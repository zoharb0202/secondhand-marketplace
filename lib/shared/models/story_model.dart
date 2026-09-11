import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String sellerId;
  final String sellerName;
  final String? sellerPhoto;
  final String imageUrl;
  final String? caption;
  final String? productId;
  final String? productTitle;
  final DateTime createdAt;
  final DateTime expiresAt;

  const StoryModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    this.sellerPhoto,
    required this.imageUrl,
    this.caption,
    this.productId,
    this.productTitle,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryModel(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'מוכר',
      sellerPhoto: data['sellerPhoto'],
      imageUrl: data['imageUrl'] ?? '',
      caption: data['caption'],
      productId: data['productId'],
      productTitle: data['productTitle'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'sellerId': sellerId,
    'sellerName': sellerName,
    'sellerPhoto': sellerPhoto,
    'imageUrl': imageUrl,
    'caption': caption,
    'productId': productId,
    'productTitle': productTitle,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
  };
}

class SellerStories {
  final String sellerId;
  final String sellerName;
  final String? sellerPhoto;
  final List<StoryModel> stories;

  const SellerStories({
    required this.sellerId,
    required this.sellerName,
    this.sellerPhoto,
    required this.stories,
  });
}
