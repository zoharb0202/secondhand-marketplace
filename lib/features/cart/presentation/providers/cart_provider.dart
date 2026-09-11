import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/cart_model.dart';
import '../../data/repositories/cart_repository.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository();
});

final cartProvider = StreamProvider.family<ShoppingCart, String>((ref, userId) {
  final repository = ref.watch(cartRepositoryProvider);
  return repository.getCartStream(userId);
});

final cartItemCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final repository = ref.watch(cartRepositoryProvider);
  return repository.getCartItemCountStream(userId);
});

final cartTotalProvider = StreamProvider.family<double, String>((ref, userId) {
  final repository = ref.watch(cartRepositoryProvider);
  return repository.getCartTotalStream(userId);
});

final cartControllerProvider =
    StateNotifierProvider<CartController, AsyncValue<void>>((ref) {
      final repository = ref.watch(cartRepositoryProvider);
      return CartController(repository);
    });

class CartController extends StateNotifier<AsyncValue<void>> {
  final CartRepository _repository;

  CartController(this._repository) : super(const AsyncValue.data(null));

  Future<AddToCartResult> addItem(String userId, CartItem item) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.addItem(userId, item);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> removeItem(String userId, String productId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.removeItem(userId, productId);
    });
  }

  Future<void> updateItemQuantity(
    String userId,
    String productId,
    int quantity,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateItemQuantity(userId, productId, quantity);
    });
  }

  Future<void> clearCart(String userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.clearCart(userId);
    });
  }

  Future<ShoppingCart> syncCartWithProducts(String userId) async {
    return await _repository.syncCartWithProducts(userId);
  }

  Future<void> removeSellerItems(String userId, String sellerId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.removeSellerItems(userId, sellerId);
    });
  }

  Future<void> removeItems(String userId, List<String> productIds) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.removeItems(userId, productIds);
    });
  }
}
