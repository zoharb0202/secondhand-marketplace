import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final String userId;
  final String query;
  final AlertCriteria parsedCriteria;
  final bool isActive;
  final int matchCount;
  final DateTime createdAt;
  final DateTime lastChecked;

  AlertModel({
    required this.id,
    required this.userId,
    required this.query,
    required this.parsedCriteria,
    required this.isActive,
    required this.matchCount,
    required this.createdAt,
    required this.lastChecked,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      userId: data['userId'] as String,
      query: data['query'] as String,
      parsedCriteria: AlertCriteria.fromJson(
        data['parsedCriteria'] as Map<String, dynamic>,
      ),
      isActive: data['isActive'] as bool? ?? true,
      matchCount: data['matchCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastChecked: (data['lastChecked'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'query': query,
      'parsedCriteria': parsedCriteria.toJson(),
      'isActive': isActive,
      'matchCount': matchCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastChecked': Timestamp.fromDate(lastChecked),
    };
  }

  AlertModel copyWith({
    String? id,
    String? userId,
    String? query,
    AlertCriteria? parsedCriteria,
    bool? isActive,
    int? matchCount,
    DateTime? createdAt,
    DateTime? lastChecked,
  }) {
    return AlertModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      query: query ?? this.query,
      parsedCriteria: parsedCriteria ?? this.parsedCriteria,
      isActive: isActive ?? this.isActive,
      matchCount: matchCount ?? this.matchCount,
      createdAt: createdAt ?? this.createdAt,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class AlertCriteria {
  final String? category;
  final List<String> keywords;
  final double? minPrice;
  final double? maxPrice;
  final String? condition;
  final String? city;
  final double? maxDistance;
  final String summary;

  AlertCriteria({
    this.category,
    this.keywords = const [],
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.city,
    this.maxDistance,
    required this.summary,
  });

  factory AlertCriteria.fromJson(Map<String, dynamic> json) {
    return AlertCriteria(
      category: json['category'] as String?,
      keywords:
          (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      minPrice: json['minPrice'] != null
          ? (json['minPrice'] as num).toDouble()
          : null,
      maxPrice: json['maxPrice'] != null
          ? (json['maxPrice'] as num).toDouble()
          : null,
      condition: json['condition'] as String?,
      city: json['city'] as String?,
      maxDistance: json['maxDistance'] != null
          ? (json['maxDistance'] as num).toDouble()
          : null,
      summary: json['summary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (category != null) 'category': category,
      'keywords': keywords,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (condition != null) 'condition': condition,
      if (city != null) 'city': city,
      if (maxDistance != null) 'maxDistance': maxDistance,
      'summary': summary,
    };
  }

  String get displaySummary {
    final parts = <String>[];

    if (category != null && category != 'אחר') {
      parts.add('קטגוריה: $category');
    }

    if (keywords.isNotEmpty) {
      parts.add('מילות מפתח: ${keywords.join(", ")}');
    }

    if (minPrice != null || maxPrice != null) {
      if (minPrice != null && maxPrice != null) {
        parts.add(
          'מחיר: ${minPrice!.toStringAsFixed(0)}-${maxPrice!.toStringAsFixed(0)} ₪',
        );
      } else if (maxPrice != null) {
        parts.add('עד ${maxPrice!.toStringAsFixed(0)} ₪');
      } else if (minPrice != null) {
        parts.add('מ-${minPrice!.toStringAsFixed(0)} ₪');
      }
    }

    if (condition != null) {
      parts.add('מצב: $condition');
    }

    if (city != null) {
      parts.add('עיר: $city');
    }

    if (maxDistance != null) {
      parts.add('עד ${maxDistance!.toStringAsFixed(0)} ק"מ');
    }

    return parts.isEmpty ? summary : parts.join(' • ');
  }
}

class AlertMatch {
  final String matchId;
  final String alertId;
  final String userId;
  final String productId;
  final int matchScore;
  final String matchReason;
  final bool isRead;
  final bool isNotified;
  final DateTime createdAt;
  final Map<String, dynamic>? product;

  AlertMatch({
    required this.matchId,
    required this.alertId,
    required this.userId,
    required this.productId,
    required this.matchScore,
    required this.matchReason,
    required this.isRead,
    required this.isNotified,
    required this.createdAt,
    this.product,
  });

  factory AlertMatch.fromJson(Map<String, dynamic> json) {
    return AlertMatch(
      matchId: json['matchId'] as String,
      alertId: json['alertId'] as String,
      userId: json['userId'] as String,
      productId: json['productId'] as String,
      matchScore: json['matchScore'] as int,
      matchReason: json['matchReason'] as String,
      isRead: json['isRead'] as bool? ?? false,
      isNotified: json['isNotified'] as bool? ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      product: json['product'] as Map<String, dynamic>?,
    );
  }

  factory AlertMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertMatch(
      matchId: doc.id,
      alertId: data['alertId'] as String,
      userId: data['userId'] as String,
      productId: data['productId'] as String,
      matchScore: data['matchScore'] as int,
      matchReason: data['matchReason'] as String,
      isRead: data['isRead'] as bool? ?? false,
      isNotified: data['isNotified'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      product: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'alertId': alertId,
      'userId': userId,
      'productId': productId,
      'matchScore': matchScore,
      'matchReason': matchReason,
      'isRead': isRead,
      'isNotified': isNotified,
      'createdAt': Timestamp.fromDate(createdAt),
      if (product != null) 'product': product,
    };
  }

  AlertMatch copyWith({
    String? matchId,
    String? alertId,
    String? userId,
    String? productId,
    int? matchScore,
    String? matchReason,
    bool? isRead,
    bool? isNotified,
    DateTime? createdAt,
    Map<String, dynamic>? product,
  }) {
    return AlertMatch(
      matchId: matchId ?? this.matchId,
      alertId: alertId ?? this.alertId,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      matchScore: matchScore ?? this.matchScore,
      matchReason: matchReason ?? this.matchReason,
      isRead: isRead ?? this.isRead,
      isNotified: isNotified ?? this.isNotified,
      createdAt: createdAt ?? this.createdAt,
      product: product ?? this.product,
    );
  }

  String get scoreColor {
    if (matchScore >= 80) return 'green';
    if (matchScore >= 60) return 'orange';
    return 'red';
  }

  String get scoreText {
    if (matchScore >= 80) return 'התאמה מעולה';
    if (matchScore >= 70) return 'התאמה טובה';
    if (matchScore >= 60) return 'התאמה סבירה';
    return 'התאמה חלשה';
  }
}
