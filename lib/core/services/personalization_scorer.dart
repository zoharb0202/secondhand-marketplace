import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/enums.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/israel_regions.dart';

class RecentSearchEntry {
  final String q;
  final int atMs;
  const RecentSearchEntry({required this.q, required this.atMs});
}

class CartAddEntry {
  final String productId;
  final int atMs;
  const CartAddEntry({required this.productId, required this.atMs});
}

class TasteProfileV2 {
  final int version;
  final Map<String, double> categoryWeights;
  final Map<String, double> brandWeights;
  final Map<String, double> sellerWeights;
  final Map<String, double> priceBandWeights;

  final Map<String, double> cityWeights;

  final Map<String, double> regionWeights;

  final List<RecentSearchEntry> recentSearches;
  final List<CartAddEntry> cartAdds;
  final int totalSignals;

  const TasteProfileV2({
    required this.version,
    required this.categoryWeights,
    required this.brandWeights,
    required this.sellerWeights,
    required this.priceBandWeights,
    this.cityWeights = const {},
    this.regionWeights = const {},
    required this.recentSearches,
    required this.cartAdds,
    required this.totalSignals,
  });

  factory TasteProfileV2.empty() => const TasteProfileV2(
    version: 0,
    categoryWeights: {},
    brandWeights: {},
    sellerWeights: {},
    priceBandWeights: {},
    recentSearches: [],
    cartAdds: [],
    totalSignals: 0,
  );

  bool get isEmpty =>
      totalSignals <= 0 &&
      categoryWeights.isEmpty &&
      brandWeights.isEmpty &&
      sellerWeights.isEmpty &&
      priceBandWeights.isEmpty;

  double get maxCategoryWeight => _maxOf(categoryWeights);
  double get maxBrandWeight => _maxOf(brandWeights);
  double get maxSellerWeight => _maxOf(sellerWeights);
  double get maxPriceBandWeight => _maxOf(priceBandWeights);
  double get maxRegionWeight => _maxOf(regionWeights);

  static double _maxOf(Map<String, double> m) =>
      m.values.fold<double>(0, (max, v) => v > max ? v : max);

  List<String> topCategories(int n) {
    final sorted = categoryWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  factory TasteProfileV2.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      if (!doc.exists) return TasteProfileV2.empty();
      final data = doc.data();
      if (data == null) return TasteProfileV2.empty();

      final version = (data['version'] as num?)?.toInt() ?? 0;
      if (version < 2) return TasteProfileV2.empty();

      final weights = data['weights'];
      final weightsMap = weights is Map ? weights : const {};

      final recentSearchesRaw = data['recentSearches'];
      final recentSearches = <RecentSearchEntry>[];
      if (recentSearchesRaw is List) {
        for (final e in recentSearchesRaw) {
          if (e is Map) {
            final q = (e['q'] ?? '').toString();
            final atMs = (e['atMs'] as num?)?.toInt() ?? 0;
            if (q.isNotEmpty) {
              recentSearches.add(RecentSearchEntry(q: q, atMs: atMs));
            }
          }
        }
      }

      final cartAddsRaw = data['cartAdds'];
      final cartAdds = <CartAddEntry>[];
      if (cartAddsRaw is List) {
        for (final e in cartAddsRaw) {
          if (e is Map) {
            final pid = (e['productId'] ?? '').toString();
            final atMs = (e['atMs'] as num?)?.toInt() ?? 0;
            if (pid.isNotEmpty) {
              cartAdds.add(CartAddEntry(productId: pid, atMs: atMs));
            }
          }
        }
      }

      final cityWeights = parseWeightMap(weightsMap['cities']);

      return TasteProfileV2(
        version: version,
        categoryWeights: parseWeightMap(weightsMap['categories']),
        brandWeights: parseWeightMap(weightsMap['brands'], keyOf: brandKeyOf),
        sellerWeights: parseWeightMap(weightsMap['sellers']),
        priceBandWeights: parseWeightMap(weightsMap['priceBands']),
        cityWeights: cityWeights,
        regionWeights: foldCityWeightsToRegions(cityWeights),
        recentSearches: recentSearches,
        cartAdds: cartAdds,
        totalSignals: (data['totalSignals'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('TasteProfileV2.fromDoc failed: $e');
      return TasteProfileV2.empty();
    }
  }
}

Map<String, double> parseWeightMap(
  dynamic v, {
  String Function(String)? keyOf,
}) {
  if (v is! Map) return <String, double>{};
  final out = <String, double>{};
  v.forEach((k, val) {
    final d = (val is num) ? val.toDouble() : null;
    if (d == null) return;
    final key = keyOf == null ? k.toString() : keyOf(k.toString());
    if (key.isEmpty) return;
    out[key] = (out[key] ?? 0) + d;
  });
  return out;
}

Map<String, double> foldCityWeightsToRegions(Map<String, double> cityWeights) {
  final out = <String, double>{};
  cityWeights.forEach((city, weight) {
    final region = israelRegionOf(city);
    if (region == null) return;
    out[region.name] = (out[region.name] ?? 0) + weight;
  });
  return out;
}

String priceBandOf(double price) {
  if (price < 50) return 'b0_50';
  if (price < 150) return 'b50_150';
  if (price < 400) return 'b150_400';
  if (price < 1000) return 'b400_1000';
  return 'b1000p';
}

String brandKeyOf(String brand) =>
    brand.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

const Map<ProductCategory, Set<ProductCategory>> categoryAdjacency = {
  ProductCategory.vehicles: {ProductCategory.services},
  ProductCategory.realEstate: {ProductCategory.homeGarden},
  ProductCategory.electronics: {
    ProductCategory.officeSupplies,
    ProductCategory.sports,
  },
  ProductCategory.fashion: {ProductCategory.babyKids, ProductCategory.sports},
  ProductCategory.homeGarden: {
    ProductCategory.realEstate,
    ProductCategory.officeSupplies,
    ProductCategory.animalsSupplies,
  },
  ProductCategory.sports: {
    ProductCategory.electronics,
    ProductCategory.fashion,
    ProductCategory.babyKids,
  },
  ProductCategory.babyKids: {ProductCategory.fashion, ProductCategory.sports},
  ProductCategory.animalsSupplies: {ProductCategory.homeGarden},
  ProductCategory.officeSupplies: {
    ProductCategory.electronics,
    ProductCategory.homeGarden,
    ProductCategory.jobs,
  },
  ProductCategory.services: {ProductCategory.vehicles, ProductCategory.jobs},
  ProductCategory.jobs: {
    ProductCategory.services,
    ProductCategory.officeSupplies,
  },
  ProductCategory.other: {},
};

double _normalize(double? raw, double max) {
  if (raw == null || raw <= 0 || max <= 0) return 0.0;
  final n = raw / max;
  return n.clamp(0.0, 1.0);
}

const double kRegionTermWeight = 1.0;

class PersonalizationScorer {
  final TasteProfileV2 profile;

  final IsraelRegion? homeRegion;

  final Set<String> _cartAddProductIds;
  Set<String> _categoriesInCart = const {};

  PersonalizationScorer(this.profile, {this.homeRegion})
    : _cartAddProductIds = profile.cartAdds.map((c) => c.productId).toSet();

  void prepare(List<ProductModel> products) {
    if (_cartAddProductIds.isEmpty) {
      _categoriesInCart = const {};
      return;
    }
    _categoriesInCart = {
      for (final p in products)
        if (_cartAddProductIds.contains(p.id)) p.category.name,
    };
  }

  double catWeightFor(ProductModel product) {
    final direct = profile.categoryWeights[product.category.name];
    if (direct != null && direct > 0) {
      return _normalize(direct, profile.maxCategoryWeight);
    }
    double bestAdjacent = 0;
    for (final adj
        in categoryAdjacency[product.category] ?? const <ProductCategory>{}) {
      final w = profile.categoryWeights[adj.name];
      if (w != null && w > bestAdjacent) bestAdjacent = w;
    }
    return kAdjacentBorrow *
        _normalize(bestAdjacent, profile.maxCategoryWeight);
  }

  bool get regionAxisActive =>
      homeRegion != null || profile.regionWeights.isNotEmpty;

  double regionWeightFor(ProductModel product) {
    if (!regionAxisActive) return 0.0;
    final region = israelRegionOf(product.city);
    if (region == null) return 0.0;

    double behavioural;
    final direct = profile.regionWeights[region.name];
    if (direct != null && direct > 0) {
      behavioural = _normalize(direct, profile.maxRegionWeight);
    } else {
      double bestAdjacent = 0;
      for (final adj in regionAdjacency[region] ?? const <IsraelRegion>{}) {
        final w = profile.regionWeights[adj.name];
        if (w != null && w > bestAdjacent) bestAdjacent = w;
      }
      behavioural =
          kAdjacentBorrow * _normalize(bestAdjacent, profile.maxRegionWeight);
    }

    double declared = 0;
    if (homeRegion != null) {
      if (region == homeRegion) {
        declared = 1.0;
      } else if ((regionAdjacency[homeRegion] ?? const <IsraelRegion>{})
          .contains(region)) {
        declared = kAdjacentBorrow;
      }
    }
    return behavioural > declared ? behavioural : declared;
  }

  double brandWeightFor(ProductModel product) {
    final brand = product.brand;
    if (brand == null) return 0.0;
    return _normalize(
      profile.brandWeights[brandKeyOf(brand)],
      profile.maxBrandWeight,
    );
  }

  double sellerWeightFor(ProductModel product) {
    return _normalize(
      profile.sellerWeights[product.sellerId],
      profile.maxSellerWeight,
    );
  }

  double priceWeightFor(ProductModel product) {
    return _normalize(
      profile.priceBandWeights[priceBandOf(product.price)],
      profile.maxPriceBandWeight,
    );
  }

  double searchBoostFor(ProductModel product) {
    if (profile.recentSearches.isEmpty) return 0.0;
    final titleLower = product.title.toLowerCase();

    bool matchesQuery(String q) {
      final terms = q
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 3);
      return terms.any(titleLower.contains);
    }

    if (matchesQuery(profile.recentSearches.first.q)) return 3.0;
    for (final entry in profile.recentSearches.skip(1)) {
      if (matchesQuery(entry.q)) return 2.0;
    }
    return 0.0;
  }

  double cartBoostFor(ProductModel product) {
    if (profile.cartAdds.isEmpty) return 0.0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const twoHoursMs = 2 * 60 * 60 * 1000;
    for (final entry in profile.cartAdds) {
      if (entry.productId == product.id && (nowMs - entry.atMs) > twoHoursMs) {
        return 8.0;
      }
    }
    if (_categoriesInCart.contains(product.category.name)) return 1.0;
    return 0.0;
  }

  double get weightedTermsMax => regionAxisActive ? 8.0 : 7.0;

  double get affinityDivisor => weightedTermsMax + 11.0;

  double get weightedTermsCeiling => weightedTermsMax / affinityDivisor;

  static const double kWeightedTermsCeilingNoRegion = 7.0 / 18.0;

  static const double kWeightedTermsCeilingWithRegion = 8.0 / 19.0;

  double compositionAffinityFor(ProductModel product) =>
      (affinityFor(product) / weightedTermsCeiling).clamp(0.0, 1.0);

  double affinityFor(ProductModel product) {
    final taste =
        3 * catWeightFor(product) +
        2 * brandWeightFor(product) +
        sellerWeightFor(product) +
        priceWeightFor(product) +
        searchBoostFor(product) +
        cartBoostFor(product);
    final raw = taste <= 0
        ? 0.0
        : taste + kRegionTermWeight * regionWeightFor(product);
    return (raw / affinityDivisor).clamp(0.0, 1.0);
  }

  double affinityBonusForSearch(ProductModel product) {
    return 0.25 * (3 * catWeightFor(product) + 2 * brandWeightFor(product));
  }
}
