import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/availability_window.dart';
import '../../../profile/data/services/opening_hours_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/geohash.dart';
import '../../../../core/utils/image_picker_web.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/products_cache_service.dart';
import '../../../../core/services/interaction_tracker.dart';
import '../../presentation/providers/product_provider.dart';

class ProductFeedPage {
  final List<ProductModel> products;
  final int fetchedCount;
  const ProductFeedPage({required this.products, required this.fetchedCount});
}

class GeoProductPage {
  final List<ProductModel> products;

  final int cellsQueried;

  final bool servedFromLegacyScan;

  final bool complete;

  const GeoProductPage({
    required this.products,
    this.cellsQueried = 0,
    this.servedFromLegacyScan = false,
    this.complete = true,
  });
}

class _GeoCellCache {
  final List<ProductModel> products;
  final DateTime fetchedAt;

  final bool complete;

  const _GeoCellCache(this.products, this.fetchedAt, {this.complete = true});
}

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ProductsCacheService _cache = ProductsCacheService();

  Future<ProductModel> createProduct({
    required ProductModel product,
    required List<dynamic> imageFiles,
    List<dynamic>? videoFiles,
  }) async {
    try {
      List<String> imageUrls = [];
      List<String> videoUrls = [];

      if (kDebugMode) {
        print('Image files count: ${imageFiles.length}');
      }
      if (imageFiles.isNotEmpty) {
        final List<SelectedImage> selectedImages = [];

        for (final imageData in imageFiles) {
          try {
            if (imageData is Map<String, dynamic>) {
              final xFile = imageData['file'] as XFile;
              final bytes = imageData['bytes'] as Uint8List;
              if (kDebugMode) {
                print(
                  'Using cached bytes for: ${xFile.name}, size: ${bytes.length}',
                );
              }
              selectedImages.add(
                SelectedImage(
                  name: xFile.name,
                  bytes: bytes,
                  mimeType: xFile.mimeType,
                ),
              );
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error processing image: $e');
            }
            continue;
          }
        }

        if (kDebugMode) {
          print('Selected images to upload: ${selectedImages.length}');
        }
        if (selectedImages.isNotEmpty) {
          imageUrls = await ImagePickerWeb.uploadMultipleImages(
            images: selectedImages,
            basePath: '${AppConstants.productImagesPath}/${product.sellerId}',
          );
          if (kDebugMode) {
            print('Uploaded image URLs: $imageUrls');
          }
        }
      }

      if (kDebugMode) {
        print('📹 Video files count: ${videoFiles?.length ?? 0}');
      }
      if (videoFiles != null && videoFiles.isNotEmpty) {
        for (int i = 0; i < videoFiles.length; i++) {
          try {
            final file = videoFiles[i];
            if (kDebugMode) {
              print(
                '📹 Processing video $i: type=${file.runtimeType}, value=$file',
              );
            }
            String? videoUrl;

            if (file is String) {
              if (kDebugMode) {
                print('📹 Video is String (web path): $file');
              }
              if (kDebugMode) {
                print('⚠️ Skipping video upload for web (path only)');
              }
              continue;
            } else if (file is XFile) {
              if (kDebugMode) {
                print('📹 Video is XFile: ${file.path}');
              }
              final bytes = await file.readAsBytes();
              if (kDebugMode) {
                print('📹 Read ${bytes.length} bytes from XFile');
              }
              final fileName =
                  '${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
              final ref = _storage
                  .ref()
                  .child(
                    '${AppConstants.productImagesPath}/${product.sellerId}/videos',
                  )
                  .child(fileName);

              if (kDebugMode) {
                print('📹 Uploading to Firebase Storage...');
              }
              await ref.putData(
                bytes,
                SettableMetadata(contentType: 'video/mp4'),
              );
              videoUrl = await ref.getDownloadURL();
              if (kDebugMode) {
                print('📹 Upload complete: $videoUrl');
              }
            } else {
              if (kDebugMode) {
                print('📹 Video is File (dart:io): ${file.path}');
              }
              final bytes = await file.readAsBytes();
              if (kDebugMode) {
                print('📹 Read ${bytes.length} bytes from File');
              }
              final fileName =
                  '${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
              final ref = _storage
                  .ref()
                  .child(
                    '${AppConstants.productImagesPath}/${product.sellerId}/videos',
                  )
                  .child(fileName);

              if (kDebugMode) {
                print('📹 Uploading to Firebase Storage...');
              }
              await ref.putData(
                bytes,
                SettableMetadata(contentType: 'video/mp4'),
              );
              videoUrl = await ref.getDownloadURL();
              if (kDebugMode) {
                print('📹 Upload complete: $videoUrl');
              }
            }

            videoUrls.add(videoUrl);
            if (kDebugMode) {
              print('Uploaded video URL: $videoUrl');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error uploading video: $e');
            }
            continue;
          }
        }
      }

      final productWithMedia = product.copyWith(
        imageUrls: imageUrls,
        videoUrls: videoUrls,
        createdAt: DateTime.now(),
      );

      final data = productWithMedia.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();

      try {
        final windows = await OpeningHoursService().loadFor(
          productWithMedia.sellerId,
        );
        data[kProductSellerHoursField] = windows.map((w) => w.toMap()).toList();
      } catch (e) {
        data.remove(kProductSellerHoursField);
        if (kDebugMode) {
          print('Seller hours mirror not stamped: $e');
        }
      }
      final docRef = await _firestore
          .collection(AppConstants.productsCollection)
          .add(data);

      return productWithMedia.copyWith(id: docRef.id);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ProductModel>> getProductsPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.productsCollection)
          .where('isActive', isEqualTo: true)
          .where('isSold', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      _cache.addProducts(products);

      return products;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching paginated products: $e');
      }
      rethrow;
    }
  }

  Stream<List<ProductModel>> getProductsStreamWithFilters(
    ProductFilters filters,
  ) => getProductFeedPageStream(filters).map((page) => page.products);

  Stream<ProductFeedPage> getProductFeedPageStream(ProductFilters filters) {
    try {
      return _firestore
          .collection(AppConstants.productsCollection)
          .where('isActive', isEqualTo: true)
          .where('isSold', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(filters.limit ?? 50)
          .snapshots()
          .handleError((error) {
            if (kDebugMode) {
              print('🔴 Firestore error: $error');
            }
            throw error;
          })
          .map((snapshot) {
            try {
              final fetchedCount = snapshot.docs.length;

              var products = snapshot.docs
                  .map((doc) {
                    try {
                      return ProductModel.fromFirestore(doc);
                    } catch (e) {
                      if (kDebugMode) {
                        print('Error parsing product document ${doc.id}: $e');
                      }
                      return null;
                    }
                  })
                  .where((product) => product != null)
                  .cast<ProductModel>()
                  .where((product) {
                    try {
                      return _matchesFilters(product, filters);
                    } catch (e) {
                      if (kDebugMode) {
                        print('Error filtering product ${product.id}: $e');
                      }
                      return false;
                    }
                  })
                  .toList();

              try {
                _sortProducts(products, filters);
              } catch (e) {
                if (kDebugMode) {
                  print('Error sorting products: $e');
                }
                products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              }

              return ProductFeedPage(
                products: products,
                fetchedCount: fetchedCount,
              );
            } catch (e) {
              if (kDebugMode) {
                print('🔴 Error processing products snapshot: $e');
              }
              return const ProductFeedPage(
                products: <ProductModel>[],
                fetchedCount: 0,
              );
            }
          });
    } catch (e) {
      if (kDebugMode) {
        print('🔴 Error in getProductFeedPageStream: $e');
      }
      return Stream.value(
        const ProductFeedPage(products: <ProductModel>[], fetchedCount: 0),
      );
    }
  }

  bool _matchesFilters(ProductModel product, ProductFilters filters) {
    bool matches = product.isActive && !product.isSold;

    if (filters.categoryId != null) {
      matches = matches && product.categoryId == filters.categoryId;
    }
    if (filters.subCategoryId != null) {
      matches = matches && product.subCategoryId == filters.subCategoryId;
    }

    if (filters.maxPrice != null) {
      matches = matches && product.price <= filters.maxPrice!;
    }
    if (filters.minPrice != null) {
      matches = matches && product.price >= filters.minPrice!;
    }

    if (filters.condition != null) {
      matches = matches && product.condition == filters.condition;
    }

    if (filters.maxDistance != null && filters.userLocation != null) {
      if (!LocationService.isRealGeoPoint(product.location)) {
        matches = false;
      } else {
        final distance = LocationService.calculateDistanceFromGeoPoints(
          filters.userLocation!,
          product.location,
        );
        matches = matches && distance <= filters.maxDistance!;
      }
    }

    return matches;
  }

  static const int _kGeoMaxCoveringCells = 9;

  static const int _kGeoCellPageSize = 150;

  static const int _kGeoMaxPagesPerCell = 6;

  static const Duration _kGeoCellTtl = Duration(seconds: 90);

  static const int _kGeoCacheMaxCells = 96;

  static const int _kLegacyScanLimit = 300;

  static const Duration _kGeohashProbeTtl = Duration(minutes: 5);

  static final Map<String, _GeoCellCache> _geoCellCache = {};
  static bool? _geohashProbeResult;
  static DateTime? _geohashProbedAt;
  static Future<bool>? _geohashProbeInFlight;
  static _GeoCellCache? _legacyScanCache;
  static Future<_GeoCellCache>? _legacyScanInFlight;

  static DateTime? _geoCompositeIndexFailedAt;
  static const Duration _kGeoCompositeIndexRetry = Duration(minutes: 2);

  static bool get _geoCompositeIndexUsable {
    final failedAt = _geoCompositeIndexFailedAt;
    return failedAt == null ||
        DateTime.now().difference(failedAt) >= _kGeoCompositeIndexRetry;
  }

  Future<GeoProductPage> getProductsNear({
    required GeoPoint center,
    required double radiusKm,
    ProductFilters? filters,
    bool forceRefresh = false,
  }) async {
    final safeRadiusKm = radiusKm <= 0 ? 1.0 : radiusKm;

    if (!await _anyProductHasGeohash()) {
      final scanned = await _legacyProximityScan();
      return GeoProductPage(
        products: _trimToRadius(
          scanned.products,
          center,
          safeRadiusKm,
          filters,
        ),
        servedFromLegacyScan: true,
        complete: scanned.complete,
      );
    }

    final box = GeoHash.boundingBox(
      latitude: center.latitude,
      longitude: center.longitude,
      radiusKm: safeRadiusKm,
    );
    final prefixes = GeoHash.coveringPrefixes(
      box,
      maxCells: _kGeoMaxCoveringCells,
    );

    final now = DateTime.now();
    final merged = <String, ProductModel>{};
    final fetches = <Future<void>>[];
    var cellsQueried = 0;
    var complete = true;

    for (final prefix in prefixes) {
      final cached = _geoCellCache[prefix];
      if (!forceRefresh &&
          cached != null &&
          now.difference(cached.fetchedAt) < _kGeoCellTtl) {
        for (final product in cached.products) {
          merged[product.id] = product;
        }
        if (!cached.complete) complete = false;
        continue;
      }
      cellsQueried++;
      fetches.add(
        _fetchGeoCell(prefix)
            .then((cell) {
              _storeGeoCell(prefix, cell);
              for (final product in cell.products) {
                merged[product.id] = product;
              }
              if (!cell.complete) complete = false;
            })
            .catchError((Object e) {
              if (kDebugMode) print('⚠️ geohash cell "$prefix" failed: $e');
              complete = false;
              final stale = _geoCellCache[prefix];
              if (stale != null) {
                for (final product in stale.products) {
                  merged[product.id] = product;
                }
              }
            }),
      );
    }

    await Future.wait(fetches);

    return GeoProductPage(
      products: _trimToRadius(merged.values, center, safeRadiusKm, filters),
      cellsQueried: cellsQueried,
      complete: complete,
    );
  }

  Future<_GeoCellCache> _fetchGeoCell(String prefix) async {
    final end = GeoHash.prefixEnd(prefix);
    final collection = _firestore.collection(AppConstants.productsCollection);

    final products = <ProductModel>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    var complete = false;

    for (var page = 0; page < _kGeoMaxPagesPerCell; page++) {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _fetchGeoCellPage(collection, prefix, end, cursor);
      } catch (e) {
        if (page == 0) rethrow;
        if (kDebugMode) {
          print('⚠️ geohash cell "$prefix" page $page failed: $e');
        }
        break;
      }

      products.addAll(_parseSellable(snapshot.docs));

      if (snapshot.docs.length < _kGeoCellPageSize) {
        complete = true;
        break;
      }
      cursor = snapshot.docs.last;
    }

    return _GeoCellCache(products, DateTime.now(), complete: complete);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchGeoCellPage(
    CollectionReference<Map<String, dynamic>> collection,
    String prefix,
    String end,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  ) async {
    Query<Map<String, dynamic>> range(Query<Map<String, dynamic>> base) {
      var query = base.orderBy('geohash');
      query = cursor == null
          ? query.startAt([prefix])
          : query.startAfterDocument(cursor);
      return query.endAt([end]).limit(_kGeoCellPageSize);
    }

    if (_geoCompositeIndexUsable) {
      try {
        final snapshot = await range(
          collection
              .where('isActive', isEqualTo: true)
              .where('isSold', isEqualTo: false),
        ).get();
        _geoCompositeIndexFailedAt = null;
        return snapshot;
      } on FirebaseException catch (e) {
        if (e.code != 'failed-precondition') rethrow;
        if (kDebugMode) {
          print(
            'ℹ️ products(isActive,isSold,geohash) index unavailable — '
            'using the single-field geohash range for the next '
            '${_kGeoCompositeIndexRetry.inMinutes} min',
          );
        }
        _geoCompositeIndexFailedAt = DateTime.now();
      }
    }
    return range(collection).get();
  }

  List<ProductModel> _parseSellable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final out = <ProductModel>[];
    for (final doc in docs) {
      try {
        final product = ProductModel.fromFirestore(doc);
        if (!product.isActive || product.isSold) continue;
        out.add(product);
      } catch (e) {
        if (kDebugMode) print('Error parsing product ${doc.id}: $e');
      }
    }
    return out;
  }

  void _storeGeoCell(String prefix, _GeoCellCache cell) {
    if (_geoCellCache.length >= _kGeoCacheMaxCells &&
        !_geoCellCache.containsKey(prefix)) {
      String? oldestKey;
      DateTime? oldestAt;
      _geoCellCache.forEach((key, value) {
        if (oldestAt == null || value.fetchedAt.isBefore(oldestAt!)) {
          oldestAt = value.fetchedAt;
          oldestKey = key;
        }
      });
      if (oldestKey != null) _geoCellCache.remove(oldestKey);
    }
    _geoCellCache[prefix] = cell;
  }

  Future<bool> _anyProductHasGeohash() {
    final cached = _geohashProbeResult;
    final probedAt = _geohashProbedAt;
    if (cached == true) return Future.value(true);
    if (cached == false &&
        probedAt != null &&
        DateTime.now().difference(probedAt) < _kGeohashProbeTtl) {
      return Future.value(false);
    }
    return _geohashProbeInFlight ??= () async {
      try {
        final snapshot = await _firestore
            .collection(AppConstants.productsCollection)
            .orderBy('geohash')
            .limit(1)
            .get();
        _geohashProbeResult = snapshot.docs.isNotEmpty;
      } catch (e) {
        if (kDebugMode) print('⚠️ geohash probe failed: $e');
        _geohashProbeResult = false;
      }
      _geohashProbedAt = DateTime.now();
      _geohashProbeInFlight = null;
      return _geohashProbeResult!;
    }();
  }

  Future<_GeoCellCache> _legacyProximityScan() {
    final cached = _legacyScanCache;
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _kGeoCellTtl) {
      return Future.value(cached);
    }
    return _legacyScanInFlight ??= () async {
      try {
        final snapshot = await _firestore
            .collection(AppConstants.productsCollection)
            .where('isActive', isEqualTo: true)
            .where('isSold', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .limit(_kLegacyScanLimit)
            .get();
        final result = _GeoCellCache(
          _parseSellable(snapshot.docs),
          DateTime.now(),
          complete: snapshot.docs.length < _kLegacyScanLimit,
        );
        _legacyScanCache = result;
        return result;
      } catch (e) {
        if (kDebugMode) print('⚠️ legacy proximity scan failed: $e');
        return _GeoCellCache(
          _legacyScanCache?.products ?? const <ProductModel>[],
          DateTime.now(),
          complete: false,
        );
      } finally {
        _legacyScanInFlight = null;
      }
    }();
  }

  List<ProductModel> _trimToRadius(
    Iterable<ProductModel> candidates,
    GeoPoint center,
    double radiusKm,
    ProductFilters? filters,
  ) {
    final out = <ProductModel>[];
    for (final product in candidates) {
      final position = LocationService.isRealGeoPoint(product.location)
          ? product.location
          : LocationService.cityCentroidFor(product.city);
      if (position == null) continue;
      if (LocationService.calculateDistanceFromGeoPoints(center, position) >
          radiusKm) {
        continue;
      }
      if (filters != null) {
        try {
          if (!_matchesFilters(product, filters)) continue;
        } catch (e) {
          if (kDebugMode) print('Error filtering product ${product.id}: $e');
          continue;
        }
      }
      out.add(product);
    }
    return out;
  }

  void _sortProducts(List<ProductModel> products, ProductFilters filters) {
    products.sort((a, b) {
      switch (filters.sortBy) {
        case SortOption.recommended:
          return b.createdAt.compareTo(a.createdAt);

        case SortOption.newest:
          return b.createdAt.compareTo(a.createdAt);

        case SortOption.priceLowToHigh:
          return a.price.compareTo(b.price);

        case SortOption.priceHighToLow:
          return b.price.compareTo(a.price);

        case SortOption.distance:
          if (filters.userLocation == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          final aReal = LocationService.isRealGeoPoint(a.location);
          final bReal = LocationService.isRealGeoPoint(b.location);
          if (aReal != bReal) return aReal ? -1 : 1;
          if (!aReal) return b.createdAt.compareTo(a.createdAt);
          final distanceA = LocationService.calculateDistanceFromGeoPoints(
            filters.userLocation!,
            a.location,
          );
          final distanceB = LocationService.calculateDistanceFromGeoPoints(
            filters.userLocation!,
            b.location,
          );
          return distanceA.compareTo(distanceB);

        case SortOption.popular:
          final aPopularity = a.likeCount + (a.viewCount * 0.1).round();
          final bPopularity = b.likeCount + (b.viewCount * 0.1).round();
          return bPopularity.compareTo(aPopularity);
      }
    });
  }

  Stream<List<ProductModel>> getProductsStream({
    int limit = 20,
    String? category,
    double? maxPrice,
    double? minPrice,
    GeoPoint? userLocation,
    bool sortByDistance = false,
  }) {
    try {
      return _firestore
          .collection(AppConstants.productsCollection)
          .limit(50)
          .snapshots()
          .map((snapshot) {
            var products = snapshot.docs
                .map((doc) => ProductModel.fromFirestore(doc))
                .where((product) {
                  bool matches = product.isActive && !product.isSold;

                  if (category != null) {
                    matches = matches && product.category.name == category;
                  }

                  if (maxPrice != null) {
                    matches = matches && product.price <= maxPrice;
                  }

                  if (minPrice != null) {
                    matches = matches && product.price >= minPrice;
                  }

                  return matches;
                })
                .toList();

            products.sort((a, b) {
              if (sortByDistance && userLocation != null) {
                final distanceA =
                    LocationService.calculateDistanceFromGeoPoints(
                      userLocation,
                      a.location,
                    );
                final distanceB =
                    LocationService.calculateDistanceFromGeoPoints(
                      userLocation,
                      b.location,
                    );
                return distanceA.compareTo(distanceB);
              } else {
                return b.createdAt.compareTo(a.createdAt);
              }
            });

            if (products.length > limit) {
              products = products.sublist(0, limit);
            }

            return products;
          });
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductModel?> getProduct(String productId) async {
    try {
      final cached = _cache.getProduct(productId);
      if (cached != null) {
        return cached;
      }

      final doc = await _firestore
          .collection(AppConstants.productsCollection)
          .doc(productId)
          .get();

      if (doc.exists) {
        final product = ProductModel.fromFirestore(doc);
        _cache.addProduct(product);
        return product;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ProductModel>> getProductsBySeller(String sellerId) {
    try {
      return _firestore
          .collection(AppConstants.productsCollection)
          .where('sellerId', isEqualTo: sellerId)
          .snapshots()
          .map((snapshot) {
            final products = snapshot.docs
                .map((doc) => ProductModel.fromFirestore(doc))
                .toList();

            products.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return products;
          });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    try {
      final rawLocation = data['location'];
      if (rawLocation is GeoPoint) {
        final derived = ProductModel.geohashForLocation(rawLocation);
        if (derived != null) {
          data = {...data, 'geohash': derived};
        } else {
          data = {...data, 'geohash': FieldValue.delete()};
        }
      }

      await _firestore
          .collection(AppConstants.productsCollection)
          .doc(productId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      final product = await getProduct(productId);
      if (product != null) {
        for (String imageUrl in product.imageUrls) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
          } catch (_) {}
        }

        await _firestore
            .collection(AppConstants.productsCollection)
            .doc(productId)
            .delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleLike(String productId, String userId) async {
    try {
      final docRef = _firestore
          .collection(AppConstants.productsCollection)
          .doc(productId);

      final cachedProduct = _cache.getProduct(productId);
      if (cachedProduct != null) {
        final likedByUserIds = List<String>.from(cachedProduct.likedByUserIds);
        if (likedByUserIds.contains(userId)) {
          likedByUserIds.remove(userId);
        } else {
          likedByUserIds.add(userId);
        }

        final updatedProduct = cachedProduct.copyWith(
          likedByUserIds: likedByUserIds,
          likeCount: likedByUserIds.length,
        );
        _cache.addProduct(updatedProduct);
      }

      bool nowLiked = false;
      ProductModel? likedProduct;
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Product not found');

        final product = ProductModel.fromFirestore(snapshot);
        likedProduct = product;
        final likedByUserIds = List<String>.from(product.likedByUserIds);

        if (likedByUserIds.contains(userId)) {
          likedByUserIds.remove(userId);
          nowLiked = false;
        } else {
          likedByUserIds.add(userId);
          nowLiked = true;
        }

        transaction.update(docRef, {
          'likedByUserIds': likedByUserIds,
          'likeCount': likedByUserIds.length,
        });
      });

      final liked = likedProduct;
      unawaited(
        _trackLikeSignal(
          userId,
          productId,
          liked?.category.name ?? 'other',
          nowLiked,
        ),
      );

      InteractionTracker().track(
        nowLiked ? InteractionType.like : InteractionType.unlike,
        product: liked,
        productId: productId,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        _cache.invalidateProduct(productId);
      });
    } catch (e) {
      _cache.invalidateProduct(productId);
      rethrow;
    }
  }

  Future<void> _trackLikeSignal(
    String userId,
    String productId,
    String category,
    bool liked,
  ) async {
    try {
      await _firestore.collection('user_activities').doc(userId).set({
        'likedProductIds': liked
            ? FieldValue.arrayUnion([productId])
            : FieldValue.arrayRemove([productId]),
        'categoryLikes': {category: FieldValue.increment(liked ? 1 : -1)},
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Failed to record like signal: $e');
    }
  }

  static const int _viewThrottleMs = 6 * 60 * 60 * 1000;

  Future<void> incrementViewCount(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'viewed_at_$productId';
      final last = prefs.getInt(key) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _viewThrottleMs) return;
      await prefs.setInt(key, now);

      await _firestore
          .collection(AppConstants.productsCollection)
          .doc(productId)
          .update({'viewCount': FieldValue.increment(1)});
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ProductModel>> searchProducts(String query) {
    try {
      return _firestore
          .collection(AppConstants.productsCollection)
          .where('isActive', isEqualTo: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
            final queryLower = query.toLowerCase();
            return snapshot.docs
                .map((doc) => ProductModel.fromFirestore(doc))
                .where(
                  (product) =>
                      !product.isSold &&
                      (product.title.toLowerCase().contains(queryLower) ||
                          product.description.toLowerCase().contains(
                            queryLower,
                          )),
                )
                .take(20)
                .toList();
          });
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ProductModel>> getFavoriteProducts(List<String> productIds) {
    try {
      if (productIds.isEmpty) {
        return Stream.value([]);
      }

      final chunks = <List<String>>[];
      for (var i = 0; i < productIds.length; i += 30) {
        chunks.add(
          productIds.sublist(
            i,
            i + 30 > productIds.length ? productIds.length : i + 30,
          ),
        );
      }

      final streams = chunks
          .map(
            (chunk) => _firestore
                .collection(AppConstants.productsCollection)
                .where(FieldPath.documentId, whereIn: chunk)
                .snapshots(),
          )
          .toList();

      if (streams.length == 1) {
        return streams.first.map((snapshot) {
          return snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList();
        });
      }

      late final StreamController<List<ProductModel>> controller;
      final snapshots = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
        streams.length,
        null,
      );
      final subscriptions =
          <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

      void emit() {
        if (snapshots.any((snapshot) => snapshot == null)) return;
        final products = <ProductModel>[];
        for (final snapshot in snapshots) {
          products.addAll(
            snapshot!.docs.map((doc) => ProductModel.fromFirestore(doc)),
          );
        }
        controller.add(products);
      }

      controller = StreamController<List<ProductModel>>(
        onListen: () {
          for (var i = 0; i < streams.length; i++) {
            subscriptions.add(
              streams[i].listen((snapshot) {
                snapshots[i] = snapshot;
                emit();
              }, onError: controller.addError),
            );
          }
        },
        onCancel: () async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        },
      );

      return controller.stream;
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ProductModel>> getProductsLikedByUser(String userId) {
    try {
      return _firestore
          .collection(AppConstants.productsCollection)
          .where('likedByUserIds', arrayContains: userId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => ProductModel.fromFirestore(doc))
                .toList(),
          );
    } catch (e) {
      rethrow;
    }
  }
}
