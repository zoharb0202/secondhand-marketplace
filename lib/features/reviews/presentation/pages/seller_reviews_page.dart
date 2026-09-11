import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/seller_review_model.dart';
import '../../data/services/seller_review_service.dart';
import '../widgets/review_card.dart';
import '../widgets/write_seller_review_sheet.dart';

final sellerReviewsStreamProvider =
    StreamProvider.family<List<SellerReviewModel>, String>((ref, sellerId) {
      return FirebaseFirestore.instance
          .collection('seller_reviews')
          .where('sellerId', isEqualTo: sellerId)
          .where('isVisible', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => SellerReviewModel.fromFirestore(doc))
                .toList(),
          );
    });

class SellerReviewsPage extends ConsumerStatefulWidget {
  final String sellerId;
  final String sellerName;
  final double? averageRating;
  final int? totalReviews;

  const SellerReviewsPage({
    super.key,
    required this.sellerId,
    required this.sellerName,
    this.averageRating,
    this.totalReviews,
  });

  @override
  ConsumerState<SellerReviewsPage> createState() => _SellerReviewsPageState();
}

class _SellerReviewsPageState extends ConsumerState<SellerReviewsPage> {
  String _sortBy = 'recent';

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(
      sellerReviewsStreamProvider(widget.sellerId),
    );
    final aggregateAsync = ref.watch(
      sellerRatingAggregateProvider(widget.sellerId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('ביקורות - ${widget.sellerName}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 20),
                    SizedBox(width: 8),
                    Text('האחרונות'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'highest',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 20, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('דירוג גבוה'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lowest',
                child: Row(
                  children: [
                    Icon(Icons.star_border, size: 20),
                    SizedBox(width: 8),
                    Text('דירוג נמוך'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: reviewsAsync.when(
        data: (reviews) {
          if (reviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'עדיין אין ביקורות',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ביקורות נכתבות על ידי קונים שרכשו מהמוכר',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final sortedReviews = _sortReviews(reviews);

          final stats = _calculateStats(reviews);
          final headline = _headline(aggregateAsync.valueOrNull, reviews);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        Colors.white,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            headline.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12, right: 4),
                            child: Text(
                              '/ 5',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final rating = headline.averageRating;
                          return Icon(
                            index < rating.floor()
                                ? Icons.star
                                : index < rating
                                ? Icons.star_half
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 28,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'מבוסס על ${headline.totalReviews} ביקורות',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      _buildRatingDistribution(stats),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'כל הביקורות (${reviews.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getSortIcon(),
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getSortLabel(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final review = sortedReviews[index];
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final isHelpfulMarked =
                        uid != null && review.markedHelpfulBy.contains(uid);
                    final isAuthor = uid != null && uid == review.reviewerId;
                    final isSeller = uid != null && uid == review.sellerId;
                    return ReviewCard(
                      review: review,
                      isHelpfulMarked: isHelpfulMarked,
                      onHelpful: isAuthor || isHelpfulMarked
                          ? null
                          : () => _markAsHelpful(review.id),
                      onFlag: isAuthor ? null : () => _flagReview(review.id),
                      onEdit:
                          isAuthor &&
                              review.isEditableBy(uid) &&
                              (review.orderId ?? '').isNotEmpty
                          ? () => _editReview(review)
                          : null,
                      onReply: isSeller && !review.hasSellerResponse
                          ? () => _replyToReview(review.id)
                          : null,
                    );
                  }, childCount: sortedReviews.length),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StreamErrorView(
          error: error,
          title: 'לא הצלחנו לטעון את הביקורות',
          onRetry: () =>
              ref.invalidate(sellerReviewsStreamProvider(widget.sellerId)),
        ),
      ),
    );
  }

  SellerRatingAggregate _headline(
    SellerRatingAggregate? serverAggregate,
    List<SellerReviewModel> reviews,
  ) {
    if (serverAggregate != null && serverAggregate.totalReviews > 0) {
      return serverAggregate;
    }
    if ((widget.totalReviews ?? 0) > 0 && widget.averageRating != null) {
      return (
        averageRating: widget.averageRating!,
        totalReviews: widget.totalReviews!,
      );
    }
    if (reviews.isEmpty) return (averageRating: 0.0, totalReviews: 0);
    final total = reviews.fold<double>(0, (acc, r) => acc + r.rating);
    return (
      averageRating: total / reviews.length,
      totalReviews: reviews.length,
    );
  }

  List<SellerReviewModel> _sortReviews(List<SellerReviewModel> reviews) {
    final sorted = List<SellerReviewModel>.from(reviews);

    switch (_sortBy) {
      case 'highest':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'lowest':
        sorted.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case 'recent':
      default:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return sorted;
  }

  Map<String, dynamic> _calculateStats(List<SellerReviewModel> reviews) {
    if (reviews.isEmpty) {
      return {
        'fiveStars': 0,
        'fourStars': 0,
        'threeStars': 0,
        'twoStars': 0,
        'oneStars': 0,
      };
    }

    return {
      'fiveStars': reviews.where((r) => r.rating == 5).length,
      'fourStars': reviews.where((r) => r.rating == 4).length,
      'threeStars': reviews.where((r) => r.rating == 3).length,
      'twoStars': reviews.where((r) => r.rating == 2).length,
      'oneStars': reviews.where((r) => r.rating == 1).length,
    };
  }

  Widget _buildRatingDistribution(Map<String, dynamic> stats) {
    final total =
        stats['fiveStars'] +
        stats['fourStars'] +
        stats['threeStars'] +
        stats['twoStars'] +
        stats['oneStars'];

    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        _buildDistributionBar(5, stats['fiveStars'], total),
        _buildDistributionBar(4, stats['fourStars'], total),
        _buildDistributionBar(3, stats['threeStars'], total),
        _buildDistributionBar(2, stats['twoStars'], total),
        _buildDistributionBar(1, stats['oneStars'], total),
      ],
    );
  }

  Widget _buildDistributionBar(int stars, int count, int total) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Row(
              children: [
                Text(
                  '$stars',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 14, color: Colors.amber),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 35,
            child: Text(
              count.toString(),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'highest':
        return 'דירוג גבוה';
      case 'lowest':
        return 'דירוג נמוך';
      case 'recent':
      default:
        return 'האחרונות';
    }
  }

  IconData _getSortIcon() {
    switch (_sortBy) {
      case 'highest':
        return Icons.arrow_upward;
      case 'lowest':
        return Icons.arrow_downward;
      case 'recent':
      default:
        return Icons.access_time;
    }
  }

  void _showCallableError(Object error, String fallback) {
    if (!mounted) return;
    final message = error is FirebaseFunctionsException
        ? (error.message ?? fallback)
        : fallback;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _markAsHelpful(String reviewId) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להתחבר כדי לסמן ביקורת כשימושית')),
      );
      return;
    }

    try {
      await ref.read(sellerReviewServiceProvider).markHelpful(reviewId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('תודה על המשוב!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showCallableError(e, 'לא ניתן לסמן את הביקורת כרגע');
    }
  }

  Future<void> _flagReview(String reviewId) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('דווח על ביקורת'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('מדוע ברצונך לדווח על ביקורת זו?'),
            const SizedBox(height: 16),
            ...[
              'תוכן פוגעני או בוטה',
              'לא רלוונטי',
              'ספאם',
              'מידע כוזב',
              'אחר',
            ].map(
              (reason) => ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      await ref
          .read(sellerReviewServiceProvider)
          .flagReview(reviewId: reviewId, reason: result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('הדיווח נשלח. תודה!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showCallableError(e, 'שליחת הדיווח נכשלה');
    }
  }

  Future<void> _editReview(SellerReviewModel review) async {
    await WriteSellerReviewSheet.show(
      context,
      orderId: review.orderId!,
      sellerId: review.sellerId,
      sellerName: widget.sellerName,
      productTitle: review.productTitle,
      existing: review,
    );
  }

  Future<void> _replyToReview(String reviewId) async {
    final controller = TextEditingController();
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('תגובת המוכר'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'אפשר להגיב פעם אחת בלבד, והתגובה מוצגת בפומבי מתחת לביקורת.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: SellerReviewService.maxReplyChars,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'התגובה שלך לביקורת',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('שלח תגובה'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (reply == null || reply.isEmpty || !mounted) return;

    try {
      await ref
          .read(sellerReviewServiceProvider)
          .replyToReview(reviewId: reviewId, reply: reply);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התגובה פורסמה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showCallableError(e, 'שליחת התגובה נכשלה');
    }
  }
}
