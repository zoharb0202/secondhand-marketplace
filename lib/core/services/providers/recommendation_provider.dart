import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../recommendation_service.dart';
import '../../../shared/models/user_activity_model.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';

final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return RecommendationService();
});

final userRecommendationsProvider = FutureProvider<List<ProductRecommendation>>(
  (ref) async {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return [];
    }

    final service = ref.watch(recommendationServiceProvider);
    return await service.getRecommendations(user.id);
  },
);

final userActivityProvider = FutureProvider<UserActivity?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) {
    return null;
  }

  final service = ref.watch(recommendationServiceProvider);
  return await service.getUserActivity(user.id);
});

class RecommendationController extends StateNotifier<AsyncValue<void>> {
  final RecommendationService _service;
  final String? _userId;

  RecommendationController(this._service, this._userId)
    : super(const AsyncValue.data(null));

  Future<void> trackView(String productId, String category) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _service.trackProductModelView(userId, productId, category);
    } catch (_) {}
  }

  Future<void> trackPurchase(
    String productId,
    String category,
    String sellerId,
  ) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _service.trackPurchase(userId, productId, category, sellerId);
    } catch (_) {}
  }

  Future<void> trackSearch(String query) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _service.trackSearch(userId, query);
    } catch (_) {}
  }
}

final recommendationControllerProvider =
    StateNotifierProvider<RecommendationController, AsyncValue<void>>((ref) {
      final service = ref.watch(recommendationServiceProvider);
      final userId = ref.watch(currentUserProvider).value?.id;
      return RecommendationController(service, userId);
    });
