import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/image_picker_web.dart';
import '../../../../shared/models/seller_review_model.dart';
import '../../../search/data/services/ai_search_service.dart';

class SellerReviewService {
  SellerReviewService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  static const String collection = 'seller_reviews';

  static const int maxPhotos = 5;
  static const int maxCommentChars = 1500;
  static const int maxReplyChars = 1000;

  static const int editWindowDays = 14;

  static String reviewDocId(String orderId, String buyerId) =>
      '${orderId}_$buyerId';

  static String legacyReviewDocId(String sellerId, String buyerId) =>
      '${sellerId}_$buyerId';

  static String photoFolder(String orderId, String buyerId) =>
      'review_photos/${reviewDocId(orderId, buyerId)}/$buyerId';

  Future<SubmitReviewResult> submitReview({
    required String orderId,
    required int rating,
    String? comment,
    List<String> photoUrls = const [],
  }) async {
    final result = await _functions.httpsCallable('submitSellerReview').call({
      'orderId': orderId,
      'rating': rating,
      'comment': comment ?? '',
      'photoUrls': photoUrls,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return SubmitReviewResult(
      reviewId: data['reviewId'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      created: (data['status'] as String? ?? '') == 'created',
      pendingModeration: data['pendingModeration'] as bool? ?? false,
    );
  }

  Future<void> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    await _functions.httpsCallable('replyToSellerReview').call({
      'reviewId': reviewId,
      'reply': reply,
    });
  }

  Future<void> markHelpful(String reviewId) async {
    await _functions.httpsCallable('markSellerReviewHelpful').call({
      'reviewId': reviewId,
    });
  }

  Future<void> flagReview({
    required String reviewId,
    required String reason,
  }) async {
    await _functions.httpsCallable('flagSellerReview').call({
      'reviewId': reviewId,
      'reason': reason,
    });
  }

  Future<UploadedReviewPhoto?> uploadPhoto({
    required String orderId,
    required String buyerId,
    required SelectedImage image,
    required int index,
  }) async {
    final moderation = await _moderate(image);
    if (!moderation.isAppropriate) {
      return UploadedReviewPhoto.rejected(
        moderation.reason ?? 'התמונה מכילה תוכן לא הולם',
      );
    }

    final extension = image.name.contains('.')
        ? image.name.split('.').last
        : 'jpg';
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$index.$extension';
    final url = await ImagePickerWeb.uploadImageToStorage(
      imageBytes: image.bytes,
      fileName: fileName,
      path: photoFolder(orderId, buyerId),
      mimeType: image.mimeType,
    );
    return UploadedReviewPhoto.uploaded(url);
  }

  Future<ModerationResult> _moderate(SelectedImage image) async {
    try {
      final codec = await ui.instantiateImageCodec(
        image.bytes,
        targetWidth: 900,
      );
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      final dataUri =
          'data:image/png;base64,${base64Encode(png!.buffer.asUint8List())}';
      return await AISearchService().moderateImage(dataUri);
    } catch (e) {
      if (kDebugMode) print('⚠️ [REVIEW] photo moderation skipped: $e');
      return ModerationResult(isAppropriate: true);
    }
  }

  Stream<SellerReviewModel?> watchMyReview({
    required String orderId,
    required String sellerId,
    required String buyerId,
  }) {
    return _firestore
        .collection(collection)
        .doc(reviewDocId(orderId, buyerId))
        .snapshots()
        .asyncMap((doc) async {
          if (doc.exists) return SellerReviewModel.fromFirestore(doc);
          final legacy = await _firestore
              .collection(collection)
              .doc(legacyReviewDocId(sellerId, buyerId))
              .get();
          if (!legacy.exists) return null;
          final model = SellerReviewModel.fromFirestore(legacy);
          return model.orderId == orderId ? model : null;
        });
  }
}

class SubmitReviewResult {
  final String reviewId;
  final String sellerId;
  final bool created;

  final bool pendingModeration;

  const SubmitReviewResult({
    required this.reviewId,
    required this.sellerId,
    required this.created,
    required this.pendingModeration,
  });
}

class UploadedReviewPhoto {
  final String? url;
  final String? rejectionReason;

  const UploadedReviewPhoto.uploaded(String this.url) : rejectionReason = null;
  const UploadedReviewPhoto.rejected(String this.rejectionReason) : url = null;

  bool get isRejected => url == null;
}

final sellerReviewServiceProvider = Provider<SellerReviewService>((ref) {
  return SellerReviewService();
});

typedef ReviewTarget = ({String orderId, String sellerId, String buyerId});

final myOrderReviewProvider =
    StreamProvider.family<SellerReviewModel?, ReviewTarget>((ref, target) {
      return ref
          .watch(sellerReviewServiceProvider)
          .watchMyReview(
            orderId: target.orderId,
            sellerId: target.sellerId,
            buyerId: target.buyerId,
          );
    });

ReviewTarget? reviewTargetFor({
  required String orderId,
  required String sellerId,
}) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  return (orderId: orderId, sellerId: sellerId, buyerId: uid);
}

typedef SellerRatingAggregate = ({double averageRating, int totalReviews});

final sellerRatingAggregateProvider =
    StreamProvider.family<SellerRatingAggregate, String>((ref, sellerId) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .snapshots()
          .map((doc) {
            final data = doc.data();
            if (data == null) return (averageRating: 0.0, totalReviews: 0);
            return (
              averageRating: (data['sellerRating'] as num?)?.toDouble() ?? 0.0,
              totalReviews: (data['totalReviews'] as num?)?.toInt() ?? 0,
            );
          });
    });

final myReviewedOrderIdsProvider = StreamProvider.family<Set<String>, String>((
  ref,
  buyerId,
) {
  return FirebaseFirestore.instance
      .collection(SellerReviewService.collection)
      .where('reviewerId', isEqualTo: buyerId)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => (d.data()['orderId'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
});
