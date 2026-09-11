import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/notification_types.dart';

export '../constants/notification_types.dart';

const int kUnreadNotificationsBadgeCap = 9;

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: notificationTypeFromWire(data['type']),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: data['data'],
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.wire,
      'title': title,
      'body': body,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class NotificationService {
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

      await _queuePush(
        userId: userId,
        type: type,
        title: title,
        body: body,
        data: data,
      );

      debugPrint('Notification sent to $userId: $title');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> _queuePush({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('fcm_queue').add({
        'userId': userId,
        'notification': {'title': title, 'body': body},
        'data': {'type': type.wire, ...?data},
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });
    } catch (e) {
      debugPrint('Error queuing push: $e');
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
        .limit(kUnreadNotificationsBadgeCap + 1)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Error marking notification $notificationId as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    const int maxWritesPerBatch = 500;

    final notifications = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final docs = notifications.docs;
    for (var start = 0; start < docs.length; start += maxWritesPerBatch) {
      final end = start + maxWritesPerBatch < docs.length
          ? start + maxWritesPerBatch
          : docs.length;
      final batch = _firestore.batch();
      for (final doc in docs.sublist(start, end)) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
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
    String actualBuyerName = buyerName;
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final buyerId = orderDoc.data()?['buyerId'];
        if (buyerId != null) {
          final userDoc = await _firestore
              .collection('users')
              .doc(buyerId)
              .get();
          if (userDoc.exists) {
            actualBuyerName = userDoc.data()?['displayName'] ?? buyerName;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching buyer name: $e');
    }

    await sendNotification(
      userId: sellerId,
      type: NotificationType.newOrder,
      title: 'הזמנה חדשה!',
      body: '$actualBuyerName הזמין את $productTitle',
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
      title: 'הודעה חדשה מ-$senderName',
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
      title: 'הצעת מחיר חדשה!',
      body: '$buyerName הציע ₪$offeredPrice',
      data: {'productId': productId, 'offeredPrice': offeredPrice},
    );
  }
}
