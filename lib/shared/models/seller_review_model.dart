import 'package:cloud_firestore/cloud_firestore.dart';

class SellerReviewModel {
  final String id;
  final String sellerId;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerPhotoUrl;

  final double rating;

  final double? communicationRating;
  final double? accuracyRating;
  final double? speedRating;
  final double? serviceRating;

  final String? comment;
  final List<String>? photoUrls;

  final String? orderId;
  final String? productId;
  final String? productTitle;

  final DateTime createdAt;
  final DateTime? updatedAt;

  final bool verifiedPurchase;

  final DateTime? editableUntil;

  final bool isVisible;
  final bool isFlagged;
  final String? flagReason;

  final String? sellerResponse;
  final DateTime? sellerResponseDate;

  final int helpfulCount;
  final List<String> markedHelpfulBy;

  SellerReviewModel({
    required this.id,
    required this.sellerId,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerPhotoUrl,
    required this.rating,
    this.communicationRating,
    this.accuracyRating,
    this.speedRating,
    this.serviceRating,
    this.comment,
    this.photoUrls,
    this.orderId,
    this.productId,
    this.productTitle,
    required this.createdAt,
    this.updatedAt,
    this.verifiedPurchase = false,
    this.editableUntil,
    this.isVisible = true,
    this.isFlagged = false,
    this.flagReason,
    this.sellerResponse,
    this.sellerResponseDate,
    this.helpfulCount = 0,
    this.markedHelpfulBy = const [],
  });

  factory SellerReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SellerReviewModel(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      reviewerName: data['reviewerName'] ?? 'משתמש',
      reviewerPhotoUrl: data['reviewerPhotoUrl'],
      rating: (data['rating'] ?? 0).toDouble(),
      communicationRating: data['communicationRating']?.toDouble(),
      accuracyRating: data['accuracyRating']?.toDouble(),
      speedRating: data['speedRating']?.toDouble(),
      serviceRating: data['serviceRating']?.toDouble(),
      comment: data['comment'],
      photoUrls: data['photoUrls'] != null
          ? List<String>.from(data['photoUrls'])
          : null,
      orderId: data['orderId'],
      productId: data['productId'],
      productTitle: data['productTitle'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      verifiedPurchase: data['verifiedPurchase'] ?? false,
      editableUntil: (data['editableUntil'] as Timestamp?)?.toDate(),
      isVisible: data['isVisible'] ?? true,
      isFlagged: data['isFlagged'] ?? false,
      flagReason: data['flagReason'],
      sellerResponse: data['sellerResponse'],
      sellerResponseDate: (data['sellerResponseDate'] as Timestamp?)?.toDate(),
      helpfulCount: data['helpfulCount'] ?? 0,
      markedHelpfulBy: data['markedHelpfulBy'] != null
          ? List<String>.from(data['markedHelpfulBy'])
          : [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sellerId': sellerId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerPhotoUrl': reviewerPhotoUrl,
      'rating': rating,
      'communicationRating': communicationRating,
      'accuracyRating': accuracyRating,
      'speedRating': speedRating,
      'serviceRating': serviceRating,
      'comment': comment,
      'photoUrls': photoUrls,
      'orderId': orderId,
      'productId': productId,
      'productTitle': productTitle,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'verifiedPurchase': verifiedPurchase,
      'editableUntil': editableUntil != null
          ? Timestamp.fromDate(editableUntil!)
          : null,
      'isVisible': isVisible,
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      'sellerResponse': sellerResponse,
      'sellerResponseDate': sellerResponseDate != null
          ? Timestamp.fromDate(sellerResponseDate!)
          : null,
      'helpfulCount': helpfulCount,
      'markedHelpfulBy': markedHelpfulBy,
    };
  }

  SellerReviewModel copyWith({
    String? id,
    String? sellerId,
    String? reviewerId,
    String? reviewerName,
    String? reviewerPhotoUrl,
    double? rating,
    double? communicationRating,
    double? accuracyRating,
    double? speedRating,
    double? serviceRating,
    String? comment,
    List<String>? photoUrls,
    String? orderId,
    String? productId,
    String? productTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? verifiedPurchase,
    DateTime? editableUntil,
    bool? isVisible,
    bool? isFlagged,
    String? flagReason,
    String? sellerResponse,
    DateTime? sellerResponseDate,
    int? helpfulCount,
    List<String>? markedHelpfulBy,
  }) {
    return SellerReviewModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerPhotoUrl: reviewerPhotoUrl ?? this.reviewerPhotoUrl,
      rating: rating ?? this.rating,
      communicationRating: communicationRating ?? this.communicationRating,
      accuracyRating: accuracyRating ?? this.accuracyRating,
      speedRating: speedRating ?? this.speedRating,
      serviceRating: serviceRating ?? this.serviceRating,
      comment: comment ?? this.comment,
      photoUrls: photoUrls ?? this.photoUrls,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verifiedPurchase: verifiedPurchase ?? this.verifiedPurchase,
      editableUntil: editableUntil ?? this.editableUntil,
      isVisible: isVisible ?? this.isVisible,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      sellerResponse: sellerResponse ?? this.sellerResponse,
      sellerResponseDate: sellerResponseDate ?? this.sellerResponseDate,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      markedHelpfulBy: markedHelpfulBy ?? this.markedHelpfulBy,
    );
  }

  double get averageDetailedRating {
    final ratings = [
      communicationRating,
      accuracyRating,
      speedRating,
      serviceRating,
    ].whereType<double>().toList();

    if (ratings.isEmpty) return rating;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  bool get hasDetailedRatings {
    return communicationRating != null ||
        accuracyRating != null ||
        speedRating != null ||
        serviceRating != null;
  }

  bool get hasPhotos => photoUrls != null && photoUrls!.isNotEmpty;

  bool get hasSellerResponse =>
      sellerResponse != null && sellerResponse!.trim().isNotEmpty;

  DateTime get editDeadline =>
      editableUntil ?? createdAt.add(const Duration(days: 14));

  bool isEditableBy(String? uid) =>
      uid != null && uid == reviewerId && DateTime.now().isBefore(editDeadline);

  int get daysLeftToEdit {
    final left = editDeadline.difference(DateTime.now()).inDays;
    return left > 0 ? left : 0;
  }
}

class SellerRatingSummary {
  final String sellerId;
  final double averageRating;
  final int totalReviews;

  final double? averageCommunication;
  final double? averageAccuracy;
  final double? averageSpeed;
  final double? averageService;

  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;

  final DateTime lastUpdated;

  SellerRatingSummary({
    required this.sellerId,
    required this.averageRating,
    required this.totalReviews,
    this.averageCommunication,
    this.averageAccuracy,
    this.averageSpeed,
    this.averageService,
    required this.fiveStarCount,
    required this.fourStarCount,
    required this.threeStarCount,
    required this.twoStarCount,
    required this.oneStarCount,
    required this.lastUpdated,
  });

  factory SellerRatingSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SellerRatingSummary(
      sellerId: doc.id,
      averageRating: (data['averageRating'] ?? 0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      averageCommunication: data['averageCommunication']?.toDouble(),
      averageAccuracy: data['averageAccuracy']?.toDouble(),
      averageSpeed: data['averageSpeed']?.toDouble(),
      averageService: data['averageService']?.toDouble(),
      fiveStarCount: data['fiveStarCount'] ?? 0,
      fourStarCount: data['fourStarCount'] ?? 0,
      threeStarCount: data['threeStarCount'] ?? 0,
      twoStarCount: data['twoStarCount'] ?? 0,
      oneStarCount: data['oneStarCount'] ?? 0,
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'averageCommunication': averageCommunication,
      'averageAccuracy': averageAccuracy,
      'averageSpeed': averageSpeed,
      'averageService': averageService,
      'fiveStarCount': fiveStarCount,
      'fourStarCount': fourStarCount,
      'threeStarCount': threeStarCount,
      'twoStarCount': twoStarCount,
      'oneStarCount': oneStarCount,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  double getStarPercentage(int stars) {
    if (totalReviews == 0) return 0;

    final count = switch (stars) {
      5 => fiveStarCount,
      4 => fourStarCount,
      3 => threeStarCount,
      2 => twoStarCount,
      1 => oneStarCount,
      _ => 0,
    };

    return (count / totalReviews) * 100;
  }

  bool get hasGoodRating => averageRating >= 4.0;

  bool get hasExcellentRating => averageRating >= 4.5;
}
