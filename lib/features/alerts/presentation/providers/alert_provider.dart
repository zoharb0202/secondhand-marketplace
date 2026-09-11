import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/alert_model.dart';
import '../../data/services/alert_service.dart';

final alertServiceProvider = Provider<AlertService>((ref) {
  return AlertService();
});

final userAlertsProvider = StreamProvider<List<AlertModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;

  if (user == null) {
    return Stream.value([]);
  }

  final service = ref.watch(alertServiceProvider);
  return service.getUserAlertsStream(user.id);
});

final activeAlertsProvider = Provider<List<AlertModel>>((ref) {
  final alerts = ref.watch(userAlertsProvider).value ?? [];
  return alerts.where((alert) => alert.isActive).toList();
});

final inactiveAlertsProvider = Provider<List<AlertModel>>((ref) {
  final alerts = ref.watch(userAlertsProvider).value ?? [];
  return alerts.where((alert) => !alert.isActive).toList();
});

final activeAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(activeAlertsProvider).length;
});

final unreadMatchesProvider = StreamProvider<List<AlertMatch>>((ref) {
  final user = ref.watch(currentUserProvider).value;

  if (user == null) {
    return Stream.value([]);
  }

  final service = ref.watch(alertServiceProvider);
  return service.getUnreadMatchesStream(user.id);
});

final unreadMatchesCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider).value;

  if (user == null) {
    return Stream.value(0);
  }

  final service = ref.watch(alertServiceProvider);
  return service.getUnreadMatchesCountStream(user.id);
});

final alertMatchesProvider =
    StreamProvider.family<List<AlertMatch>, ({String alertId, String userId})>((
      ref,
      params,
    ) {
      final service = ref.watch(alertServiceProvider);
      return service.getAlertMatchesStream(
        alertId: params.alertId,
        userId: params.userId,
      );
    });

final highScoreMatchesProvider =
    StreamProvider.family<List<AlertMatch>, ({String alertId, String userId})>((
      ref,
      params,
    ) {
      final service = ref.watch(alertServiceProvider);
      return service.getAlertMatchesStream(
        alertId: params.alertId,
        userId: params.userId,
        minScore: 70,
      );
    });
