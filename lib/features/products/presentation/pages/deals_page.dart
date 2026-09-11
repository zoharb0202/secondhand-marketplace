import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import 'product_detail_page.dart';

class DealsPage extends ConsumerWidget {
  const DealsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bargains = ref.watch(bargainsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer, size: 20),
            SizedBox(width: 8),
            Text('מציאון'),
          ],
        ),
      ),
      body: bargains.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _DealsMessage(
          icon: Icons.cloud_off_outlined,
          title: 'לא הצלחנו לטעון את המציאון',
          subtitle: 'בדקו את החיבור לאינטרנט ונסו שוב',
          action: TextButton.icon(
            onPressed: () => ref.invalidate(bargainsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('נסו שוב'),
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return const _DealsMessage(
              icon: Icons.local_offer_outlined,
              title: 'אין מציאות כרגע',
              subtitle:
                  'כאן יופיעו מוצרים שמחירם נמוך משמעותית ממחיר החדש בחנות',
            );
          }
          return _BargainsGrid(products: products);
        },
      ),
    );
  }
}

class _BargainsGrid extends ConsumerWidget {
  const _BargainsGrid({required this.products});

  final List<ProductModel> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.palm.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            '${products.length} מוצרים מתחת למחיר החדש בחנות — '
            'מעבר לבלאי הרגיל של מצב הפריט',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.62,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final isLiked =
                  currentUser != null &&
                  product.likedByUserIds.contains(currentUser.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ProductCard(
                      product: product,
                      isLiked: isLiked,
                      onLike: currentUser != null
                          ? () => ref
                                .read(productControllerProvider.notifier)
                                .toggleLike(product.id, currentUser.id)
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProductDetailPage(productId: product.id),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _RetailAnchorLine(product: product),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RetailAnchorLine extends StatelessWidget {
  const _RetailAnchorLine({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final retail = product.retailEstimate;
    if (retail == null || retail <= 0) return const SizedBox.shrink();
    final pct = product.bargainDiscountPercent;

    return Row(
      children: [
        if (pct != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.palm,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$pct%-',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            'חדש עולה ${_formatIls(retail)} ₪',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatIls(double value) {
  final digits = value.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

class _DealsMessage extends StatelessWidget {
  const _DealsMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
