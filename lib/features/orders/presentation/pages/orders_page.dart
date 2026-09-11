import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/order_number.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reviews/data/services/seller_review_service.dart';
import '../../../reviews/presentation/widgets/write_seller_review_sheet.dart';
import '../providers/order_provider.dart';
import 'order_tracking_page.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTabIndex.clamp(0, 1),
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ההזמנות שלי'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'קניות'),
            Tab(text: 'מכירות'),
          ],
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _OrdersList(
                  orders: ref.watch(buyerOrdersProvider(user.id)),
                  asBuyer: true,
                  emptyText: 'עדיין לא קנית כלום',
                  onRetry: () => ref.invalidate(buyerOrdersProvider(user.id)),
                ),
                _OrdersList(
                  orders: ref.watch(sellerOrdersProvider(user.id)),
                  asBuyer: false,
                  emptyText: 'עדיין אין מכירות',
                  onRetry: () => ref.invalidate(sellerOrdersProvider(user.id)),
                ),
              ],
            ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final AsyncValue<List<OrderModel>> orders;
  final bool asBuyer;
  final String emptyText;
  final VoidCallback onRetry;

  const _OrdersList({
    required this.orders,
    required this.asBuyer,
    required this.emptyText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => StreamErrorView(error: e, onRetry: onRetry),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: context.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(emptyText, style: TextStyle(color: context.textSecondary)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _OrderCard(order: list[i], asBuyer: asBuyer),
        );
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final OrderModel order;
  final bool asBuyer;

  const _OrderCard({required this.order, required this.asBuyer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = orderNumberDisplay(order.orderNumber);
    final title = order.isMultiItem
        ? '${order.productTitle} (+${order.lineItems.length - 1})'
        : order.productTitle;
    final counterpartId = asBuyer ? order.sellerId : order.buyerId;
    final counterpartName =
        ref.watch(userDisplayNameProvider(counterpartId)).valueOrNull ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderTrackingPage(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: order.productImageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: order.productImageUrl,
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
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (counterpartName.isNotEmpty)
                              '${asBuyer ? 'מוכר' : 'קונה'}: $counterpartName',
                            DateFormat('dd/MM/yy').format(order.createdAt),
                            if (number != null) number,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₪${order.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
              if (asBuyer && order.status == OrderStatus.completed) ...[
                const SizedBox(height: 10),
                _ReviewSellerButton(order: order, sellerName: counterpartName),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSellerButton extends ConsumerWidget {
  final OrderModel order;
  final String sellerName;

  const _ReviewSellerButton({required this.order, required this.sellerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = reviewTargetFor(orderId: order.id, sellerId: order.sellerId);
    if (target == null) return const SizedBox.shrink();

    final myReview = ref.watch(myOrderReviewProvider(target)).valueOrNull;

    if (myReview != null && !myReview.isEditableBy(target.buyerId)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            'כתבת ביקורת (${myReview.rating.toStringAsFixed(0)} כוכבים)',
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      );
    }

    final isEdit = myReview != null;
    return ElevatedButton.icon(
      onPressed: () => WriteSellerReviewSheet.show(
        context,
        orderId: order.id,
        sellerId: order.sellerId,
        sellerName: sellerName,
        productTitle: order.productTitle,
        existing: myReview,
      ),
      icon: Icon(isEdit ? Icons.edit_outlined : Icons.star_outline_rounded),
      label: Text(isEdit ? 'ערוך את הביקורת שלך' : 'דרג את המוכר'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
