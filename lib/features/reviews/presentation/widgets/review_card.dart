import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../shared/models/seller_review_model.dart';
import 'review_photo_gallery.dart';

class ReviewCard extends StatelessWidget {
  final SellerReviewModel review;
  final VoidCallback? onHelpful;
  final VoidCallback? onFlag;

  final VoidCallback? onEdit;

  final VoidCallback? onReply;

  final bool isHelpfulMarked;

  const ReviewCard({
    super.key,
    required this.review,
    this.onHelpful,
    this.onFlag,
    this.onEdit,
    this.onReply,
    this.isHelpfulMarked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review.reviewerPhotoUrl != null
                      ? CachedNetworkImageProvider(review.reviewerPhotoUrl!)
                      : null,
                  child: review.reviewerPhotoUrl == null
                      ? Text(
                          review.reviewerName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildStarRating(review.rating),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(review.createdAt, locale: 'he'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (review.verifiedPurchase || review.productTitle != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (review.verifiedPurchase)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 13,
                            color: Colors.green[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'רכישה מאומתת',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (review.productTitle != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'קנייה: ${review.productTitle}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                ],
              ),
            ],

            if (review.hasDetailedRatings) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (review.communicationRating != null)
                    _buildDetailChip(
                      'תקשורת',
                      review.communicationRating!,
                      Icons.chat_bubble_outline,
                    ),
                  if (review.accuracyRating != null)
                    _buildDetailChip(
                      'דיוק',
                      review.accuracyRating!,
                      Icons.fact_check_outlined,
                    ),
                  if (review.speedRating != null)
                    _buildDetailChip(
                      'מהירות',
                      review.speedRating!,
                      Icons.speed,
                    ),
                  if (review.serviceRating != null)
                    _buildDetailChip(
                      'שירות',
                      review.serviceRating!,
                      Icons.support_agent,
                    ),
                ],
              ),
            ],

            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment!,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],

            if (review.hasPhotos) ...[
              const SizedBox(height: 12),
              ReviewPhotoStrip(
                photoUrls: review.photoUrls!,
                reviewerName: review.reviewerName,
              ),
            ],

            if (review.hasSellerResponse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          'תגובת המוכר',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        if (review.sellerResponseDate != null) ...[
                          const Spacer(),
                          Text(
                            timeago.format(
                              review.sellerResponseDate!,
                              locale: 'he',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      review.sellerResponse!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            if (onEdit != null || onReply != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onEdit != null)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(
                        review.daysLeftToEdit > 0
                            ? 'ערוך (${review.daysLeftToEdit} ימים)'
                            : 'ערוך',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  if (onEdit != null && onReply != null)
                    const SizedBox(width: 8),
                  if (onReply != null)
                    OutlinedButton.icon(
                      onPressed: onReply,
                      icon: const Icon(Icons.reply_outlined, size: 16),
                      label: const Text(
                        'הגב לביקורת',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: onHelpful,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isHelpfulMarked
                          ? Colors.blue[50]
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isHelpfulMarked
                            ? Colors.blue
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHelpfulMarked
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          size: 16,
                          color: isHelpfulMarked
                              ? Colors.blue
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'שימושי (${review.helpfulCount})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isHelpfulMarked
                                ? Colors.blue
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: onFlag,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'דווח',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 16);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        } else {
          return Icon(Icons.star_border, color: Colors.grey[400], size: 16);
        }
      }),
    );
  }

  Widget _buildDetailChip(String label, double rating, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          const SizedBox(width: 4),
          Icon(Icons.star, size: 12, color: Colors.amber),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
