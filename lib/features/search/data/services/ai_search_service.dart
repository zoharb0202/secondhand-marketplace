import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AISearchService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<AISearchResult> searchProducts({
    required String query,
    int limit = 20,
  }) async {
    try {
      final callable = _functions.httpsCallable('aiProductSearch');
      final result = await callable.call({'query': query, 'limit': limit});

      final data = Map<String, dynamic>.from(result.data as Map);

      final productsData = data['products'] as List<dynamic>;
      final products = productsData
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();

      final searchParamsRaw = data['searchParams'] as Map;
      final searchParams = Map<String, dynamic>.from(searchParamsRaw);

      return AISearchResult(
        products: products,
        totalFound: data['totalFound'] as int? ?? products.length,
        message: data['message'] as String? ?? '',
        searchParams: SearchParameters.fromJson(searchParams),
        searchId: data['searchId'] as String?,
      );
    } catch (e) {
      throw Exception('Failed to perform AI search: $e');
    }
  }

  Future<ProductAnalysis> analyzeProductImage(String imageUrl) async {
    try {
      final callable = _functions.httpsCallable('analyzeProductImage');
      final result = await callable.call({'imageUrl': imageUrl});

      final data = Map<String, dynamic>.from(result.data as Map);
      return ProductAnalysis.fromJson(data);
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }

  Future<void> logSearchClick({
    required String productId,
    String? searchId,
    int? rank,
  }) async {
    try {
      await _functions
          .httpsCallable('logSearchClick')
          .call<dynamic>({
            'productId': productId,
            if (searchId != null) 'searchId': searchId,
            if (rank != null) 'rank': rank,
          })
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) print('ℹ️ logSearchClick failed (non-fatal): $e');
    }
  }

  Future<void> logListingOutcome({
    required String analysisId,
    required String productId,
  }) async {
    try {
      await _functions
          .httpsCallable('logListingOutcome')
          .call<dynamic>({'analysisId': analysisId, 'productId': productId})
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) print('ℹ️ logListingOutcome failed (non-fatal): $e');
    }
  }

  Future<String> enhanceDescription({
    required String description,
    String? title,
    String? category,
    String? subcategory,
    String? brand,
    String? model,
    String? condition,
  }) async {
    try {
      final callable = _functions.httpsCallable('enhanceDescription');
      final result = await callable.call({
        'description': description,
        if (title != null) 'title': title,
        if (category != null) 'category': category,
        if (subcategory != null) 'subcategory': subcategory,
        if (brand != null) 'brand': brand,
        if (model != null) 'model': model,
        if (condition != null) 'condition': condition,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return data['enhancedDescription'] as String;
    } catch (e) {
      throw Exception('Failed to enhance description: $e');
    }
  }

  Future<ModerationResult> moderateImage(String imageUrl) async {
    try {
      final callable = _functions.httpsCallable('moderateImage');
      final result = await callable.call({'imageUrl': imageUrl});

      final data = Map<String, dynamic>.from(result.data as Map);
      return ModerationResult(
        isAppropriate: data['isAppropriate'] as bool,
        reason: data['reason'] as String?,
        category: data['category'] as String?,
      );
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('Image moderation error: $e');
      }
      return ModerationResult(
        isAppropriate: true,
        reason: null,
        category: null,
      );
    }
  }

  Future<ChatbotResponse> sendMessage(
    String message, {
    List<ChatMessage>? conversationHistory,
  }) async {
    try {
      final callable = _functions.httpsCallable('chatbot');
      final result = await callable.call({
        'message': message,
        if (conversationHistory != null)
          'conversationHistory': conversationHistory
              .map((msg) => {'role': msg.role, 'content': msg.content})
              .toList(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return ChatbotResponse(
        response: data['response'] as String,
        timestamp: data['timestamp'] as int,
      );
    } catch (e) {
      throw Exception('Failed to get chatbot response: $e');
    }
  }

  Future<RecommendationsResponse> getPersonalizedRecommendations({
    required UserActivity userActivity,
    required List<ProductSummary> availableProducts,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'getPersonalizedRecommendations',
      );

      final result = await callable.call({
        'userActivity': userActivity.toJson(),
        'availableProducts': availableProducts.map((p) => p.toJson()).toList(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final recommendations = (data['recommendations'] as List)
          .map(
            (rec) => ProductRecommendation.fromJson(
              Map<String, dynamic>.from(rec as Map),
            ),
          )
          .toList();

      return RecommendationsResponse(
        recommendations: recommendations,
        timestamp:
            data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      throw Exception('Failed to get recommendations: $e');
    }
  }
}

class AISearchResult {
  final List<Map<String, dynamic>> products;
  final int totalFound;
  final String message;
  final SearchParameters searchParams;

  final String? searchId;

  AISearchResult({
    required this.products,
    required this.totalFound,
    required this.message,
    required this.searchParams,
    this.searchId,
  });
}

class SearchParameters {
  final List<String> keywords;
  final String? category;
  final String? subcategory;
  final double? minPrice;
  final double? maxPrice;
  final String? condition;
  final String? city;
  final String? brand;
  final String? model;

  SearchParameters({
    this.keywords = const [],
    this.category,
    this.subcategory,
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.city,
    this.brand,
    this.model,
  });

  factory SearchParameters.fromJson(Map<String, dynamic> json) {
    return SearchParameters(
      keywords:
          (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      condition: json['condition'] as String?,
      city: json['city'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keywords': keywords,
      'category': category,
      'subcategory': subcategory,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'condition': condition,
      'city': city,
      'brand': brand,
      'model': model,
    };
  }

  String toDisplayString() {
    final parts = <String>[];

    if (keywords.isNotEmpty) {
      parts.add('מילות מפתח: ${keywords.join(", ")}');
    }
    if (category != null) {
      parts.add('קטגוריה: $category');
    }
    if (subcategory != null) {
      parts.add('תת-קטגוריה: $subcategory');
    }
    if (minPrice != null || maxPrice != null) {
      if (minPrice != null && maxPrice != null) {
        parts.add('מחיר: ₪$minPrice - ₪$maxPrice');
      } else if (minPrice != null) {
        parts.add('מחיר מינימום: ₪$minPrice');
      } else if (maxPrice != null) {
        parts.add('מחיר מקסימום: ₪$maxPrice');
      }
    }
    if (condition != null) {
      parts.add('מצב: $condition');
    }
    if (city != null) {
      parts.add('מיקום: $city');
    }
    if (brand != null) {
      parts.add('מותג: $brand');
    }
    if (model != null) {
      parts.add('דגם: $model');
    }

    return parts.join(' • ');
  }
}

class ModerationResult {
  final bool isAppropriate;
  final String? reason;
  final String? category;

  ModerationResult({required this.isAppropriate, this.reason, this.category});
}

class ProductAnalysis {
  final String title;
  final String? brand;
  final String? model;
  final String? color;
  final String? condition;
  final String? category;
  final String? subcategory;
  final PriceEstimate? priceEstimate;
  final String? description;
  final List<String> features;
  final List<String> missingInfo;

  final String? analysisId;

  ProductAnalysis({
    required this.title,
    this.brand,
    this.model,
    this.color,
    this.condition,
    this.category,
    this.subcategory,
    this.priceEstimate,
    this.description,
    this.features = const [],
    this.missingInfo = const [],
    this.analysisId,
  });

  factory ProductAnalysis.fromJson(Map<String, dynamic> json) {
    return ProductAnalysis(
      title: json['title'] as String,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      color: json['color'] as String?,
      condition: json['condition'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      priceEstimate: json['priceEstimate'] != null
          ? PriceEstimate.fromJson(
              Map<String, dynamic>.from(json['priceEstimate'] as Map),
            )
          : null,
      description: json['description'] as String?,
      features:
          (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      missingInfo:
          (json['missingInfo'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      analysisId: json['analysisId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'brand': brand,
      'model': model,
      'color': color,
      'condition': condition,
      'category': category,
      'subcategory': subcategory,
      'priceEstimate': priceEstimate?.toJson(),
      'description': description,
      'features': features,
      'missingInfo': missingInfo,
      'analysisId': analysisId,
    };
  }
}

class PriceEstimate {
  final double min;
  final double max;

  PriceEstimate({required this.min, required this.max});

  factory PriceEstimate.fromJson(Map<String, dynamic> json) {
    return PriceEstimate(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'min': min, 'max': max};
  }

  String toDisplayString() {
    return '₪${min.toStringAsFixed(0)} - ₪${max.toStringAsFixed(0)}';
  }
}

class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});
}

class ChatbotResponse {
  final String response;
  final int timestamp;

  ChatbotResponse({required this.response, required this.timestamp});

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

class UserActivity {
  final List<ProductSummary> viewed;
  final List<String> searches;
  final List<ProductSummary> favorites;
  final List<ProductSummary> purchased;

  UserActivity({
    this.viewed = const [],
    this.searches = const [],
    this.favorites = const [],
    this.purchased = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'viewed': viewed.map((p) => p.toJson()).toList(),
      'searches': searches,
      'favorites': favorites.map((p) => p.toJson()).toList(),
      'purchased': purchased.map((p) => p.toJson()).toList(),
    };
  }
}

class ProductSummary {
  final String id;
  final String title;
  final String category;
  final String? subcategory;
  final double price;
  final String? condition;
  final String? brand;

  ProductSummary({
    required this.id,
    required this.title,
    required this.category,
    this.subcategory,
    required this.price,
    this.condition,
    this.brand,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      'price': price,
      if (condition != null) 'condition': condition,
      if (brand != null) 'brand': brand,
    };
  }
}

class ProductRecommendation {
  final String productId;
  final String reason;
  final int score;

  ProductRecommendation({
    required this.productId,
    required this.reason,
    required this.score,
  });

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) {
    return ProductRecommendation(
      productId: json['productId'] as String,
      reason: json['reason'] as String,
      score: (json['score'] as num).toInt(),
    );
  }
}

class RecommendationsResponse {
  final List<ProductRecommendation> recommendations;
  final int timestamp;

  RecommendationsResponse({
    required this.recommendations,
    required this.timestamp,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

final aiSearchServiceProvider = Provider<AISearchService>((ref) {
  return AISearchService();
});
