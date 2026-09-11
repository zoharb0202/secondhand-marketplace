import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user_activity_model.dart';
import '../../shared/models/user_interaction_model.dart';
import '../../shared/models/product_model.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int maxRecommendations = 20;
  static const int maxViewHistory = 50;
  static const int maxSearchHistory = 20;

  Future<void> trackProductModelView(
    String userId,
    String productId,
    String category,
  ) async {
    try {
      final activityRef = _firestore.collection('user_activities').doc(userId);
      final doc = await activityRef.get();

      final existingViews = doc.exists
          ? List<String>.from((doc.data()?['viewedProductIds'] ?? []) as List)
          : <String>[];

      final updatedViews = [
        productId,
        ...existingViews.where((id) => id != productId),
      ];
      if (updatedViews.length > maxViewHistory) {
        updatedViews.removeRange(maxViewHistory, updatedViews.length);
      }

      await activityRef.set({
        'viewedProductIds': updatedViews,
        'categoryViews': {category: FieldValue.increment(1)},
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Error tracking product view: $e');
    }
  }

  Future<void> trackDwell(
    String userId,
    String productId,
    String category,
    int seconds, {
    double? price,
  }) async {
    try {
      if (seconds <= 2) return;
      final weight = seconds >= 60 ? 5 : (seconds / 12).ceil().clamp(1, 5);

      final data = <String, dynamic>{
        'categoryDwell': {category: FieldValue.increment(weight)},
        'dwellSeconds': FieldValue.increment(seconds),
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (price != null && price > 0) {
        data['priceSum'] = FieldValue.increment(price);
        data['priceCount'] = FieldValue.increment(1);
        data['priceSumSq'] = FieldValue.increment(price * price);
      }

      await _firestore
          .collection('user_activities')
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Error tracking dwell: $e');
    }
  }

  Future<void> trackPurchase(
    String userId,
    String productId,
    String category,
    String sellerId,
  ) async {
    try {
      await _firestore.collection('user_activities').doc(userId).set({
        'purchasedProductIds': FieldValue.arrayUnion([productId]),
        'categoryPurchases': {category: FieldValue.increment(1)},
        'favoriteSellers': FieldValue.arrayUnion([sellerId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Error tracking purchase: $e');
    }
  }

  Future<void> trackSearch(String userId, String query) async {
    try {
      final activityRef = _firestore.collection('user_activities').doc(userId);
      final doc = await activityRef.get();

      final existingSearches = doc.exists
          ? List<String>.from((doc.data()?['searchHistory'] ?? []) as List)
          : <String>[];

      final updatedSearches = [
        query,
        ...existingSearches.where((q) => q != query),
      ];
      if (updatedSearches.length > maxSearchHistory) {
        updatedSearches.removeRange(maxSearchHistory, updatedSearches.length);
      }

      await activityRef.set({
        'searchHistory': updatedSearches,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Error tracking search: $e');
    }
  }

  Future<void> trackLike(
    String userId,
    String productId,
    String category, {
    required bool liked,
  }) async {
    try {
      await _firestore.collection('user_activities').doc(userId).set({
        'likedProductIds': liked
            ? FieldValue.arrayUnion([productId])
            : FieldValue.arrayRemove([productId]),
        'categoryLikes': {category: FieldValue.increment(liked ? 1 : -1)},
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Error tracking like: $e');
    }
  }

  Future<List<ProductRecommendation>> getRecommendations(String userId) async {
    try {
      final activityDoc = await _firestore
          .collection('user_activities')
          .doc(userId)
          .get();
      if (!activityDoc.exists) {
        return await _getTrendingProductModels();
      }

      final activity = UserActivity.fromFirestore(activityDoc);
      final recommendations = <ProductRecommendation>[];

      if (activity.favoriteSellers.isNotEmpty) {
        final sellerProductModels = await _getProductsFromSellers(
          activity.favoriteSellers,
          activity.purchasedProductIds,
        );
        recommendations.addAll(
          sellerProductModels.map(
            (p) => ProductRecommendation(
              productId: p.id,
              score: 90,
              reason: RecommendationReason.favoriteSeller,
              generatedAt: DateTime.now(),
            ),
          ),
        );
      }

      if (activity.categoryPurchases.isNotEmpty) {
        final topCategories = _getTopCategories(activity.categoryPurchases, 3);
        for (final category in topCategories) {
          final categoryProductModels = await _getProductsByCategory(
            category,
            activity.viewedProductIds + activity.purchasedProductIds,
          );
          recommendations.addAll(
            categoryProductModels.map(
              (p) => ProductRecommendation(
                productId: p.id,
                score: 80,
                reason: RecommendationReason.categoryMatch,
                generatedAt: DateTime.now(),
              ),
            ),
          );
        }
      }

      if (activity.viewedProductIds.isNotEmpty) {
        final recentViews = activity.viewedProductIds.take(10).toList();
        final similarProductModels = await _getSimilarProducts(
          recentViews,
          activity.purchasedProductIds,
        );
        recommendations.addAll(
          similarProductModels.map(
            (p) => ProductRecommendation(
              productId: p.id,
              score: 70,
              reason: RecommendationReason.viewedSimilar,
              generatedAt: DateTime.now(),
            ),
          ),
        );
      }

      if (recommendations.length < maxRecommendations) {
        final trending = await _getTrendingProductModels();
        recommendations.addAll(trending);
      }

      final uniqueRecommendations = <String, ProductRecommendation>{};
      for (final rec in recommendations) {
        if (!uniqueRecommendations.containsKey(rec.productId)) {
          uniqueRecommendations[rec.productId] = rec;
        }
      }

      final sorted = uniqueRecommendations.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      return sorted.take(maxRecommendations).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting recommendations: $e');
      return _getTrendingProductModels();
    }
  }

  Future<List<ProductModel>> _getProductsFromSellers(
    List<String> sellerIds,
    List<String> excludeIds,
  ) async {
    try {
      final topSellers = sellerIds.take(3).toList();
      final products = <ProductModel>[];

      for (final sellerId in topSellers) {
        final snapshot = await _firestore
            .collection('products')
            .where('sellerId', isEqualTo: sellerId)
            .where('isAvailable', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        for (final doc in snapshot.docs) {
          final product = ProductModel.fromFirestore(doc);
          if (!excludeIds.contains(product.id)) {
            products.add(product);
          }
        }
      }

      return products;
    } catch (e) {
      if (kDebugMode) print('Error getting seller products: $e');
      return [];
    }
  }

  Future<List<ProductModel>> _getProductsByCategory(
    String category,
    List<String> excludeIds,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('category', isEqualTo: category)
          .where('isAvailable', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final products = <ProductModel>[];
      for (final doc in snapshot.docs) {
        final product = ProductModel.fromFirestore(doc);
        if (!excludeIds.contains(product.id)) {
          products.add(product);
        }
      }

      return products;
    } catch (e) {
      if (kDebugMode) print('Error getting category products: $e');
      return [];
    }
  }

  Future<List<ProductModel>> _getSimilarProducts(
    List<String> viewedProductIds,
    List<String> excludeIds,
  ) async {
    try {
      final categories = <String>[];
      for (final productId in viewedProductIds.take(5)) {
        final doc = await _firestore
            .collection('products')
            .doc(productId)
            .get();
        if (doc.exists) {
          final product = ProductModel.fromFirestore(doc);
          final categoryName = product.category.name;
          if (!categories.contains(categoryName)) {
            categories.add(categoryName);
          }
        }
      }

      final products = <ProductModel>[];
      for (final category in categories) {
        final categoryProductModels = await _getProductsByCategory(
          category,
          excludeIds,
        );
        products.addAll(categoryProductModels.take(3));
      }

      return products;
    } catch (e) {
      if (kDebugMode) print('Error getting similar products: $e');
      return [];
    }
  }

  Future<List<ProductRecommendation>> _getTrendingProductModels() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isAvailable', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(maxRecommendations)
          .get();

      return snapshot.docs.map((doc) {
        final product = ProductModel.fromFirestore(doc);
        return ProductRecommendation(
          productId: product.id,
          score: 50,
          reason: RecommendationReason.trending,
          generatedAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting trending products: $e');
      return [];
    }
  }

  List<String> _getTopCategories(Map<String, int> categoryMap, int count) {
    final sorted = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(count).map((e) => e.key).toList();
  }

  Future<UserActivity?> getUserActivity(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_activities')
          .doc(userId)
          .get();
      if (!doc.exists) return null;
      return UserActivity.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) print('Error getting user activity: $e');
      return null;
    }
  }

  Future<List<UserInteractionModel>> getUserInteractions(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_activities')
          .doc(userId)
          .get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};

      final likedProductIds = List<String>.from(data['likedProductIds'] ?? []);
      final searchHistory = List<String>.from(data['searchHistory'] ?? []);
      final now = DateTime.now();

      final interactions = <UserInteractionModel>[];
      for (final pid in likedProductIds) {
        interactions.add(
          UserInteractionModel(
            id: 'like_$pid',
            userId: userId,
            productId: pid,
            type: InteractionType.like,
            timestamp: now,
          ),
        );
      }
      for (final term in searchHistory) {
        interactions.add(
          UserInteractionModel(
            id: 'search_$term',
            userId: userId,
            productId: '',
            type: InteractionType.search,
            timestamp: now,
            category: term,
          ),
        );
      }
      return interactions;
    } catch (e) {
      if (kDebugMode) print('Error getting user interactions: $e');
      return [];
    }
  }

  Future<UserTasteProfile> getTasteProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_activities')
          .doc(userId)
          .get();
      if (!doc.exists) return UserTasteProfile.empty();
      final data = doc.data() ?? {};

      Map<String, int> intMap(dynamic v) => v is Map
          ? v.map((k, val) => MapEntry(k.toString(), (val as num).toInt()))
          : <String, int>{};

      final categoryViews = intMap(data['categoryViews']);
      final categoryDwell = intMap(data['categoryDwell']);
      final categoryLikes = intMap(data['categoryLikes']);
      final categoryCartAdds = intMap(data['categoryCartAdds']);
      final categoryPurchases = intMap(data['categoryPurchases']);

      final affinity = <String, double>{};
      void fold(Map<String, int> m, double w) {
        m.forEach((k, v) => affinity[k] = (affinity[k] ?? 0) + v * w);
      }

      fold(categoryViews, 1.0);
      fold(categoryDwell, 1.0);
      fold(categoryCartAdds, 2.0);
      fold(categoryLikes, 3.0);
      fold(categoryPurchases, 5.0);
      affinity.removeWhere((_, v) => v <= 0);

      final priceRange = _computePriceBand(data);
      final likedProductIds = Set<String>.from(data['likedProductIds'] ?? []);
      final favoriteSellers = Set<String>.from(data['favoriteSellers'] ?? []);
      final searchHistory = List<String>.from(data['searchHistory'] ?? []);

      final totalViews = categoryViews.values.fold<int>(0, (a, b) => a + b);
      final totalPurchases = List<String>.from(
        data['purchasedProductIds'] ?? [],
      ).length;

      return UserTasteProfile(
        categoryAffinity: affinity,
        avgPrice: priceRange.avg,
        minPrice: priceRange.min,
        maxPrice: priceRange.max,
        favoriteSellers: favoriteSellers,
        likedProductIds: likedProductIds,
        searchHistory: searchHistory,
        totalViews: totalViews,
        totalLikes: likedProductIds.length,
        totalSearches: searchHistory.length,
        totalPurchases: totalPurchases,
      );
    } catch (e) {
      if (kDebugMode) print('Error building taste profile: $e');
      return UserTasteProfile.empty();
    }
  }

  ({double? avg, double? min, double? max}) _computePriceBand(
    Map<String, dynamic> data,
  ) {
    final count = ((data['priceCount'] ?? 0) as num).toInt();
    if (count <= 0) return (avg: null, min: null, max: null);
    final sum = ((data['priceSum'] ?? 0) as num).toDouble();
    final sumSq = ((data['priceSumSq'] ?? 0) as num).toDouble();
    final avg = sum / count;
    final variance = (sumSq / count) - (avg * avg);
    final std = variance > 0 ? math.sqrt(variance) : 0.0;
    final min = (avg - std).clamp(0.0, double.infinity).toDouble();
    final max = avg + std;
    return (avg: avg, min: min, max: max);
  }

  Future<List<ProductModel>> sortByRelevance({
    required String userId,
    required List<ProductModel> products,
  }) async {
    try {
      final recommendations = await getRecommendations(userId);

      final scoreMap = <String, double>{};
      for (final rec in recommendations) {
        scoreMap[rec.productId] = rec.score;
      }

      final sorted = List<ProductModel>.from(products);
      sorted.sort((a, b) {
        final scoreA = scoreMap[a.id] ?? 0;
        final scoreB = scoreMap[b.id] ?? 0;
        return scoreB.compareTo(scoreA);
      });

      return sorted;
    } catch (e) {
      if (kDebugMode) print('Error sorting by relevance: $e');
      return products;
    }
  }

  Future<void> recordInteraction({
    required String userId,
    required String productId,
    required String type,
    String? category,
    String? sellerId,
  }) async {
    try {
      switch (type.toLowerCase()) {
        case 'like':
        case 'favorite':
          if (category != null) {
            await trackProductModelView(userId, productId, category);
          }
          break;
        case 'view':
          if (category != null) {
            await trackProductModelView(userId, productId, category);
          }
          break;
        case 'purchase':
          if (category != null && sellerId != null) {
            await trackPurchase(userId, productId, category, sellerId);
          }
          break;
        case 'search':
          if (category != null) {
            await trackSearch(userId, category);
          }
          break;
        default:
          break;
      }
    } catch (e) {
      if (kDebugMode) print('Error recording interaction: $e');
    }
  }

  Future<Map<String, dynamic>> getUserPreferences(String userId) async {
    try {
      final profile = await getTasteProfile(userId);
      if (profile.isEmpty) {
        return {
          'favoriteCategories': <String>[],
          'favoriteSellers': <String>[],
          'priceRange': {'min': 0.0, 'max': 0.0},
        };
      }

      return {
        'favoriteCategories': profile.topCategories(5),
        'favoriteSellers': profile.favoriteSellers.toList(),
        'priceRange': {
          'min': profile.minPrice ?? 0.0,
          'max': profile.maxPrice ?? 0.0,
        },
      };
    } catch (e) {
      if (kDebugMode) print('Error getting user preferences: $e');
      return {
        'favoriteCategories': <String>[],
        'favoriteSellers': <String>[],
        'priceRange': {'min': 0.0, 'max': 0.0},
      };
    }
  }
}

class UserTasteProfile {
  final Map<String, double> categoryAffinity;
  final double? avgPrice;
  final double? minPrice;
  final double? maxPrice;
  final Set<String> favoriteSellers;
  final Set<String> likedProductIds;
  final List<String> searchHistory;
  final int totalViews;
  final int totalLikes;
  final int totalSearches;
  final int totalPurchases;

  const UserTasteProfile({
    required this.categoryAffinity,
    required this.avgPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.favoriteSellers,
    required this.likedProductIds,
    required this.searchHistory,
    required this.totalViews,
    required this.totalLikes,
    required this.totalSearches,
    required this.totalPurchases,
  });

  factory UserTasteProfile.empty() => const UserTasteProfile(
    categoryAffinity: {},
    avgPrice: null,
    minPrice: null,
    maxPrice: null,
    favoriteSellers: {},
    likedProductIds: {},
    searchHistory: [],
    totalViews: 0,
    totalLikes: 0,
    totalSearches: 0,
    totalPurchases: 0,
  );

  bool get isEmpty =>
      categoryAffinity.isEmpty &&
      totalViews == 0 &&
      totalLikes == 0 &&
      totalSearches == 0 &&
      totalPurchases == 0;

  double get maxAffinity =>
      categoryAffinity.values.fold<double>(0, (m, v) => v > m ? v : m);

  List<String> topCategories(int n) {
    final sorted = categoryAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  int get totalInteractions =>
      totalViews + totalLikes + totalSearches + totalPurchases;
}
