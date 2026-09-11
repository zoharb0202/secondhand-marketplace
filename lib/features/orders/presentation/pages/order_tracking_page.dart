import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/order_number.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../support/presentation/pages/ticket_chat_page.dart';
import '../providers/order_provider.dart';
import '../widgets/order_problem_sheet.dart';

class OrderTrackingPage extends ConsumerWidget {
  final String orderId;

  const OrderTrackingPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final me = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('פרטי הזמנה')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('שגיאה בטעינת ההזמנה: $e')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('ההזמנה לא נמצאה'));
          }
          final isSeller = me?.id == order.sellerId;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(order: order),
              const SizedBox(height: 16),
              _StatusSteps(
                status: order.status,
                payOnPickup: order.isPayOnPickup,
              ),
              const SizedBox(height: 16),
              _ItemsCard(order: order),
              const SizedBox(height: 16),
              _PickupCard(order: order, isSeller: isSeller),
              if (order.buyerNotes != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.sticky_note_2_outlined),
                    title: const Text('הערת הקונה'),
                    subtitle: Text(order.buyerNotes!),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _Actions(order: order, isSeller: isSeller),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final OrderModel order;
  const _Header({required this.order});

  @override
  Widget build(BuildContext context) {
    final number = orderNumberDisplay(order.orderNumber);
    final date = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number != null ? '$orderNumberLabelHe $number' : 'הזמנה',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(date, style: TextStyle(color: context.textSecondary)),
            ],
          ),
        ),
        OrderStatusChip(status: order.status),
      ],
    );
  }
}

class OrderStatusChip extends StatelessWidget {
  final OrderStatus status;
  const OrderStatusChip({super.key, required this.status});

  static Color colorFor(OrderStatus status) => switch (status) {
    OrderStatus.pending => AppColors.warning,
    OrderStatus.paid => AppColors.info,
    OrderStatus.readyForPickup => AppColors.primary,
    OrderStatus.completed => AppColors.success,
    OrderStatus.cancelled => AppColors.error,
    OrderStatus.disputed => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusSteps extends StatelessWidget {
  final OrderStatus status;
  final bool payOnPickup;
  const _StatusSteps({required this.status, this.payOnPickup = false});

  List<OrderStatus> get _steps => [
    if (!payOnPickup) OrderStatus.paid,
    OrderStatus.readyForPickup,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled || status == OrderStatus.disputed) {
      return const SizedBox.shrink();
    }
    final current = _steps.indexOf(status);
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= current
                      ? AppColors.primary
                      : context.altSurface,
                  child: Icon(
                    i < current || status == OrderStatus.completed
                        ? Icons.check
                        : Icons.circle,
                    size: i <= current ? 16 : 8,
                    color: i <= current ? Colors.white : context.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i].displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: i <= current
                        ? context.textPrimary
                        : context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final OrderModel order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final item in order.lineItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: item.productImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.productImageUrl,
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
                      child: Text(
                        item.productTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('₪${item.price.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'סה״כ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '₪${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  final OrderModel order;
  final bool isSeller;
  const _PickupCard({required this.order, required this.isSeller});

  Future<void> _openMaps() async {
    final loc = order.pickupLocation;
    final query = loc != null && (loc.latitude != 0 || loc.longitude != 0)
        ? '${loc.latitude},${loc.longitude}'
        : Uri.encodeComponent(order.pickupAddress ?? '');
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final revealed = isSeller || order.isPickupRevealed;
    final address = order.pickupAddress;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.person_pin_circle_outlined,
              color: AppColors.primary,
            ),
            title: const Text('איסוף עצמי'),
            subtitle: Text(
              !revealed
                  ? 'כתובת האיסוף תוצג לאחר התשלום'
                  : (address?.isNotEmpty ?? false)
                  ? address!
                  : 'תאמו את כתובת האיסוף בצ׳אט',
            ),
            trailing: revealed && (address?.isNotEmpty ?? false)
                ? IconButton(
                    tooltip: 'פתיחה במפות',
                    icon: const Icon(Icons.map_outlined),
                    onPressed: _openMaps,
                  )
                : null,
          ),
          if (revealed && order.pickupPhone != null)
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(order.pickupPhone!),
              onTap: () => launchUrl(Uri.parse('tel:${order.pickupPhone}')),
            ),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  final OrderModel order;
  final bool isSeller;
  const _Actions({required this.order, required this.isSeller});

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    final repo = ref.read(chatRepositoryProvider);
    final names = await Future.wait([
      ref.read(userDisplayNameProvider(order.sellerId).future),
      ref.read(userDisplayNameProvider(order.buyerId).future),
    ]);
    final chat = await repo.getOrCreateChat(
      productId: order.productId,
      productTitle: order.productTitle,
      productImageUrl: order.productImageUrl,
      sellerId: order.sellerId,
      sellerName: names[0],
      buyerId: order.buyerId,
      buyerName: names[1],
    );
    if (context.mounted) context.push('/chat/${chat.id}');
  }

  Future<void> _confirm(
    BuildContext context,
    String title,
    String body,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('אישור'),
          ),
        ],
      ),
    );
    if (ok == true) await action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(orderControllerProvider.notifier);
    final busy = ref.watch(orderControllerProvider).isLoading;
    final status = order.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSeller && order.canMarkReady)
          ElevatedButton.icon(
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('המוצר מוכן לאיסוף'),
            onPressed: busy
                ? null
                : () => _confirm(
                    context,
                    'המוצר מוכן לאיסוף?',
                    'הקונה יקבל הודעה שאפשר להגיע לאסוף.',
                    () => controller.markReadyForPickup(order.id),
                  ),
          ),
        if (!isSeller &&
            (status == OrderStatus.paid ||
                status == OrderStatus.readyForPickup))
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('אספתי את המוצר'),
            onPressed: busy
                ? null
                : () => _confirm(
                    context,
                    'לאשר איסוף?',
                    'אשר רק אחרי שקיבלת את המוצר ובדקת אותו.',
                    () => controller.confirmPickup(order.id),
                  ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(isSeller ? 'צ׳אט עם הקונה' : 'תיאום איסוף בצ׳אט'),
          onPressed: () => _openChat(context, ref),
        ),
        if (order.disputeTicketId != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.support_agent),
            label: const Text('פנייה לשירות הלקוחות'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TicketChatPage(ticketId: order.disputeTicketId!),
              ),
            ),
          ),
        ] else if (!isSeller &&
            status != OrderStatus.cancelled &&
            status != OrderStatus.pending) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('דיווח על בעיה בהזמנה'),
            onPressed: () => OrderProblemSheet.show(context, order),
          ),
        ],
        if (status == OrderStatus.pending) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: busy
                ? null
                : () => _confirm(
                    context,
                    'לבטל את ההזמנה?',
                    'המוצר יחזור להיות זמין למכירה.',
                    () => controller.cancelOrder(order.id),
                  ),
            child: const Text('ביטול הזמנה'),
          ),
        ],
      ],
    );
  }
}
