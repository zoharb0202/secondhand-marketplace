import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/order_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/services/providers/recommendation_provider.dart';
import '../../../../core/services/interaction_tracker.dart';
import '../../../../shared/models/product_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

final buyerOrdersProvider = StreamProvider.family<List<OrderModel>, String>((
  ref,
  userId,
) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getBuyerOrders(userId);
});

final sellerOrdersProvider = StreamProvider.family<List<OrderModel>, String>((
  ref,
  userId,
) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getSellerOrders(userId);
});

final orderProvider = StreamProvider.family<OrderModel?, String>((
  ref,
  orderId,
) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getOrder(orderId);
});

class OrderController extends StateNotifier<AsyncValue<void>> {
  final OrderRepository _repository;
  final Ref _ref;

  OrderController(this._repository, this._ref)
    : super(const AsyncValue.data(null));

  Future<OrderModel?> createOrder({
    required String productId,
    required String sellerId,
    required String buyerId,
    required String productTitle,
    required String productImageUrl,
    required double productPrice,
    String? pickupAddress,
    GeoPoint? pickupLocation,
    String? pickupPhone,
    String? buyerNotes,
    String? paymentId,
    String? paymentMethod,
    String? offerId,
    List<OrderLineItem> additionalItems = const [],
    Map<String, int> quantities = const {},
  }) async {
    state = const AsyncValue.loading();
    try {
      final order = await _repository.createOrder(
        productId: productId,
        sellerId: sellerId,
        buyerId: buyerId,
        productTitle: productTitle,
        productImageUrl: productImageUrl,
        productPrice: productPrice,
        pickupAddress: pickupAddress,
        pickupLocation: pickupLocation,
        pickupPhone: pickupPhone,
        buyerNotes: buyerNotes,
        paymentId: paymentId,
        paymentMethod: paymentMethod,
        offerId: offerId,
        additionalItems: additionalItems,
        quantities: quantities,
      );

      _trackPurchase(productId, sellerId, buyerId);
      for (final item in additionalItems) {
        _trackPurchase(item.productId, sellerId, buyerId);
      }

      state = const AsyncValue.data(null);
      return order;
    } catch (e, stack) {
      debugPrint('Error creating order: $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> _trackPurchase(
    String productId,
    String sellerId,
    String buyerId,
  ) async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (productDoc.exists) {
        final product = ProductModel.fromFirestore(productDoc);
        _ref
            .read(recommendationControllerProvider.notifier)
            .trackPurchase(productId, product.category.name, sellerId);
        InteractionTracker().track(
          InteractionType.purchase,
          product: product,
          sellerId: sellerId,
        );
      }
    } catch (e) {
      debugPrint('Failed to track purchase for recommendations: $e');
    }
  }

  Future<void> updateStatus(
    String orderId,
    OrderStatus status, {
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateOrderStatus(orderId, status, note: note);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.cancelOrder(orderId, reason: reason);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> markReadyForPickup(String orderId) =>
      _run(() => _repository.markReadyForPickup(orderId));

  Future<void> confirmPickup(String orderId) =>
      _run(() => _repository.confirmPickup(orderId));

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final orderControllerProvider =
    StateNotifierProvider<OrderController, AsyncValue<void>>((ref) {
      return OrderController(ref.watch(orderRepositoryProvider), ref);
    });
