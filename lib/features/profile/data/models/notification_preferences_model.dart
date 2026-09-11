import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferencesModel {
  final String userId;

  final bool enableNotifications;
  final bool enableSounds;
  final bool enableVibration;

  final int? quietHoursStart;
  final int? quietHoursEnd;

  final bool notifyNewMessages;
  final bool notifyPriceReductions;
  final bool notifyPriceAlerts;
  final bool notifyBackInStock;
  final bool notifySimilarProducts;
  final bool notifyNewProducts;

  final bool notifyOrderStatus;
  final bool notifyPaymentStatus;

  final bool notifyChatMessages;
  final bool notifyOfferReceived;
  final bool notifyOfferAccepted;

  final bool notifyNewReviews;
  final bool notifyReviewResponses;

  final bool notifyPromotions;
  final bool notifySystemUpdates;
  final bool notifyRecommendations;

  final List<String> mutedCategories;

  final DateTime lastUpdated;

  NotificationPreferencesModel({
    required this.userId,
    this.enableNotifications = true,
    this.enableSounds = true,
    this.enableVibration = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.notifyNewMessages = true,
    this.notifyPriceReductions = true,
    this.notifyPriceAlerts = true,
    this.notifyBackInStock = true,
    this.notifySimilarProducts = true,
    this.notifyNewProducts = true,
    this.notifyOrderStatus = true,
    this.notifyPaymentStatus = true,
    this.notifyChatMessages = true,
    this.notifyOfferReceived = true,
    this.notifyOfferAccepted = true,
    this.notifyNewReviews = true,
    this.notifyReviewResponses = true,
    this.notifyPromotions = false,
    this.notifySystemUpdates = true,
    this.notifyRecommendations = true,
    this.mutedCategories = const [],
    required this.lastUpdated,
  });

  bool shouldNotifyNow() {
    if (!enableNotifications) return false;

    if (quietHoursStart != null && quietHoursEnd != null) {
      final now = DateTime.now();
      final currentHour = now.hour;

      if (quietHoursStart! > quietHoursEnd!) {
        if (currentHour >= quietHoursStart! || currentHour < quietHoursEnd!) {
          return false;
        }
      } else {
        if (currentHour >= quietHoursStart! && currentHour < quietHoursEnd!) {
          return false;
        }
      }
    }

    return true;
  }

  bool isCategoryMuted(String categoryId) {
    return mutedCategories.contains(categoryId);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'enableNotifications': enableNotifications,
      'enableSounds': enableSounds,
      'enableVibration': enableVibration,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'notifyNewMessages': notifyNewMessages,
      'notifyPriceReductions': notifyPriceReductions,
      'notifyPriceAlerts': notifyPriceAlerts,
      'notifyBackInStock': notifyBackInStock,
      'notifySimilarProducts': notifySimilarProducts,
      'notifyNewProducts': notifyNewProducts,
      'notifyOrderStatus': notifyOrderStatus,
      'notifyPaymentStatus': notifyPaymentStatus,
      'notifyChatMessages': notifyChatMessages,
      'notifyOfferReceived': notifyOfferReceived,
      'notifyOfferAccepted': notifyOfferAccepted,
      'notifyNewReviews': notifyNewReviews,
      'notifyReviewResponses': notifyReviewResponses,
      'notifyPromotions': notifyPromotions,
      'notifySystemUpdates': notifySystemUpdates,
      'notifyRecommendations': notifyRecommendations,
      'mutedCategories': mutedCategories,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory NotificationPreferencesModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return NotificationPreferencesModel(
      userId: data['userId'] ?? '',
      enableNotifications: data['enableNotifications'] ?? true,
      enableSounds: data['enableSounds'] ?? true,
      enableVibration: data['enableVibration'] ?? true,
      quietHoursStart: data['quietHoursStart'],
      quietHoursEnd: data['quietHoursEnd'],
      notifyNewMessages: data['notifyNewMessages'] ?? true,
      notifyPriceReductions: data['notifyPriceReductions'] ?? true,
      notifyPriceAlerts: data['notifyPriceAlerts'] ?? true,
      notifyBackInStock: data['notifyBackInStock'] ?? true,
      notifySimilarProducts: data['notifySimilarProducts'] ?? true,
      notifyNewProducts: data['notifyNewProducts'] ?? true,
      notifyOrderStatus: data['notifyOrderStatus'] ?? true,
      notifyPaymentStatus: data['notifyPaymentStatus'] ?? true,
      notifyChatMessages: data['notifyChatMessages'] ?? true,
      notifyOfferReceived: data['notifyOfferReceived'] ?? true,
      notifyOfferAccepted: data['notifyOfferAccepted'] ?? true,
      notifyNewReviews: data['notifyNewReviews'] ?? true,
      notifyReviewResponses: data['notifyReviewResponses'] ?? true,
      notifyPromotions: data['notifyPromotions'] ?? false,
      notifySystemUpdates: data['notifySystemUpdates'] ?? true,
      notifyRecommendations: data['notifyRecommendations'] ?? true,
      mutedCategories: List<String>.from(data['mutedCategories'] ?? []),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  NotificationPreferencesModel copyWith({
    bool? enableNotifications,
    bool? enableSounds,
    bool? enableVibration,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? notifyNewMessages,
    bool? notifyPriceReductions,
    bool? notifyPriceAlerts,
    bool? notifyBackInStock,
    bool? notifySimilarProducts,
    bool? notifyNewProducts,
    bool? notifyOrderStatus,
    bool? notifyPaymentStatus,
    bool? notifyChatMessages,
    bool? notifyOfferReceived,
    bool? notifyOfferAccepted,
    bool? notifyNewReviews,
    bool? notifyReviewResponses,
    bool? notifyPromotions,
    bool? notifySystemUpdates,
    bool? notifyRecommendations,
    List<String>? mutedCategories,
  }) {
    return NotificationPreferencesModel(
      userId: userId,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableSounds: enableSounds ?? this.enableSounds,
      enableVibration: enableVibration ?? this.enableVibration,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      notifyNewMessages: notifyNewMessages ?? this.notifyNewMessages,
      notifyPriceReductions:
          notifyPriceReductions ?? this.notifyPriceReductions,
      notifyPriceAlerts: notifyPriceAlerts ?? this.notifyPriceAlerts,
      notifyBackInStock: notifyBackInStock ?? this.notifyBackInStock,
      notifySimilarProducts:
          notifySimilarProducts ?? this.notifySimilarProducts,
      notifyNewProducts: notifyNewProducts ?? this.notifyNewProducts,
      notifyOrderStatus: notifyOrderStatus ?? this.notifyOrderStatus,
      notifyPaymentStatus: notifyPaymentStatus ?? this.notifyPaymentStatus,
      notifyChatMessages: notifyChatMessages ?? this.notifyChatMessages,
      notifyOfferReceived: notifyOfferReceived ?? this.notifyOfferReceived,
      notifyOfferAccepted: notifyOfferAccepted ?? this.notifyOfferAccepted,
      notifyNewReviews: notifyNewReviews ?? this.notifyNewReviews,
      notifyReviewResponses:
          notifyReviewResponses ?? this.notifyReviewResponses,
      notifyPromotions: notifyPromotions ?? this.notifyPromotions,
      notifySystemUpdates: notifySystemUpdates ?? this.notifySystemUpdates,
      notifyRecommendations:
          notifyRecommendations ?? this.notifyRecommendations,
      mutedCategories: mutedCategories ?? this.mutedCategories,
      lastUpdated: DateTime.now(),
    );
  }
}
