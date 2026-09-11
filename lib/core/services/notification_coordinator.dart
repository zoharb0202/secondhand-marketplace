import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

class NotificationCoordinator {
  NotificationCoordinator._();
  static final NotificationCoordinator instance = NotificationCoordinator._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  String? _currentUid;
  bool _initialized = false;
  bool _localReady = false;

  static const Map<String, String> _typeToChannel = {
    'new_order': 'orders',
    'order_update': 'orders',
    'pickup_reminder': 'orders',
    'new_message': 'messages',
    'price_offer': 'orders',
    'review': 'orders',
    'promo': 'marketing',
    'alert_match': 'alerts',
    'saved_search_match': 'alerts',
    'followed_seller_new_product': 'alerts',
    'price_drop': 'alerts',
  };

  static const AndroidNotificationChannel _ordersChannel =
      AndroidNotificationChannel(
        'orders',
        'הזמנות',
        description: 'עדכונים על הזמנות ותשלומים',
        importance: Importance.high,
        playSound: true,
      );
  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
        'messages',
        'הודעות',
        description: 'הודעות צ׳אט חדשות',
        importance: Importance.high,
        playSound: true,
      );
  static const AndroidNotificationChannel _marketingChannel =
      AndroidNotificationChannel(
        'marketing',
        'מבצעים ועדכונים',
        description: 'מבצעים, קופונים ועדכונים שיווקיים',
        importance: Importance.low,
        playSound: false,
      );
  static const AndroidNotificationChannel _alertsChannel =
      AndroidNotificationChannel(
        'alerts',
        'התראות ומוצרים חדשים',
        description: 'התראות חכמות, חיפושים שמורים ומוכרים שאתה עוקב אחריהם',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  static const List<AndroidNotificationChannel> _channels = [
    _ordersChannel,
    _messagesChannel,
    _marketingChannel,
    _alertsChannel,
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      await _ensureLocalNotificationsReady();
      await _requestAndroidNotificationsPermission();

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      _onMessageSub = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => handleNotificationTap(m.data),
      );
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        Future.delayed(
          const Duration(milliseconds: 500),
          () => handleNotificationTap(initial.data),
        );
      }

      _authSub = FirebaseAuth.instance.authStateChanges().listen(
        _handleAuthChange,
      );
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
        if (_currentUid != null) _saveToken(_currentUid!, token);
      });

      if (kDebugMode) print('✅ NotificationCoordinator initialized');
    } catch (e) {
      if (kDebugMode) print('❌ NotificationCoordinator init error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
          handleNotificationTap(data);
        } catch (_) {}
      },
    );
  }

  Future<void> _ensureLocalNotificationsReady() async {
    if (_localReady) return;
    await _initLocalNotifications();
    await _createChannels();
    _localReady = true;
  }

  Future<void> _createChannels() async {
    final androidImpl = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl == null) return;
    for (final channel in _channels) {
      await androidImpl.createNotificationChannel(channel);
    }
  }

  Future<void> _requestAndroidNotificationsPermission() async {
    final androidImpl = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
  }

  Future<void> _handleAuthChange(User? user) async {
    final previousUid = _currentUid;
    if (user == null) {
      if (previousUid != null) {
        await _deleteToken(previousUid);
      }
      _currentUid = null;
      return;
    }

    _currentUid = user.uid;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(user.uid, token);
    } catch (e) {
      if (kDebugMode) print('⚠️ Could not fetch/save FCM token: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _deviceDoc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('device');

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _deviceDoc(uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) print('📱 Saved FCM token for $uid');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save FCM token: $e');
    }
  }

  Future<void> prepareForSignOut() async {
    final uid = _currentUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _deleteToken(uid);
    }
    try {
      await _messaging.deleteToken();
    } catch (e) {
      if (kDebugMode) print('⚠️ Could not invalidate FCM token: $e');
    }
    _currentUid = null;
  }

  Future<void> _deleteToken(String uid) async {
    try {
      await _deviceDoc(
        uid,
      ).set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to delete FCM token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = (data['type'] as String?) ?? 'order_update';

    final notification = message.notification;
    final channelId = _typeToChannel[type] ?? 'orders';

    final title = notification?.title ?? data['title'] ?? '';
    final body = notification?.body ?? data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final channel = _channelById(channelId);
    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: channel.importance == Importance.max
          ? Priority.max
          : Priority.high,
      icon: '@drawable/ic_notification',
      tag: data['tag'] ?? data['orderId'] ?? type,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _local.show(
      message.hashCode,
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }

  AndroidNotificationChannel _channelById(String id) {
    return _channels.firstWhere(
      (c) => c.id == id,
      orElse: () => _ordersChannel,
    );
  }

  void handleNotificationTap(Map<String, dynamic> data) {
    final route = routeForData(data);
    if (route == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      if (kDebugMode) {
        print('⚠️ No navigator context for notification route $route');
      }
      return;
    }
    if (kDebugMode) print('➡️ Notification tap → $route');
    context.go(route);
  }

  @visibleForTesting
  String? routeForData(Map<String, dynamic> data) {
    final type = (data['type'] as String?) ?? '';
    final orderId = data['orderId'] as String?;
    final chatId = (data['chatId'] ?? data['conversationId']) as String?;
    final productId = data['productId'] as String?;

    switch (type) {
      case 'new_order':
      case 'order_update':
      case 'pickup_reminder':
        return orderId != null ? '/order/$orderId' : '/notifications';
      case 'new_message':
        return chatId != null ? '/chat/$chatId' : '/notifications';
      case 'price_offer':
        return productId != null ? '/product/$productId' : '/notifications';
      case 'alert_match':
      case 'saved_search_match':
      case 'followed_seller_new_product':
      case 'price_drop':
        return productId != null ? '/product/$productId' : '/notifications';
      case 'review':
      case 'promo':
        return '/notifications';
      default:
        return '/notifications';
    }
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
  }
}
