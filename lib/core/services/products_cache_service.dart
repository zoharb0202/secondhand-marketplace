import 'package:flutter/foundation.dart';
import '../../shared/models/product_model.dart';

class ProductsCacheService {
  static final ProductsCacheService _instance =
      ProductsCacheService._internal();
  factory ProductsCacheService() => _instance;
  ProductsCacheService._internal();

  final Map<String, _CachedProduct> _productsCache = {};
  final Map<String, List<String>> _categoryCache = {};

  static const Duration _cacheExpiration = Duration(minutes: 5);
  static const int _maxCacheSize = 500;

  int _hits = 0;
  int _misses = 0;

  ProductModel? getProduct(String productId) {
    final cached = _productsCache[productId];

    if (cached != null && !cached.isExpired) {
      _hits++;
      if (kDebugMode) {
        print(
          '✅ Cache HIT for product: $productId ($_hits/${_hits + _misses})',
        );
      }
      return cached.product;
    }

    _misses++;
    if (kDebugMode) {
      print('❌ Cache MISS for product: $productId ($_hits/${_hits + _misses})');
    }
    return null;
  }

  void addProduct(ProductModel product) {
    if (_productsCache.length >= _maxCacheSize) {
      _evictOldest();
    }

    _productsCache[product.id] = _CachedProduct(
      product: product,
      cachedAt: DateTime.now(),
    );
  }

  void addProducts(List<ProductModel> products) {
    for (final product in products) {
      addProduct(product);
    }
  }

  List<ProductModel>? getProductsByCategory(String categoryId) {
    final productIds = _categoryCache[categoryId];
    if (productIds == null) return null;

    final products = <ProductModel>[];
    for (final id in productIds) {
      final product = getProduct(id);
      if (product != null) {
        products.add(product);
      } else {
        _categoryCache.remove(categoryId);
        return null;
      }
    }

    return products;
  }

  void cacheProductsByCategory(String categoryId, List<ProductModel> products) {
    addProducts(products);
    _categoryCache[categoryId] = products.map((p) => p.id).toList();
  }

  void invalidateProduct(String productId) {
    _productsCache.remove(productId);

    _categoryCache.removeWhere(
      (key, productIds) => productIds.contains(productId),
    );
  }

  void invalidateCategory(String categoryId) {
    _categoryCache.remove(categoryId);
  }

  void clearAll() {
    _productsCache.clear();
    _categoryCache.clear();
    _hits = 0;
    _misses = 0;
    if (kDebugMode) print('🗑️ Cache cleared');
  }

  Map<String, dynamic> getStats() {
    final hitRate = _hits + _misses > 0
        ? (_hits / (_hits + _misses) * 100).toStringAsFixed(1)
        : '0.0';

    return {
      'hits': _hits,
      'misses': _misses,
      'hitRate': '$hitRate%',
      'cachedProducts': _productsCache.length,
      'cachedCategories': _categoryCache.length,
    };
  }

  void _evictOldest() {
    if (_productsCache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _productsCache.entries) {
      if (oldestTime == null || entry.value.cachedAt.isBefore(oldestTime)) {
        oldestTime = entry.value.cachedAt;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _productsCache.remove(oldestKey);
      if (kDebugMode) {
        print('🗑️ Evicted oldest product from cache: $oldestKey');
      }
    }
  }

  void cleanExpired() {
    final expiredKeys = <String>[];

    for (final entry in _productsCache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _productsCache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      if (kDebugMode) {
        print('🗑️ Cleaned ${expiredKeys.length} expired products from cache');
      }
    }
  }
}

class _CachedProduct {
  final ProductModel product;
  final DateTime cachedAt;

  _CachedProduct({required this.product, required this.cachedAt});

  bool get isExpired {
    return DateTime.now().difference(cachedAt) >
        ProductsCacheService._cacheExpiration;
  }
}
