import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/models/cart_model.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../core/services/interaction_tracker.dart';

enum AddToCartOutcome {
  added,
  incremented,
  alreadyInCart,
  stockLimitReached,
  outOfStock,
}

class AddToCartResult {
  final AddToCartOutcome outcome;
  final int quantity;
  const AddToCartResult(this.outcome, this.quantity);
}

class CartRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'carts';

  Stream<ShoppingCart> getCartStream(String userId) {
    return _firestore.collection(_collection).doc(userId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return ShoppingCart.fromFirestore(snapshot);
      } else {
        return ShoppingCart.empty(userId);
      }
    });
  }

  Future<ShoppingCart> getCart(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return ShoppingCart.fromFirestore(doc);
      } else {
        return ShoppingCart.empty(userId);
      }
    } catch (e) {
      debugPrint('Error getting cart: $e');
      rethrow;
    }
  }

  Future<T> _mutateCart<T>(
    String userId,
    (ShoppingCart, T) Function(ShoppingCart cart) mutate,
  ) async {
    final docRef = _firestore.collection(_collection).doc(userId);
    late T result;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final cart = snapshot.exists
          ? ShoppingCart.fromFirestore(snapshot)
          : ShoppingCart.empty(userId);
      final (newCart, value) = mutate(cart);
      result = value;
      transaction.set(docRef, newCart.toFirestore(), SetOptions(merge: true));
    });
    return result;
  }

  (ShoppingCart, AddToCartResult) _applyAddItem(
    ShoppingCart cart,
    CartItem newItem,
  ) {
    if (newItem.availableStock <= 0) {
      return (cart, const AddToCartResult(AddToCartOutcome.outOfStock, 0));
    }

    final existingIndex = cart.items.indexWhere(
      (i) => i.productId == newItem.productId,
    );

    if (existingIndex == -1) {
      return (
        cart.copyWith(items: [...cart.items, newItem]),
        AddToCartResult(AddToCartOutcome.added, newItem.quantity),
      );
    }

    final existing = cart.items[existingIndex];

    if (newItem.availableStock <= 1) {
      return (
        cart,
        AddToCartResult(AddToCartOutcome.alreadyInCart, existing.quantity),
      );
    }

    if (existing.quantity >= newItem.availableStock) {
      return (
        cart,
        AddToCartResult(AddToCartOutcome.stockLimitReached, existing.quantity),
      );
    }

    final newQuantity = existing.quantity + 1;
    final updatedItems = List<CartItem>.from(cart.items);
    updatedItems[existingIndex] = existing.copyWith(
      quantity: newQuantity,
      price: newItem.price,
      availableStock: newItem.availableStock,
    );
    return (
      cart.copyWith(items: updatedItems),
      AddToCartResult(AddToCartOutcome.incremented, newQuantity),
    );
  }

  Future<AddToCartResult> addItem(String userId, CartItem item) async {
    try {
      final result = await _mutateCart<AddToCartResult>(
        userId,
        (cart) => _applyAddItem(cart, item),
      );
      debugPrint(
        'Add-to-cart outcome for ${item.productTitle}: ${result.outcome}',
      );
      if (result.outcome == AddToCartOutcome.added ||
          result.outcome == AddToCartOutcome.incremented) {
        unawaited(_trackCartAdd(userId, item));
      }
      return result;
    } catch (e) {
      debugPrint('Error adding item to cart: $e');
      rethrow;
    }
  }

  Future<void> _trackCartAdd(String userId, CartItem item) async {
    try {
      String category = 'other';
      ProductModel? product;
      try {
        final productDoc = await _firestore
            .collection('products')
            .doc(item.productId)
            .get();
        final raw = productDoc.data()?['category'];
        if (raw is String && raw.isNotEmpty) category = raw;
        if (productDoc.exists) product = ProductModel.fromFirestore(productDoc);
      } catch (_) {}

      final price = item.price;
      final data = <String, dynamic>{
        'categoryCartAdds': {category: FieldValue.increment(1)},
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (price > 0) {
        data['priceSum'] = FieldValue.increment(price);
        data['priceCount'] = FieldValue.increment(1);
        data['priceSumSq'] = FieldValue.increment(price * price);
      }

      await _firestore
          .collection('user_activities')
          .doc(userId)
          .set(data, SetOptions(merge: true));

      InteractionTracker().track(
        InteractionType.addToCart,
        product: product,
        productId: item.productId,
        category: category,
        price: price,
        sellerId: item.sellerId,
      );
    } catch (e) {
      debugPrint('Failed to record cart-add signal: $e');
    }
  }

  Future<void> removeItem(String userId, String productId) async {
    try {
      await _mutateCart<void>(
        userId,
        (cart) => (cart.removeItem(productId), null),
      );
      debugPrint('Removed item from cart: $productId');
      InteractionTracker().track(
        InteractionType.removeFromCart,
        productId: productId,
      );
    } catch (e) {
      debugPrint('Error removing item from cart: $e');
      rethrow;
    }
  }

  Future<void> updateItemQuantity(
    String userId,
    String productId,
    int quantity,
  ) async {
    try {
      await _mutateCart<void>(
        userId,
        (cart) => (cart.updateItemQuantity(productId, quantity), null),
      );
      debugPrint('Updated item quantity: $productId = $quantity');
    } catch (e) {
      debugPrint('Error updating item quantity: $e');
      rethrow;
    }
  }

  Future<void> clearCart(String userId) async {
    try {
      await _mutateCart<void>(userId, (cart) => (cart.clear(), null));
      debugPrint('Cleared cart for user: $userId');
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      rethrow;
    }
  }

  Future<void> updateCart(ShoppingCart cart) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(cart.userId)
          .set(cart.toFirestore(), SetOptions(merge: true));
      debugPrint('Updated cart for user: ${cart.userId}');
    } catch (e) {
      debugPrint('Error updating cart: $e');
      rethrow;
    }
  }

  Future<ShoppingCart> syncCartWithProducts(String userId) async {
    try {
      final cart = await getCart(userId);
      if (cart.isEmpty) return cart;

      final productIds = cart.items
          .map((item) => item.productId)
          .toSet()
          .toList();
      final chunks = <List<String>>[];
      for (var i = 0; i < productIds.length; i += 30) {
        chunks.add(
          productIds.sublist(
            i,
            i + 30 > productIds.length ? productIds.length : i + 30,
          ),
        );
      }

      final snapshots = await Future.wait(
        chunks.map(
          (chunk) => _firestore
              .collection('products')
              .where(FieldPath.documentId, whereIn: chunk)
              .get(),
        ),
      );

      final productDataById = <String, Map<String, dynamic>>{};
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          productDataById[doc.id] = doc.data();
        }
      }

      final updatedItems = <CartItem>[];

      for (final item in cart.items) {
        final productData = productDataById[item.productId];

        if (productData != null) {
          final hasStock = productData['stockTotal'] != null;
          final refreshedAvailableStock = hasStock
              ? ((productData['stockRemaining'] as num?)?.toInt() ?? 0)
              : 1;
          final updatedItem = item.copyWith(
            price: (productData['price'] ?? item.price).toDouble(),
            availableStock: refreshedAvailableStock,
            productTitle: productData['title'] ?? item.productTitle,
            productImage: productData['images']?[0] ?? item.productImage,
          );

          if (productData['isActive'] == true) {
            updatedItems.add(updatedItem);
          } else {
            debugPrint(
              'Product ${item.productId} is no longer active, removing from cart',
            );
          }
        } else {
          debugPrint('Product ${item.productId} not found, removing from cart');
        }
      }

      final updatedCart = cart.copyWith(items: updatedItems);
      await updateCart(updatedCart);
      return updatedCart;
    } catch (e) {
      debugPrint('Error syncing cart with products: $e');
      return getCart(userId);
    }
  }

  Future<void> removeSellerItems(String userId, String sellerId) async {
    try {
      await _mutateCart<void>(userId, (cart) {
        final updatedItems = cart.items
            .where((item) => item.sellerId != sellerId)
            .toList();
        return (cart.copyWith(items: updatedItems), null);
      });
      debugPrint('Removed items from seller: $sellerId');
    } catch (e) {
      debugPrint('Error removing seller items: $e');
      rethrow;
    }
  }

  Future<void> removeItems(String userId, List<String> productIds) async {
    try {
      await _mutateCart<void>(userId, (cart) {
        var updatedCart = cart;
        for (final productId in productIds) {
          updatedCart = updatedCart.removeItem(productId);
        }
        return (updatedCart, null);
      });
      debugPrint('Removed ${productIds.length} items from cart');
    } catch (e) {
      debugPrint('Error removing multiple items: $e');
      rethrow;
    }
  }

  Stream<int> getCartItemCountStream(String userId) {
    return getCartStream(userId).map((cart) => cart.totalItems);
  }

  Stream<double> getCartTotalStream(String userId) {
    return getCartStream(userId).map((cart) => cart.totalAmount);
  }
}
