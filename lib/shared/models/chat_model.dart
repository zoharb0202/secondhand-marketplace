import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String productId;
  final String sellerId;
  final String buyerId;

  final String productTitle;
  final String productImageUrl;
  final String sellerName;
  final String? sellerPhotoUrl;
  final String buyerName;
  final String? buyerPhotoUrl;

  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;

  final int sellerUnreadCount;
  final int buyerUnreadCount;

  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChatModel({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.buyerId,
    required this.productTitle,
    required this.productImageUrl,
    required this.sellerName,
    this.sellerPhotoUrl,
    required this.buyerName,
    this.buyerPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.sellerUnreadCount = 0,
    this.buyerUnreadCount = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      productTitle: data['productTitle'] ?? '',
      productImageUrl: data['productImageUrl'] ?? '',
      sellerName: data['sellerName'] ?? '',
      sellerPhotoUrl: data['sellerPhotoUrl'],
      buyerName: data['buyerName'] ?? '',
      buyerPhotoUrl: data['buyerPhotoUrl'],
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: data['lastMessageSenderId'],
      sellerUnreadCount: data['sellerUnreadCount'] ?? 0,
      buyerUnreadCount: data['buyerUnreadCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'productTitle': productTitle,
      'productImageUrl': productImageUrl,
      'sellerName': sellerName,
      'sellerPhotoUrl': sellerPhotoUrl,
      'buyerName': buyerName,
      'buyerPhotoUrl': buyerPhotoUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessageSenderId': lastMessageSenderId,
      'sellerUnreadCount': sellerUnreadCount,
      'buyerUnreadCount': buyerUnreadCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  ChatModel copyWith({
    String? id,
    String? productId,
    String? sellerId,
    String? buyerId,
    String? productTitle,
    String? productImageUrl,
    String? sellerName,
    String? sellerPhotoUrl,
    String? buyerName,
    String? buyerPhotoUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    int? sellerUnreadCount,
    int? buyerUnreadCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sellerId: sellerId ?? this.sellerId,
      buyerId: buyerId ?? this.buyerId,
      productTitle: productTitle ?? this.productTitle,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      sellerName: sellerName ?? this.sellerName,
      sellerPhotoUrl: sellerPhotoUrl ?? this.sellerPhotoUrl,
      buyerName: buyerName ?? this.buyerName,
      buyerPhotoUrl: buyerPhotoUrl ?? this.buyerPhotoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      sellerUnreadCount: sellerUnreadCount ?? this.sellerUnreadCount,
      buyerUnreadCount: buyerUnreadCount ?? this.buyerUnreadCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
