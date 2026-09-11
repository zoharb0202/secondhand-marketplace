import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/feature_flags.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/order_provider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  final ProductModel product;

  final double? overridePrice;

  final String? offerId;

  const CheckoutPage({
    super.key,
    required this.product,
    this.overridePrice,
    this.offerId,
  });

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _notesController = TextEditingController();
  bool _isLoading = false;

  double get _price => widget.overridePrice ?? widget.product.price;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    final buyer = ref.read(currentUserProvider).value;
    if (buyer == null) {
      _showError('יש להתחבר כדי לבצע הזמנה');
      return;
    }
    if (buyer.id == widget.product.sellerId) {
      _showError('לא ניתן לקנות מוצר שפרסמת בעצמך');
      return;
    }

    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);

    try {
      final product = widget.product;
      final order = await ref
          .read(orderControllerProvider.notifier)
          .createOrder(
            productId: product.id,
            sellerId: product.sellerId,
            buyerId: buyer.id,
            productTitle: product.title,
            productImageUrl: product.imageUrls.isNotEmpty
                ? product.imageUrls.first
                : '',
            productPrice: _price,
            pickupAddress: product.city,
            pickupLocation: product.location,
            buyerNotes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            paymentMethod: FeatureFlags.paymentEnabled
                ? OrderModel.paymentCard
                : OrderModel.paymentOnPickup,
            offerId: widget.offerId,
          );
      if (order == null) return;

      if (FeatureFlags.paymentEnabled && !await _pay(order, buyer.id)) return;

      await NotificationService().notifyNewOrder(
        sellerId: order.sellerId,
        orderId: order.id,
        productTitle: order.productTitle,
        buyerName: buyer.displayName ?? 'קונה',
      );

      if (widget.offerId != null && widget.offerId!.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('price_offers')
              .doc(widget.offerId)
              .update({'status': 'completed', 'orderId': order.id});
        } catch (e) {
          if (kDebugMode) debugPrint('Failed to mark offer completed: $e');
        }
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ההזמנה נקלטה בהצלחה!'),
          content: const Text(
            'המוכר קיבל הודעה על ההזמנה. כתובת האיסוף מופיעה בדף ההזמנה, '
            'ואפשר לתאם את מועד האיסוף עם המוכר בצ׳אט.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                navigator.pop();
                if (widget.offerId == null) navigator.pop();
              },
              child: const Text('אישור'),
            ),
          ],
        ),
      );
    } catch (e) {
      final busy =
          e is FirebaseException &&
          (e.code == 'aborted' || e.code == 'deadline-exceeded');
      _showError(
        busy ? 'המערכת עמוסה כרגע, נסה שוב' : 'שגיאה ביצירת הזמנה: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _pay(OrderModel order, String buyerId) async {
    final result = await PaymentService().processPayment(
      amount: order.totalAmount,
      currency: 'ils',
      orderIds: [order.id],
      description: order.productTitle,
      metadata: {'sellerId': order.sellerId, 'buyerId': buyerId},
    );
    if (result.success && result.paymentIntentId != null) return true;

    await ref
        .read(orderControllerProvider.notifier)
        .cancelOrder(order.id, reason: result.error ?? 'התשלום נכשל או בוטל');
    _showError('התשלום לא הושלם: ${result.error ?? "בוטל"}');
    return false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('סיום הזמנה')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: product.imageUrls.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl:
                                  product.thumbnailUrl ??
                                  product.imageUrls.first,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: context.altSurface,
                              child: const Icon(Icons.image_outlined),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₪${_price.toStringAsFixed(0)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.person_pin_circle_outlined,
                color: AppColors.primary,
              ),
              title: const Text('איסוף עצמי מהמוכר'),
              subtitle: Text(
                product.city.isNotEmpty
                    ? 'באזור ${product.city}. הכתובת המדויקת תוצג כשההזמנה תאושר.'
                    : 'הכתובת המדויקת תוצג כשההזמנה תאושר.',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'הערה למוכר (לא חובה)',
              hintText: 'למשל: מתי נוח לך שאגיע לאסוף?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'סה״כ לתשלום',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '₪${_price.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitOrder,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('אישור ורכישה'),
            ),
          ),
        ],
      ),
    );
  }
}
