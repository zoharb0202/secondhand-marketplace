import 'package:cloud_firestore/cloud_firestore.dart';

class UserInteractionModel {
  final String id;
  final String userId;
  final String productId;
  final InteractionType type;
  final DateTime timestamp;

  final String? category;
  final List<String>? tags;
  final double? price;
  final String? sellerId;

  UserInteractionModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.type,
    required this.timestamp,
    this.category,
    this.tags,
    this.price,
    this.sellerId,
  });

  factory UserInteractionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserInteractionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      productId: data['productId'] ?? '',
      type: InteractionType.values.byName(data['type'] ?? 'view'),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      category: data['category'],
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      price: data['price']?.toDouble(),
      sellerId: data['sellerId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'productId': productId,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'category': category,
      'tags': tags,
      'price': price,
      'sellerId': sellerId,
    };
  }
}

enum InteractionType {
  view,
  like,
  dislike,
  favorite,
  unfavorite,
  search,
  purchase,
  chat,
}

class UserPreferencesModel {
  final String userId;

  final Map<String, double> categoryScores;

  final Map<String, double> tagScores;

  final double? preferredMinPrice;
  final double? preferredMaxPrice;

  final Map<String, int> sellerInteractions;

  final List<String> likedProductIds;

  final List<String> dislikedProductIds;

  final DateTime lastUpdated;

  UserPreferencesModel({
    required this.userId,
    this.categoryScores = const {},
    this.tagScores = const {},
    this.preferredMinPrice,
    this.preferredMaxPrice,
    this.sellerInteractions = const {},
    this.likedProductIds = const [],
    this.dislikedProductIds = const [],
    required this.lastUpdated,
  });

  factory UserPreferencesModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPreferencesModel(
      userId: doc.id,
      categoryScores: Map<String, double>.from(data['categoryScores'] ?? {}),
      tagScores: Map<String, double>.from(data['tagScores'] ?? {}),
      preferredMinPrice: data['preferredMinPrice']?.toDouble(),
      preferredMaxPrice: data['preferredMaxPrice']?.toDouble(),
      sellerInteractions: Map<String, int>.from(
        data['sellerInteractions'] ?? {},
      ),
      likedProductIds: List<String>.from(data['likedProductIds'] ?? []),
      dislikedProductIds: List<String>.from(data['dislikedProductIds'] ?? []),
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categoryScores': categoryScores,
      'tagScores': tagScores,
      'preferredMinPrice': preferredMinPrice,
      'preferredMaxPrice': preferredMaxPrice,
      'sellerInteractions': sellerInteractions,
      'likedProductIds': likedProductIds,
      'dislikedProductIds': dislikedProductIds,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}
