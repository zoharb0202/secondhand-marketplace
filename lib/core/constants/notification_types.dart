import 'package:flutter/material.dart';

enum NotificationType {
  newOrder,
  orderStatusUpdate,
  pickupReminder,
  newMessage,
  priceOffer,
  review,
  priceDrop,
  alertMatch,
  savedSearchMatch,
  followedSellerNewProduct,
  systemAlert,
}

const Map<NotificationType, String> kNotificationTypeWire = {
  NotificationType.newOrder: 'new_order',
  NotificationType.orderStatusUpdate: 'order_update',
  NotificationType.pickupReminder: 'pickup_reminder',
  NotificationType.newMessage: 'new_message',
  NotificationType.priceOffer: 'price_offer',
  NotificationType.review: 'review',
  NotificationType.priceDrop: 'price_drop',
  NotificationType.alertMatch: 'alert_match',
  NotificationType.savedSearchMatch: 'saved_search_match',
  NotificationType.followedSellerNewProduct: 'followed_seller_new_product',
  NotificationType.systemAlert: 'promo',
};

final Map<String, NotificationType> _byWire = {
  for (final entry in kNotificationTypeWire.entries) entry.value: entry.key,
};

const Map<String, NotificationType> kLegacyNotificationTypeAliases = {
  'newOrder': NotificationType.newOrder,
  'orderStatusUpdate': NotificationType.orderStatusUpdate,
  'newMessage': NotificationType.newMessage,
  'priceOffer': NotificationType.priceOffer,
  'systemAlert': NotificationType.systemAlert,
  'reviewReceived': NotificationType.review,
};

NotificationType notificationTypeFromWire(dynamic raw) {
  if (raw is! String || raw.isEmpty) return NotificationType.systemAlert;
  final canonical = _byWire[raw];
  if (canonical != null) return canonical;
  final legacy = kLegacyNotificationTypeAliases[raw];
  if (legacy != null) return legacy;
  return NotificationType.systemAlert;
}

extension NotificationTypeX on NotificationType {
  String get wire => kNotificationTypeWire[this]!;

  IconData get icon {
    switch (this) {
      case NotificationType.newOrder:
        return Icons.shopping_bag;
      case NotificationType.orderStatusUpdate:
        return Icons.update;
      case NotificationType.pickupReminder:
        return Icons.alarm;
      case NotificationType.newMessage:
        return Icons.chat;
      case NotificationType.priceOffer:
        return Icons.local_offer;
      case NotificationType.review:
        return Icons.star;
      case NotificationType.priceDrop:
        return Icons.trending_down;
      case NotificationType.alertMatch:
        return Icons.notifications_active;
      case NotificationType.savedSearchMatch:
        return Icons.saved_search;
      case NotificationType.followedSellerNewProduct:
        return Icons.storefront;
      case NotificationType.systemAlert:
        return Icons.info;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.newOrder:
        return Colors.green;
      case NotificationType.orderStatusUpdate:
        return Colors.blue;
      case NotificationType.pickupReminder:
        return Colors.orange;
      case NotificationType.newMessage:
        return Colors.blue;
      case NotificationType.priceOffer:
        return Colors.amber;
      case NotificationType.review:
        return Colors.yellow[700]!;
      case NotificationType.priceDrop:
        return Colors.green;
      case NotificationType.alertMatch:
        return Colors.deepPurple;
      case NotificationType.savedSearchMatch:
        return Colors.deepPurple;
      case NotificationType.followedSellerNewProduct:
        return Colors.deepPurple;
      case NotificationType.systemAlert:
        return Colors.grey;
    }
  }
}
