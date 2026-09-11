import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String productId;
  final String productTitle;
  final String? productImage;
  final double price;
  final int quantity;
  final String sellerId;
  final String sellerName;
  final int availableStock;

  CartItem({
    required this.productId,
    required this.productTitle,
    this.productImage,
    required this.price,
    required this.quantity,
    required this.sellerId,
    required this.sellerName,
    required this.availableStock,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['productId'] ?? '',
      productTitle: map['productTitle'] ?? '',
      productImage: map['productImage'],
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      availableStock: map['availableStock'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productTitle': productTitle,
      'productImage': productImage,
      'price': price,
      'quantity': quantity,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'availableStock': availableStock,
    };
  }

  double get totalPrice => price * quantity;

  bool get isInStock => availableStock > 0;

  bool get hasEnoughStock => quantity <= availableStock;

  CartItem copyWith({
    String? productId,
    String? productTitle,
    String? productImage,
    double? price,
    int? quantity,
    String? sellerId,
    String? sellerName,
    int? availableStock,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      availableStock: availableStock ?? this.availableStock,
    );
  }
}

class ShoppingCart {
  final String id;
  final String userId;
  final List<CartItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingCart({
    required this.id,
    required this.userId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingCart.empty(String userId) {
    return ShoppingCart(
      id: userId,
      userId: userId,
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory ShoppingCart.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShoppingCart(
      id: doc.id,
      userId: data['userId'] ?? '',
      items:
          (data['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  int get totalItems => items.fold(0, (total, item) => total + item.quantity);

  double get totalAmount =>
      items.fold(0.0, (total, item) => total + item.totalPrice);

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  CartItem? getItem(String productId) {
    try {
      return items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  bool hasProduct(String productId) {
    return items.any((item) => item.productId == productId);
  }

  ShoppingCart addItem(CartItem newItem) {
    final existingIndex = items.indexWhere(
      (item) => item.productId == newItem.productId,
    );

    if (existingIndex != -1) {
      final existing = items[existingIndex];
      final mergedQuantity = existing.quantity + newItem.quantity;
      final cappedQuantity = existing.availableStock > 0
          ? mergedQuantity.clamp(1, existing.availableStock).toInt()
          : mergedQuantity;
      final updatedItems = List<CartItem>.from(items);
      updatedItems[existingIndex] = existing.copyWith(quantity: cappedQuantity);
      return copyWith(items: updatedItems);
    } else {
      return copyWith(items: [...items, newItem]);
    }
  }

  ShoppingCart removeItem(String productId) {
    return copyWith(
      items: items.where((item) => item.productId != productId).toList(),
    );
  }

  ShoppingCart updateItemQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      return removeItem(productId);
    }

    final updatedItems = items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    return copyWith(items: updatedItems);
  }

  ShoppingCart clear() {
    return copyWith(items: []);
  }

  Map<String, List<CartItem>> groupBySeller() {
    final Map<String, List<CartItem>> grouped = {};

    for (final item in items) {
      if (!grouped.containsKey(item.sellerId)) {
        grouped[item.sellerId] = [];
      }
      grouped[item.sellerId]!.add(item);
    }

    return grouped;
  }

  double getTotalForSeller(String sellerId) {
    return items
        .where((item) => item.sellerId == sellerId)
        .fold(0.0, (total, item) => total + item.totalPrice);
  }

  List<CartItem> getItemsWithStockIssues() {
    return items.where((item) => !item.hasEnoughStock).toList();
  }

  bool get hasStockIssues => getItemsWithStockIssues().isNotEmpty;

  ShoppingCart copyWith({
    String? id,
    String? userId,
    List<CartItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingCart(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
