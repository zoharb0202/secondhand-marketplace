import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/product_repository.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/product_similarity.dart';
import '../../../../shared/models/feed_composition.dart';
import '../../../../shared/models/feed_signals.dart';
import '../../../../shared/models/israel_regions.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/services/personalization_scorer.dart';
import '../../../../core/services/location_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

final activeFiltersProvider = StateProvider<ProductFilters>((ref) {
  return ProductFilters(sortBy: SortOption.newest);
});

final userTasteProfileProvider = FutureProvider<TasteProfileV2>((ref) async {
  final userId = ref.watch(
    currentUserProvider.select((asyncUser) => asyncUser.value?.id),
  );
  if (userId == null) return TasteProfileV2.empty();
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('tasteProfile')
        .get();
    return TasteProfileV2.fromDoc(doc);
  } catch (e) {
    if (kDebugMode) print('⚠️ userTasteProfileProvider failed: $e');
    return TasteProfileV2.empty();
  }
});

final viewerHomeRegionProvider = Provider<IsraelRegion?>((ref) {
  final addressCity = ref.watch(primaryAddressProvider)?.city;
  final fromAddress = israelRegionOf(addressCity);
  if (fromAddress != null) return fromAddress;

  final profileCity = ref.watch(
    currentUserProvider.select((asyncUser) => asyncUser.value?.city),
  );
  return israelRegionOf(profileCity);
});

final trendingScoresProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('trending')
        .doc('global')
        .get();
    final raw = doc.data()?['scores'];
    if (raw is Map) {
      final out = <String, double>{};
      raw.forEach((key, value) {
        final k = key?.toString();
        final v = (value is num) ? value.toDouble() : null;
        if (k != null && v != null) out[k] = v;
      });
      return out;
    }
  } catch (e) {
    if (kDebugMode) print('⚠️ trendingScoresProvider failed: $e');
  }
  return const <String, double>{};
});

class RecentProductStats {
  final int views;
  final int likes;
  const RecentProductStats(this.views, this.likes);
  bool get isEmpty => views == 0 && likes == 0;
}

final recentProductStatsProvider =
    FutureProvider.family<RecentProductStats, String>((ref, productId) async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('product_daily_stats')
            .doc(productId)
            .get();
        final days = doc.data()?['days'];
        if (days is! Map) return const RecentProductStats(0, 0);

        final now = DateTime.now().toUtc();
        var views = 0;
        var likes = 0;
        for (var i = 0; i < 7; i++) {
          final d = now.subtract(Duration(days: i));
          final key =
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          final entry = days[key];
          if (entry is Map) {
            final v = entry['views'];
            final l = entry['likes'];
            if (v is num) views += v.toInt();
            if (l is num) likes += l.toInt();
          }
        }
        return RecentProductStats(views, likes);
      } catch (e) {
        if (kDebugMode) print('⚠️ recentProductStatsProvider failed: $e');
        return const RecentProductStats(0, 0);
      }
    });

const FeedRecipe _kFeedRecipe = FeedRecipe();

const FeedRecipe _kFollowedFeedRecipe = FeedRecipe(maxPerSellerPerWindow: 10);

List<ProductModel> _composeTasteFeed(
  List<ProductModel> products,
  TasteProfileV2 profile, {
  Map<String, double> trendScores = const {},
  GeoPoint? viewerLocation,
  IsraelRegion? viewerHomeRegion,
  FeedRecipe recipe = _kFeedRecipe,
  DateTime? at,
}) {
  if (products.length < 2) return products;
  assert(
    kFeedBasePageSize % _kFeedRecipe.windowSize == 0 &&
        kFeedPageIncrement % _kFeedRecipe.windowSize == 0,
    'Feed page sizes must be whole windows, or a page boundary can land '
    'mid-pattern.',
  );
  assert(
    _kFollowedFeedRecipe.maxPerSellerPerWindow >=
        _kFollowedFeedRecipe.windowSize,
    'The Following recipe must leave the seller cap unreachable — see the '
    'const above for why a reachable cap truncates that feed to three items.',
  );

  final now = at ?? DateTime.now();
  final scorer = PersonalizationScorer(profile, homeRegion: viewerHomeRegion)
    ..prepare(products);
  final coldStart = profile.isEmpty;

  double maxTrend = 0;
  for (final p in products) {
    final t = trendScores[p.id];
    if (t != null && t > maxTrend) maxTrend = t;
  }

  final candidates = <FeedCandidate<ProductModel>>[];
  for (final p in products) {
    final age = now.difference(p.createdAt);
    final tieBreak = freshnessTieBreak(age);
    final base = coldStart
        ? coldStartAffinity(age)
        : scorer.compositionAffinityFor(p);

    final affinity = affinityWithProximity(
      base,
      productDistanceKm(viewerLocation, p.location),
    );

    final trend = normalisedTrend(trendScores[p.id], maxTrend);
    candidates.add(
      FeedCandidate<ProductModel>(
        item: p,
        affinity: affinity > 0 ? affinity + tieBreak : 0.0,
        trend: trend > 0 ? trend : tieBreak,
        categoryKey: _categoryKeyFor(p),
        brandKey: _brandKeyFor(p),
        sellerKey: p.sellerId.isEmpty ? null : p.sellerId,
      ),
    );
  }

  final ordered = composeFeed(candidates, recipe: recipe);
  if (ordered.length == products.length) return ordered;

  final placed = <String>{for (final p in ordered) p.id};
  return [...ordered, ...products.where((p) => !placed.contains(p.id))];
}

String _categoryKeyFor(ProductModel p) {
  final sub = (p.subcategory ?? p.subCategoryId)?.trim();
  final base = p.category.name;
  return (sub == null || sub.isEmpty) ? base : '$base/$sub';
}

String? _brandKeyFor(ProductModel p) {
  final raw = p.brand;
  if (raw == null) return null;
  final key = brandKeyOf(raw);
  return key.isEmpty ? null : key;
}

const int kFeedBasePageSize = 20;
const int kFeedPageIncrement = 20;
const int kFeedMaxPageSize = 400;

final feedPageSizeProvider = StateProvider<int>((ref) {
  ref.watch(activeFiltersProvider);
  return kFeedBasePageSize;
});

final feedRawFetchCountProvider = StateProvider<int>((ref) {
  ref.watch(activeFiltersProvider);
  return 0;
});

final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) async* {
  final repository = ref.watch(productRepositoryProvider);
  final pageSize = ref.watch(feedPageSizeProvider);
  final userLocation = ref.watch(userGeoPointProvider).valueOrNull;
  final filters = ref
      .watch(activeFiltersProvider)
      .copyWith(limit: pageSize, userLocation: userLocation);
  final userId = ref.watch(
    currentUserProvider.select((asyncUser) => asyncUser.value?.id),
  );
  final profile =
      ref.watch(userTasteProfileProvider).value ?? TasteProfileV2.empty();
  final trendScores =
      ref.watch(trendingScoresProvider).value ?? const <String, double>{};
  final viewerHomeRegion = ref.watch(viewerHomeRegionProvider);

  if (kDebugMode) print('🔄 ProductsStreamProvider: Starting stream...');
  if (kDebugMode) print('🔄 Current user: ${userId ?? "null"}');
  if (kDebugMode) print('🔄 Filters: ${filters.sortBy}');

  await for (final page in repository.getProductFeedPageStream(filters)) {
    ref.read(feedRawFetchCountProvider.notifier).state = page.fetchedCount;
    final products = page.products;
    if (kDebugMode) {
      print('📋 Raw products from repository: ${products.length}');
    }

    final filteredProducts = userId != null
        ? products.where((p) => p.sellerId != userId).toList()
        : products;

    if (kDebugMode) {
      print('📋 After filtering user products: ${filteredProducts.length}');
    }

    final composed =
        filters.sortBy == SortOption.recommended ||
        filters.sortBy == SortOption.newest;

    List<ProductModel> finalProducts;
    if (composed) {
      try {
        finalProducts = _composeTasteFeed(
          filteredProducts,
          profile,
          trendScores: trendScores,
          viewerLocation: filters.userLocation,
          viewerHomeRegion: viewerHomeRegion,
        );
        if (kDebugMode) {
          print(
            '🎯 Feed composed over ${filteredProducts.length} candidates '
            '(profile ${profile.isEmpty ? "cold" : "warm"}, '
            'user ${userId ?? "signed-out"})',
          );
        }
      } catch (e) {
        if (kDebugMode) print('❌ Error composing feed: $e');
        finalProducts = filteredProducts;
      }
    } else {
      finalProducts = filteredProducts;
    }

    if (kDebugMode) {
      print('🎯 Final products to display: ${finalProducts.length}');
    }

    yield finalProducts;
  }
});

final mapProductsStreamProvider = StreamProvider<List<ProductModel>>((
  ref,
) async* {
  final repository = ref.watch(productRepositoryProvider);
  final userLocation = ref.watch(userGeoPointProvider).valueOrNull;
  final filters = ref
      .watch(activeFiltersProvider)
      .copyWith(limit: 500, userLocation: userLocation);
  final userId = ref.watch(
    currentUserProvider.select((asyncUser) => asyncUser.value?.id),
  );

  await for (final products in repository.getProductsStreamWithFilters(
    filters,
  )) {
    yield userId != null
        ? products.where((p) => p.sellerId != userId).toList()
        : products;
  }
});

final productProvider = FutureProvider.family<ProductModel?, String>((
  ref,
  productId,
) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProduct(productId);
});

final productsBySellerProvider =
    StreamProvider.family<List<ProductModel>, String>((ref, sellerId) {
      final repository = ref.watch(productRepositoryProvider);
      return repository.getProductsBySeller(sellerId);
    });

class PriceStats {
  final int count;
  final double p25;
  final double median;
  final double p75;
  const PriceStats(this.count, this.p25, this.median, this.p75);
}

final categoryPriceStatsProvider = FutureProvider.autoDispose
    .family<PriceStats?, ({String category, String? subcategory})>((
      ref,
      key,
    ) async {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('products')
            .where('category', isEqualTo: key.category)
            .limit(200)
            .get();

        final prices = <double>[];
        for (final d in snap.docs) {
          final data = d.data();
          if (data['isActive'] == false || data['isSold'] == true) continue;
          if (key.subcategory != null &&
              data['subcategory'] != key.subcategory) {
            continue;
          }
          final p = (data['price'] as num?)?.toDouble();
          if (p != null && p > 0) prices.add(p);
        }
        if (prices.length < 3) return null;
        prices.sort();
        double pct(double f) => prices[(f * (prices.length - 1)).round()];
        return PriceStats(prices.length, pct(0.25), pct(0.5), pct(0.75));
      } catch (e) {
        if (kDebugMode) print('⚠️ categoryPriceStatsProvider failed: $e');
        return null;
      }
    });

final marketMediansProvider = Provider<Map<String, double>>((ref) {
  final products = ref.watch(productsStreamProvider).valueOrNull ?? const [];
  final byModel = <String, List<double>>{};
  for (final p in products) {
    if (!p.isActive || p.isSold || p.price <= 0) continue;
    byModel.putIfAbsent(productMatchKey(p), () => []).add(p.price);
  }
  final out = <String, double>{};
  byModel.forEach((key, prices) {
    if (prices.length < 3) return;
    prices.sort();
    final mid = prices.length ~/ 2;
    out[key] = prices.length.isOdd
        ? prices[mid]
        : (prices[mid - 1] + prices[mid]) / 2;
  });
  return out;
});

int? marketDealPercent(
  ProductModel p,
  Map<String, double> medians, {
  int minPct = 12,
}) {
  final median = medians[productMatchKey(p)];
  if (median == null || median <= 0 || p.price <= 0 || p.price >= median) {
    return null;
  }
  final pct = ((1 - p.price / median) * 100).round();
  return pct >= minPct ? pct : null;
}

typedef Deal = ({ProductModel product, int pct});

final dealsProvider = Provider<List<Deal>>((ref) {
  final products = ref.watch(productsStreamProvider).valueOrNull ?? const [];
  final medians = ref.watch(marketMediansProvider);
  final deals = <Deal>[];
  for (final p in products) {
    if (!p.isActive || p.isSold) continue;
    final pct = marketDealPercent(p, medians);
    if (pct != null) deals.add((product: p, pct: pct));
  }
  deals.sort((a, b) => b.pct.compareTo(a.pct));
  return deals;
});

const int kBargainsPageSize = 60;

final bargainsProvider = StreamProvider.autoDispose<List<ProductModel>>((ref) {
  final userId = ref.watch(
    currentUserProvider.select((asyncUser) => asyncUser.value?.id),
  );

  return FirebaseFirestore.instance
      .collection('products')
      .where('isBargain', isEqualTo: true)
      .where('isActive', isEqualTo: true)
      .where('isSold', isEqualTo: false)
      .orderBy('bargainDiscountPercent', descending: true)
      .limit(kBargainsPageSize)
      .snapshots()
      .map((snap) {
        final products = snap.docs.map(ProductModel.fromFirestore).where((p) {
          if (!p.hasRetailAnchor) return false;
          if (p.isReserved && !p.isReservationExpired) return false;
          return userId == null || p.sellerId != userId;
        }).toList();
        return products;
      });
});

const int kFollowedFeedChunkSize = 30;

final followedSellersRawFeedProvider =
    StreamProvider.autoDispose<List<ProductModel>>((ref) {
      final sellerIds = ref.watch(
        currentUserProvider.select((u) => u.value?.followingSellerIds),
      );
      if (sellerIds == null || sellerIds.isEmpty) {
        return Stream.value(const <ProductModel>[]);
      }

      final fs = FirebaseFirestore.instance;
      final chunks = <List<String>>[];
      for (var i = 0; i < sellerIds.length; i += kFollowedFeedChunkSize) {
        chunks.add(
          sellerIds.sublist(
            i,
            i + kFollowedFeedChunkSize > sellerIds.length
                ? sellerIds.length
                : i + kFollowedFeedChunkSize,
          ),
        );
      }

      final controller = StreamController<List<ProductModel>>();
      final latest = List<List<ProductModel>>.filled(chunks.length, const []);
      final seeded = List<bool>.filled(chunks.length, false);
      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

      void emit() {
        if (!seeded.every((s) => s)) return;
        final byId = <String, ProductModel>{};
        for (final list in latest) {
          for (final p in list) {
            byId[p.id] = p;
          }
        }
        if (!controller.isClosed) controller.add(byId.values.toList());
      }

      for (var i = 0; i < chunks.length; i++) {
        final chunkIndex = i;
        final sub = fs
            .collection('products')
            .where('sellerId', whereIn: chunks[chunkIndex])
            .snapshots()
            .listen(
              (snap) {
                latest[chunkIndex] = snap.docs
                    .map((d) => ProductModel.fromFirestore(d))
                    .where((p) => p.isActive && !p.isSold)
                    .toList();
                seeded[chunkIndex] = true;
                emit();
              },
              onError: (Object e, StackTrace st) {
                if (kDebugMode) {
                  print(
                    '❌ followedSellersRawFeedProvider chunk $chunkIndex failed: $e',
                  );
                }
                if (!controller.isClosed) controller.addError(e, st);
              },
            );
        subs.add(sub);
      }

      ref.onDispose(() {
        for (final s in subs) {
          s.cancel();
        }
        controller.close();
      });

      return controller.stream;
    });

final followedSellersFeedProvider =
    Provider.autoDispose<AsyncValue<List<ProductModel>>>((ref) {
      final raw = ref.watch(followedSellersRawFeedProvider);
      final profile =
          ref.watch(userTasteProfileProvider).value ?? TasteProfileV2.empty();
      final trendScores =
          ref.watch(trendingScoresProvider).value ?? const <String, double>{};
      final viewerLocation = ref.watch(userGeoPointProvider).valueOrNull;
      final viewerHomeRegion = ref.watch(viewerHomeRegionProvider);

      return raw.whenData((products) {
        try {
          return _composeTasteFeed(
            products,
            profile,
            trendScores: trendScores,
            viewerLocation: viewerLocation,
            viewerHomeRegion: viewerHomeRegion,
            recipe: _kFollowedFeedRecipe,
          );
        } catch (e) {
          if (kDebugMode) print('❌ Error composing followed feed: $e');
          final sorted = [...products]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return sorted;
        }
      });
    });

final searchProductsProvider =
    StreamProvider.family<List<ProductModel>, String>((ref, query) {
      if (query.isEmpty) {
        return Stream.value([]);
      }
      final repository = ref.watch(productRepositoryProvider);
      return repository.searchProducts(query);
    });

final favoriteProductsProvider =
    StreamProvider.family<List<ProductModel>, List<String>>((ref, productIds) {
      final repository = ref.watch(productRepositoryProvider);
      return repository.getFavoriteProducts(productIds);
    });

final likedProductsProvider = StreamProvider.family<List<ProductModel>, String>(
  (ref, userId) {
    final repository = ref.watch(productRepositoryProvider);
    return repository.getProductsLikedByUser(userId);
  },
);

class ProductController extends StateNotifier<AsyncValue<void>> {
  final ProductRepository _repository;

  ProductController(this._repository) : super(const AsyncValue.data(null));

  Future<ProductModel?> createProduct({
    required ProductModel product,
    required List<dynamic> imageFiles,
    List<dynamic>? videoFiles,
  }) async {
    state = const AsyncValue.loading();
    try {
      final createdProduct = await _repository.createProduct(
        product: product,
        imageFiles: imageFiles,
        videoFiles: videoFiles,
      );
      state = const AsyncValue.data(null);
      return createdProduct;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateProduct(productId, data);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteProduct(String productId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteProduct(productId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleLike(String productId, String userId) async {
    try {
      await _repository.toggleLike(productId, userId);
    } catch (e) {
      if (kDebugMode) print('toggleLike failed: $e');
    }
  }

  Future<void> incrementViewCount(String productId) async {
    try {
      await _repository.incrementViewCount(productId);
    } catch (_) {}
  }
}

final productControllerProvider =
    StateNotifierProvider<ProductController, AsyncValue<void>>((ref) {
      return ProductController(ref.watch(productRepositoryProvider));
    });

double? productDistanceKm(GeoPoint? userLocation, GeoPoint productLocation) {
  if (userLocation == null) return null;
  if (!LocationService.isRealGeoPoint(productLocation)) return null;
  return LocationService.calculateDistanceFromGeoPoints(
    userLocation,
    productLocation,
  );
}

enum SortOption {
  recommended,
  newest,
  priceLowToHigh,
  priceHighToLow,
  distance,
  popular;

  String get displayName {
    switch (this) {
      case SortOption.recommended:
        return 'מומלץ בשבילך ✨';
      case SortOption.newest:
        return 'חדש ביותר';
      case SortOption.priceLowToHigh:
        return 'מחיר: נמוך לגבוה';
      case SortOption.priceHighToLow:
        return 'מחיר: גבוה לנמוך';
      case SortOption.distance:
        return 'מרחק ממני';
      case SortOption.popular:
        return 'פופולרי';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.recommended:
        return Icons.auto_awesome;
      case SortOption.newest:
        return Icons.new_releases;
      case SortOption.priceLowToHigh:
      case SortOption.priceHighToLow:
        return Icons.attach_money;
      case SortOption.distance:
        return Icons.near_me;
      case SortOption.popular:
        return Icons.trending_up;
    }
  }
}

class ProductFilters {
  final String? categoryId;
  final String? subCategoryId;
  final double? minPrice;
  final double? maxPrice;
  final ProductCondition? condition;
  final double? maxDistance;
  final SortOption sortBy;
  final GeoPoint? userLocation;
  final int? limit;

  ProductFilters({
    this.categoryId,
    this.subCategoryId,
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.maxDistance,
    this.sortBy = SortOption.newest,
    this.userLocation,
    this.limit,
  });

  bool get hasActiveFilters {
    return categoryId != null ||
        minPrice != null ||
        maxPrice != null ||
        condition != null ||
        maxDistance != null;
  }

  int get activeFilterCount {
    int count = 0;
    if (categoryId != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (condition != null) count++;
    if (maxDistance != null) count++;
    return count;
  }

  ProductFilters copyWith({
    Object? categoryId = _unset,
    Object? subCategoryId = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    Object? condition = _unset,
    Object? maxDistance = _unset,
    SortOption? sortBy,
    Object? userLocation = _unset,
    int? limit,
  }) {
    return ProductFilters(
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      subCategoryId: identical(subCategoryId, _unset)
          ? this.subCategoryId
          : subCategoryId as String?,
      minPrice: identical(minPrice, _unset)
          ? this.minPrice
          : minPrice as double?,
      maxPrice: identical(maxPrice, _unset)
          ? this.maxPrice
          : maxPrice as double?,
      condition: identical(condition, _unset)
          ? this.condition
          : condition as ProductCondition?,
      maxDistance: identical(maxDistance, _unset)
          ? this.maxDistance
          : maxDistance as double?,
      sortBy: sortBy ?? this.sortBy,
      userLocation: identical(userLocation, _unset)
          ? this.userLocation
          : userLocation as GeoPoint?,
      limit: limit ?? this.limit,
    );
  }

  ProductFilters clear() {
    return ProductFilters(
      sortBy: sortBy,
      userLocation: userLocation,
      limit: limit,
    );
  }
}

class _Unset {
  const _Unset();
}

const _unset = _Unset();

final similarProductsProvider = FutureProvider.autoDispose
    .family<List<ScoredProduct>, SimilarityFeatures>((ref, reference) async {
      final products = FirebaseFirestore.instance.collection('products');

      Future<List<ProductModel>> run(
        String label,
        Query<Map<String, dynamic>> q,
      ) async {
        try {
          final snap = await q.get();
          if (kDebugMode) {
            print('📊 [SIMILAR] $label returned ${snap.docs.length} docs');
          }
          return snap.docs.map(ProductModel.fromFirestore).toList();
        } catch (e) {
          if (kDebugMode) print('⚠️ [SIMILAR] $label failed: $e');
          return const [];
        }
      }

      final legs = <Future<List<ProductModel>>>[
        run(
          'category=${reference.legacyCategory}',
          products
              .where('category', isEqualTo: reference.legacyCategory)
              .where('isSold', isEqualTo: false)
              .orderBy('createdAt', descending: true)
              .limit(kSimilarCategoryPoolSize),
        ),
        if (reference.sellerId.isNotEmpty)
          run(
            'seller',
            products
                .where('sellerId', isEqualTo: reference.sellerId)
                .where('isSold', isEqualTo: false)
                .limit(kSimilarSellerPoolSize),
          ),
        for (final variant in brandQueryVariants(reference.rawBrand))
          run(
            'brand=$variant',
            products
                .where('brand', isEqualTo: variant)
                .where('isSold', isEqualTo: false)
                .limit(kSimilarBrandPoolSize),
          ),
      ];

      final pool = (await Future.wait(legs)).expand((e) => e);

      final ranked = rankSimilarProducts(
        reference: reference,
        candidates: pool,
        now: DateTime.now(),
      );

      if (kDebugMode) {
        print(
          '✅ [SIMILAR] ${ranked.length} shown, best: '
          '${ranked.isEmpty ? "—" : ranked.first.score}',
        );
      }
      return ranked;
    });
