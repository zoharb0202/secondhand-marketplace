import 'package:cloud_firestore/cloud_firestore.dart';

class UserActivity {
  final String userId;
  final List<String> viewedProductIds;
  final List<String> purchasedProductIds;
  final Map<String, int> categoryViews;
  final Map<String, int> categoryPurchases;
  final List<String> favoriteSellers;
  final List<String> searchHistory;
  final DateTime lastUpdated;

  const UserActivity({
    required this.userId,
    required this.viewedProductIds,
    required this.purchasedProductIds,
    required this.categoryViews,
    required this.categoryPurchases,
    required this.favoriteSellers,
    required this.searchHistory,
    required this.lastUpdated,
  });

  factory UserActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserActivity(
      userId: doc.id,
      viewedProductIds: List<String>.from(data['viewedProductIds'] ?? []),
      purchasedProductIds: List<String>.from(data['purchasedProductIds'] ?? []),
      categoryViews: Map<String, int>.from(data['categoryViews'] ?? {}),
      categoryPurchases: Map<String, int>.from(data['categoryPurchases'] ?? {}),
      favoriteSellers: List<String>.from(data['favoriteSellers'] ?? []),
      searchHistory: List<String>.from(data['searchHistory'] ?? []),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'viewedProductIds': viewedProductIds,
      'purchasedProductIds': purchasedProductIds,
      'categoryViews': categoryViews,
      'categoryPurchases': categoryPurchases,
      'favoriteSellers': favoriteSellers,
      'searchHistory': searchHistory,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  UserActivity copyWith({
    String? userId,
    List<String>? viewedProductIds,
    List<String>? purchasedProductIds,
    Map<String, int>? categoryViews,
    Map<String, int>? categoryPurchases,
    List<String>? favoriteSellers,
    List<String>? searchHistory,
    DateTime? lastUpdated,
  }) {
    return UserActivity(
      userId: userId ?? this.userId,
      viewedProductIds: viewedProductIds ?? this.viewedProductIds,
      purchasedProductIds: purchasedProductIds ?? this.purchasedProductIds,
      categoryViews: categoryViews ?? this.categoryViews,
      categoryPurchases: categoryPurchases ?? this.categoryPurchases,
      favoriteSellers: favoriteSellers ?? this.favoriteSellers,
      searchHistory: searchHistory ?? this.searchHistory,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory UserActivity.empty(String userId) {
    return UserActivity(
      userId: userId,
      viewedProductIds: [],
      purchasedProductIds: [],
      categoryViews: {},
      categoryPurchases: {},
      favoriteSellers: [],
      searchHistory: [],
      lastUpdated: DateTime.now(),
    );
  }
}

enum RecommendationReason {
  viewedSimilar,
  boughtSimilar,
  categoryMatch,
  popularInCategory,
  favoriteSeller,
  trending,
  newArrival,
  priceMatch,
}

extension RecommendationReasonExtension on RecommendationReason {
  String get displayText {
    switch (this) {
      case RecommendationReason.viewedSimilar:
        return 'בהתבסס על מוצרים שצפית בהם';
      case RecommendationReason.boughtSimilar:
        return 'בהתבסס על קניות קודמות';
      case RecommendationReason.categoryMatch:
        return 'מתאים להעדפות שלך';
      case RecommendationReason.popularInCategory:
        return 'פופולרי בקטגוריה שאתה אוהב';
      case RecommendationReason.favoriteSeller:
        return 'ממוכר שקנית ממנו';
      case RecommendationReason.trending:
        return 'טרנדי עכשיו';
      case RecommendationReason.newArrival:
        return 'חדש בקטגוריה שלך';
      case RecommendationReason.priceMatch:
        return 'במחיר שמתאים לך';
    }
  }

  String get icon {
    switch (this) {
      case RecommendationReason.viewedSimilar:
        return '👀';
      case RecommendationReason.boughtSimilar:
        return '🛍️';
      case RecommendationReason.categoryMatch:
        return '🎯';
      case RecommendationReason.popularInCategory:
        return '🔥';
      case RecommendationReason.favoriteSeller:
        return '⭐';
      case RecommendationReason.trending:
        return '📈';
      case RecommendationReason.newArrival:
        return '🆕';
      case RecommendationReason.priceMatch:
        return '💰';
    }
  }
}

class ProductRecommendation {
  final String productId;
  final double score;
  final RecommendationReason reason;
  final DateTime generatedAt;

  const ProductRecommendation({
    required this.productId,
    required this.score,
    required this.reason,
    required this.generatedAt,
  });
}
