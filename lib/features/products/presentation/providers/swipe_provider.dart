import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/recommendation_service.dart';
import '../../../../shared/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'product_provider.dart';

class SwipeState {
  final List<ProductModel> products;
  final int currentIndex;
  final bool isLoading;
  final String? error;

  SwipeState({
    required this.products,
    this.currentIndex = 0,
    this.isLoading = false,
    this.error,
  });

  SwipeState copyWith({
    List<ProductModel>? products,
    int? currentIndex,
    bool? isLoading,
    String? error,
  }) {
    return SwipeState(
      products: products ?? this.products,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  ProductModel? get currentProduct {
    if (currentIndex >= 0 && currentIndex < products.length) {
      return products[currentIndex];
    }
    return null;
  }

  bool get hasMore => currentIndex < products.length;
}

class SwipeController extends StateNotifier<SwipeState> {
  final Ref ref;
  final RecommendationService _recommendationService = RecommendationService();

  SwipeController(this.ref) : super(SwipeState(products: []));

  Future<void> loadProducts(List<ProductModel> products) async {
    state = state.copyWith(isLoading: true);

    try {
      final user = ref.read(currentUserProvider).value;

      if (user != null) {
        final sorted = await _recommendationService.sortByRelevance(
          userId: user.id,
          products: products,
        );

        state = state.copyWith(
          products: sorted,
          currentIndex: 0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          products: products,
          currentIndex: 0,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> swipeRight() async {
    final product = state.currentProduct;
    if (product == null) return;

    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      await _recommendationService.recordInteraction(
        userId: user.id,
        productId: product.id,
        type: 'like',
        category: product.category.name,
        sellerId: product.sellerId,
      );

      await _recommendationService.recordInteraction(
        userId: user.id,
        productId: product.id,
        type: 'favorite',
        category: product.category.name,
        sellerId: product.sellerId,
      );

      try {
        if (!product.likedByUserIds.contains(user.id)) {
          await ref
              .read(productRepositoryProvider)
              .toggleLike(product.id, user.id);
        }
      } catch (_) {}
    }

    _moveToNext();
  }

  Future<void> swipeLeft() async {
    final product = state.currentProduct;
    if (product == null) return;

    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      await _recommendationService.recordInteraction(
        userId: user.id,
        productId: product.id,
        type: 'dislike',
        category: product.category.name,
        sellerId: product.sellerId,
      );
    }

    _moveToNext();
  }

  void _moveToNext() {
    if (state.currentIndex < state.products.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    } else {
      state = state.copyWith(currentIndex: state.products.length);
    }
  }

  void reset() {
    state = state.copyWith(currentIndex: 0);
  }
}

final swipeControllerProvider =
    StateNotifierProvider<SwipeController, SwipeState>((ref) {
      return SwipeController(ref);
    });
