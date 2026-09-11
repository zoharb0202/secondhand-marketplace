import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/products/presentation/pages/product_detail_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/orders/presentation/pages/order_tracking_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/notification_settings_page.dart';
import '../widgets/home_gate.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

class RouterNotifier extends ChangeNotifier {
  StreamSubscription<User?>? _authSubscription;

  RouterNotifier() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  final notifier = RouterNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final isGoingToAuth = state.matchedLocation.startsWith('/login');

      if (!isLoggedIn && !isGoingToAuth) {
        return '/login';
      }

      if (isLoggedIn && isGoingToAuth) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

      GoRoute(path: '/', builder: (context, state) => const HomeGate()),

      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailPage(productId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            ChatPage(chatId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/order/:id',
        builder: (context, state) =>
            OrderTrackingPage(orderId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),

      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
    ],
  );
});
