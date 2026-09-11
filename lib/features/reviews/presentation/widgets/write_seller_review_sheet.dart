import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_picker_web.dart';
import '../../../../shared/models/seller_review_model.dart';
import '../../data/services/seller_review_service.dart';
import 'review_photo_gallery.dart';

class WriteSellerReviewSheet extends ConsumerStatefulWidget {
  final String orderId;
  final String sellerId;
  final String sellerName;
  final String? productTitle;

  final SellerReviewModel? existing;

  const WriteSellerReviewSheet({
    super.key,
    required this.orderId,
    required this.sellerId,
    required this.sellerName,
    this.productTitle,
    this.existing,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    required String sellerId,
    required String sellerName,
    String? productTitle,
    SellerReviewModel? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WriteSellerReviewSheet(
        orderId: orderId,
        sellerId: sellerId,
        sellerName: sellerName,
        productTitle: productTitle,
        existing: existing,
      ),
    );
  }

  @override
  ConsumerState<WriteSellerReviewSheet> createState() =>
      _WriteSellerReviewSheetState();
}

class _WriteSellerReviewSheetState
    extends ConsumerState<WriteSellerReviewSheet> {
  static const int _maxPhotoBytes = 10 * 1024 * 1024;

  late final TextEditingController _commentController;
  late int _rating;

  late final List<String> _photoUrls;

  bool _submitting = false;
  bool _uploading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _rating = existing?.rating.round() ?? 0;
    _commentController = TextEditingController(text: existing?.comment ?? '');
    _photoUrls = List<String>.from(existing?.photoUrls ?? const <String>[]);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _isEdit ? 'עריכת הביקורת שלך' : 'דרג את ${widget.sellerName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.productTitle != null &&
                    widget.productTitle!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'על הרכישה: ${widget.productTitle}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _identityStrip(),
                const SizedBox(height: AppSpacing.md),
                _stars(),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Text(
                    _ratingLabel(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _rating > 0
                          ? AppColors.sunDeep
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _commentController,
                  maxLines: 5,
                  minLines: 3,
                  maxLength: SellerReviewService.maxCommentChars,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'ספר על החוויה שלך',
                    hintText: 'איך הייתה התקשורת? האם המוצר היה כמתואר?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                _quickComments(),
                const SizedBox(height: AppSpacing.md),
                _photos(),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _submitButton(),
                if (_isEdit) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: Text(
                      widget.existing!.daysLeftToEdit > 0
                          ? 'ניתן לערוך את הביקורת עוד ${widget.existing!.daysLeftToEdit} ימים'
                          : 'חלון העריכה נסגר',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStrip() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cobalt.withValues(alpha: 0.06),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: AppColors.cobalt,
          ),
          const SizedBox(width: AppSpacing.xs),
          const Expanded(
            child: Text(
              'הביקורת מתפרסמת בשמך ובתמונת הפרופיל שלך. אין ביקורות אנונימיות — '
              'כך אי אפשר לזייף ביקורות.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final value = index + 1;
        return IconButton(
          onPressed: _busy ? null : () => setState(() => _rating = value),
          icon: Icon(
            value <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber,
            size: 40,
          ),
          tooltip: '$value',
        );
      }),
    );
  }

  Widget _quickComments() {
    const suggestions = [
      'תקשורת מצוינת',
      'מסירה מהירה',
      'מוצר כמתואר',
      'מומלץ בחום',
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: suggestions.map((text) {
        return InkWell(
          onTap: _busy ? null : () => _appendQuickComment(text),
          borderRadius: AppRadius.chipR,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs + 2,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.chipR,
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _appendQuickComment(String text) {
    final current = _commentController.text.trim();
    if (current.contains(text)) return;
    _commentController.text = current.isEmpty ? text : '$current, $text';
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
  }

  Widget _photos() {
    final remaining = SellerReviewService.maxPhotos - _photoUrls.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'תמונות (${_photoUrls.length}/${SellerReviewService.maxPhotos})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (remaining > 0)
              TextButton.icon(
                onPressed: _busy ? null : _addPhotos,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('הוסף'),
                style: TextButton.styleFrom(foregroundColor: AppColors.cobalt),
              ),
          ],
        ),
        if (_uploading) ...[
          const SizedBox(height: AppSpacing.xs),
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'מעלה ובודק את התמונות…',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
        if (_photoUrls.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photoUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                return _photoThumb(index);
              },
            ),
          ),
        ] else if (!_uploading) ...[
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'תמונות עוזרות לקונים הבאים להאמין לביקורת. אפשר גם בלי.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _photoThumb(int index) {
    const double thumbSize = 80;

    return SizedBox(
      width: thumbSize,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => ReviewPhotoGallery.open(
              context,
              photoUrls: _photoUrls,
              initialIndex: index,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: _photoUrls[index],
                width: thumbSize,
                height: thumbSize,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: thumbSize,
                  height: thumbSize,
                  color: AppColors.surfaceVariant,
                ),
                errorWidget: (context, url, error) => Container(
                  width: thumbSize,
                  height: thumbSize,
                  color: AppColors.surfaceVariant,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: InkWell(
              onTap: _busy
                  ? null
                  : () => setState(() => _photoUrls.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.card),
                    bottomRight: Radius.circular(AppRadius.card),
                  ),
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return ElevatedButton(
      onPressed: _rating == 0 || _busy ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cobalt,
        foregroundColor: AppColors.textOnPrimary,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
      ),
      child: _submitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isEdit ? 'עדכן ביקורת' : 'פרסם ביקורת',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
    );
  }

  bool get _busy => _submitting || _uploading;

  String _ratingLabel() {
    switch (_rating) {
      case 1:
        return 'גרוע';
      case 2:
        return 'לא טוב';
      case 3:
        return 'בסדר';
      case 4:
        return 'טוב';
      case 5:
        return 'מעולה!';
      default:
        return 'בחר דירוג';
    }
  }

  Future<void> _addPhotos() async {
    final service = ref.read(sellerReviewServiceProvider);
    final target = reviewTargetFor(
      orderId: widget.orderId,
      sellerId: widget.sellerId,
    );
    if (target == null) {
      setState(() => _error = 'יש להתחבר כדי לצרף תמונות');
      return;
    }

    final remaining = SellerReviewService.maxPhotos - _photoUrls.length;
    if (remaining <= 0) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    final rejected = <String>[];
    try {
      final picked = await ImagePickerWeb.pickMultipleImages(
        maxImages: remaining,
      );
      for (var i = 0; i < picked.length; i++) {
        final image = picked[i];
        if (image.bytes.length > _maxPhotoBytes) {
          rejected.add('${image.name}: הקובץ גדול מ-10MB');
          continue;
        }
        final result = await service.uploadPhoto(
          orderId: widget.orderId,
          buyerId: target.buyerId,
          image: image,
          index: _photoUrls.length + i,
        );
        if (result == null || result.isRejected) {
          rejected.add(result?.rejectionReason ?? 'התמונה נדחתה');
          continue;
        }
        if (!mounted) return;
        setState(() => _photoUrls.add(result.url!));
      }
    } catch (e) {
      rejected.add('שגיאה בהעלאת תמונה: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = rejected.isEmpty ? null : rejected.join('\n');
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(sellerReviewServiceProvider)
          .submitReview(
            orderId: widget.orderId,
            rating: _rating,
            comment: _commentController.text.trim(),
            photoUrls: _photoUrls,
          );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.pendingModeration
                ? 'הביקורת נשמרה וממתינה לבדיקה לפני פרסום'
                : result.created
                ? 'תודה! הביקורת פורסמה'
                : 'הביקורת עודכנה',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'שליחת הביקורת נכשלה');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'שליחת הביקורת נכשלה: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
