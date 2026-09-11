import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'in_app_banner.dart';

class NotificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationListener({super.key, required this.child});

  @override
  ConsumerState<NotificationListener> createState() =>
      _NotificationListenerState();
}

class _NotificationListenerState extends ConsumerState<NotificationListener> {
  final Set<String> _shownNotifications = {};

  final DateTime _appStartTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return widget.child;

        final notificationService = NotificationService();

        return StreamBuilder<List<AppNotification>>(
          stream: notificationService.getUserNotifications(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final notifications = snapshot.data!;

              for (final notification in notifications) {
                if (notification.isRead) continue;
                if (_shownNotifications.contains(notification.id)) continue;
                if (notification.createdAt.isBefore(_appStartTime)) {
                  _shownNotifications.add(notification.id);
                  continue;
                }

                _shownNotifications.add(notification.id);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _surfaceNotification(context, notification);
                  }
                });
              }
            }

            return widget.child;
          },
        );
      },
      loading: () => widget.child,
      error: (_, __) => widget.child,
    );
  }

  void _surfaceNotification(
    BuildContext context,
    AppNotification notification,
  ) {
    InAppBanner.show(context, notification);
  }
}
