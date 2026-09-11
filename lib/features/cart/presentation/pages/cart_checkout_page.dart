import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/feature_flags.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/cart_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../providers/cart_provider.dart';

class _SellerGroup {
  final String sellerId;
  final String sellerName;
  final List<CartItem> items;

  const _SellerGroup(this.sellerId, this.sellerName, this.items);

  double get total =>
      items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  Map<String, int> get quantities => {
    for (final item in items) item.productId: item.quantity,
  };
}

List<_SellerGroup> _groupBySeller(List<CartItem> items) {
  final groups = <String, List<CartItem>>{};
  for (final item in items) {
    groups.putIfAbsent(item.sellerId, () => []).add(item);
  }
  return [
    for (final entry in groups.entries)
      _SellerGroup(entry.key, entry.value.first.sellerName, entry.value),
  ];
}

class CartCheckoutPage extends ConsumerStatefulWidget {
  final ShoppingCart cart;

  const CartCheckoutPage({super.key, required this.cart});

  @override
  ConsumerState<CartCheckoutPage> createState() => _CartCheckoutPageState();
}

class _CartCheckoutPageState extends ConsumerState<CartCheckoutPage> {
  final _notesController = TextEditingController();
  bool _isLoading = false;

  late final List<_SellerGroup> _groups = _groupBySeller(widget.cart.items);

  double get _total => _groups.fold(0.0, (sum, g) => sum + g.total);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final buyer = ref.read(currentUserProvider).value;
    if (buyer == null) {
      _showError('יש להתחבר כדי לבצע הזמנה');
      return;
    }
    if (widget.cart.hasStockIssues) {
      _showError('חלק מהפריטים בעגלה כבר לא זמינים בכמות שבחרת');
      return;
    }

    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);
    final controller = ref.read(orderControllerProvider.notifier);
    final products = ProductRepository();
    final created = <OrderModel>[];

    try {
      for (final group in _groups) {
        final first = group.items.first;
        final ProductModel? product = await products.getProduct(
          first.productId,
        );
        final order = await controller.createOrder(
          productId: first.productId,
          sellerId: group.sellerId,
          buyerId: buyer.id,
          productTitle: first.productTitle,
          productImageUrl: first.productImage ?? '',
          productPrice: first.price,
          pickupAddress: product?.city,
          pickupLocation: product?.location,
          paymentMethod: FeatureFlags.paymentEnabled
              ? OrderModel.paymentCard
              : OrderModel.paymentOnPickup,
          buyerNotes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          additionalItems: [
            for (final item in group.items.skip(1))
              OrderLineItem(
                productId: item.productId,
                productTitle: item.productTitle,
                productImageUrl: item.productImage ?? '',
                price: item.price,
              ),
          ],
          quantities: group.quantities,
        );
        if (order != null) created.add(order);
      }

      if (created.isEmpty) return;

      if (FeatureFlags.paymentEnabled) {
        final total = created.fold(0.0, (sum, o) => sum + o.totalAmount);
        final result = await PaymentService().processPayment(
          amount: total,
          currency: 'ils',
          orderIds: created.map((o) => o.id).toList(),
          description: 'הזמנה מהעגלה',
          metadata: {'buyerId': buyer.id},
        );
        if (!result.success || result.paymentIntentId == null) {
          for (final order in created) {
            await controller.cancelOrder(
              order.id,
              reason: result.error ?? 'התשלום נכשל או בוטל',
            );
          }
          _showError('התשלום לא הושלם: ${result.error ?? "בוטל"}');
          return;
        }
      }

      for (final order in created) {
        await NotificationService().notifyNewOrder(
          sellerId: order.sellerId,
          orderId: order.id,
          productTitle: order.productTitle,
          buyerName: buyer.displayName ?? 'קונה',
        );
      }

      await ref
          .read(cartControllerProvider.notifier)
          .removeItems(
            buyer.id,
            widget.cart.items.map((i) => i.productId).toList(),
          );

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ההזמנות נקלטו בהצלחה!'),
          content: Text(
            created.length == 1
                ? 'המוכר קיבל הודעה. כתובת האיסוף מופיעה בדף ההזמנה.'
                : 'נוצרו ${created.length} הזמנות, אחת לכל מוכר. '
                      'כתובות האיסוף מופיעות בדף ההזמנות.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                navigator.pop();
              },
              child: const Text('אישור'),
            ),
          ],
        ),
      );
    } catch (e) {
      for (final order in created) {
        try {
          await controller.cancelOrder(
            order.id,
            reason: 'ההזמנה בוטלה כי חלק מהעגלה לא הושלם',
          );
        } catch (_) {}
      }
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('סיום הזמנה')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final group in _groups)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            group.sellerName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'איסוף עצמי',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    for (final item in group.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.quantity > 1
                                    ? '${item.productTitle} ×${item.quantity}'
                                    : item.productTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '₪${(item.price * item.quantity).toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'הערה למוכרים (לא חובה)',
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
                '₪${_total.toStringAsFixed(2)}',
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
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      _groups.length == 1
                          ? 'אישור ורכישה'
                          : 'אישור ורכישה (${_groups.length} הזמנות)',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
