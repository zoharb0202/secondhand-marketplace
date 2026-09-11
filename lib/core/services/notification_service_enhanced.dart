import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/notification_types.dart';
import 'notification_service.dart' show AppNotification;

export '../constants/notification_types.dart';

class NotificationServiceEnhanced {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'notifications';

  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'userId': userId,
        'type': type.wire,
        'title': title,
        'body': body,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _queuePushNotification(
        userId: userId,
        title: title,
        body: body,
        data: {'type': type.wire, ...?data},
      );

      debugPrint('✅ Notification sent to $userId: $title');
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }

  Future<void> _queuePushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('fcm_queue').add({
        'notification': {'title': title, 'body': body},
        'data': data,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      debugPrint('📤 Push notification queued for user $userId');
    } catch (e) {
      debugPrint('❌ Error queuing push notification: $e');
    }
  }

  Stream<List<AppNotification>> getUserNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).delete();
  }

  Future<void> notifyNewOrder({
    required String sellerId,
    required String orderId,
    required String productTitle,
    required String buyerName,
  }) async {
    await sendNotification(
      userId: sellerId,
      type: NotificationType.newOrder,
      title: '🛒 הזמנה חדשה!',
      body: '$buyerName הזמין את $productTitle',
      data: {'orderId': orderId},
    );
  }

  Future<void> notifyNewMessage({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String chatId,
    required String preview,
  }) async {
    await sendNotification(
      userId: recipientId,
      type: NotificationType.newMessage,
      title: '💬 $senderName',
      body: preview.length > 50 ? '${preview.substring(0, 50)}...' : preview,
      data: {'chatId': chatId, 'senderId': senderId},
    );
  }

  Future<void> notifyPriceOffer({
    required String sellerId,
    required String productId,
    required String buyerName,
    required double offeredPrice,
  }) async {
    await sendNotification(
      userId: sellerId,
      type: NotificationType.priceOffer,
      title: '💰 הצעת מחיר חדשה!',
      body: '$buyerName הציע ₪${offeredPrice.toStringAsFixed(0)}',
      data: {'productId': productId, 'offeredPrice': offeredPrice},
    );
  }
}
