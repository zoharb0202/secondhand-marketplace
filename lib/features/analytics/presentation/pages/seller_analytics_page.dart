import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/seller_revenue.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/data/repositories/order_repository.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';

class SellerAnalyticsPage extends ConsumerWidget {
  const SellerAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('יש להתחבר')));
    }

    final sellerId = user.uid;
    final productsAsync = ref.watch(productsBySellerProvider(sellerId));

    return Scaffold(
      appBar: AppBar(title: const Text('אנליטיקס')),
      body: SingleChildScrollView(
        padding: NavBarClearance.pad(context, base: const EdgeInsets.all(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummarySection(context, ref, sellerId, productsAsync),
            const SizedBox(height: 24),

            const Text(
              'צפיות לפי יום',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDailyViewsChart(context, user.uid),
            const SizedBox(height: 24),

            const Text(
              'צפיות במוצרים',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildViewsChart(context, ref, sellerId, productsAsync),
            const SizedBox(height: 24),

            const Text(
              'מוצרים פופולריים',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTopProducts(context, ref, sellerId, productsAsync),
            const SizedBox(height: 24),

            const Text(
              'מכירות והכנסות',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _SalesAndRevenueSection(sellerId: sellerId),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    WidgetRef ref,
    String sellerId,
    AsyncValue<List<ProductModel>> productsAsync,
  ) {
    return productsAsync.when(
      loading: () => const _SummaryRowPlaceholder(),
      error: (error, _) => StreamErrorView.compact(
        error: error,
        onRetry: () => ref.invalidate(productsBySellerProvider(sellerId)),
      ),
      data: (products) {
        int activeProducts = 0;
        int soldProducts = 0;
        int totalViews = 0;
        int totalLikes = 0;

        for (final product in products) {
          if (product.isActive && !product.isSold) {
            activeProducts++;
          }
          if (product.isSold) {
            soldProducts++;
          }
          totalViews += product.viewCount;
          totalLikes += product.likeCount;
        }

        return Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'מוצרים פעילים',
                value: activeProducts.toString(),
                icon: Icons.inventory_2,
                color: context.accentCobalt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'נמכרו',
                value: soldProducts.toString(),
                icon: Icons.sell,
                color: AppColors.palm,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'צפיות',
                value: totalViews.toString(),
                icon: Icons.visibility,
                color: AppColors.sunDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'לייקים',
                value: totalLikes.toString(),
                icon: Icons.favorite,
                color: AppColors.coral,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDailyViewsChart(BuildContext context, String userId) {
    const windowDays = 14;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('product_daily_stats')
          .where('sellerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: context.altSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final now = DateTime.now();
        final dateKeys = <String>[];
        for (int i = windowDays - 1; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          final key =
              '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}';
          dateKeys.add(key);
        }

        final perDay = <String, int>{for (final k in dateKeys) k: 0};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final days = data['days'];
          if (days is Map) {
            days.forEach((key, value) {
              final k = key?.toString();
              if (k != null && perDay.containsKey(k) && value is Map) {
                perDay[k] = perDay[k]! + ((value['views'] ?? 0) as num).toInt();
              }
            });
          }
        }

        final totalWindow = perDay.values.fold<int>(0, (a, b) => a + b);
        if (totalWindow == 0) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: context.altSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'נתוני צפיות יומיים נאספים אחת ליום — הגרף יתמלא בקרוב',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        int maxViews = 1;
        for (final v in perDay.values) {
          if (v > maxViews) maxViews = v;
        }

        return Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: context.altSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dateKeys.map((key) {
              final views = perDay[key] ?? 0;
              final fraction = (views / maxViews).clamp(0.0, 1.0);
              final parts = key.split('-');
              final label = parts.length == 3 ? '${parts[2]}/${parts[1]}' : key;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        views.toString(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: (fraction * 120).clamp(2.0, 120.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildViewsChart(
    BuildContext context,
    WidgetRef ref,
    String sellerId,
    AsyncValue<List<ProductModel>> productsAsync,
  ) {
    return productsAsync.when(
      loading: () => Container(
        height: 200,
        decoration: BoxDecoration(
          color: context.altSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => StreamErrorView.compact(
        error: error,
        onRetry: () => ref.invalidate(productsBySellerProvider(sellerId)),
      ),
      data: (products) {
        final topByViews = [...products]
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
        final docs = topByViews.take(6).toList();

        if (docs.isEmpty) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: context.altSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('אין עדיין נתוני צפיות')),
          );
        }

        int maxViews = 1;
        for (final product in docs) {
          if (product.viewCount > maxViews) maxViews = product.viewCount;
        }

        return Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: context.altSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: docs.map((product) {
              final views = product.viewCount;
              final fraction = (views / maxViews).clamp(0.0, 1.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        views.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: (fraction * 120).clamp(4.0, 120.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTopProducts(
    BuildContext context,
    WidgetRef ref,
    String sellerId,
    AsyncValue<List<ProductModel>> productsAsync,
  ) {
    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StreamErrorView.compact(
        error: error,
        onRetry: () => ref.invalidate(productsBySellerProvider(sellerId)),
      ),
      data: (products) {
        final topByViews = [...products]
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
        final top5 = topByViews.take(5).toList();

        if (top5.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.altSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('אין מוצרים עדיין')),
          );
        }

        return Column(
          children: top5.map((product) {
            return _TopProductTile(
              title: product.title,
              views: product.viewCount,
              likes: product.likeCount,
            );
          }).toList(),
        );
      },
    );
  }
}

class _SummaryRowPlaceholder extends StatelessWidget {
  const _SummaryRowPlaceholder();

  @override
  Widget build(BuildContext context) {
    Widget tile() => Expanded(
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: context.altSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
    return Row(
      children: [
        tile(),
        const SizedBox(width: 12),
        tile(),
        const SizedBox(width: 12),
        tile(),
        const SizedBox(width: 12),
        tile(),
      ],
    );
  }
}

class _SalesAndRevenueSection extends ConsumerWidget {
  final String sellerId;

  const _SalesAndRevenueSection({required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(sellerOrdersProvider(sellerId));

    return ordersAsync.when(
      loading: () => const _RevenueRowPlaceholder(),
      error: (error, _) => StreamErrorView.compact(
        error: error,
        onRetry: () => ref.invalidate(sellerOrdersProvider(sellerId)),
      ),
      data: (orders) => _buildContent(context, orders),
    );
  }

  Widget _buildContent(BuildContext context, List<OrderModel> orders) {
    final summary = SellerRevenue.summarize(orders);
    final hasRevenue = summary.realizedCount > 0;
    final atQueryLimit =
        orders.length == OrderRepository.sellerOrdersQueryLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _RevenueTile(
                icon: Icons.check_circle,
                color: context.accentCobalt,
                value: summary.realizedCount.toString(),
                label: 'מכירות שהושלמו',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RevenueTile(
                icon: Icons.monetization_on,
                color: AppColors.palm,
                value: hasRevenue
                    ? '₪${summary.total.toStringAsFixed(0)}'
                    : '—',
                label: 'הכנסות ממכירות',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RevenueTile(
                icon: Icons.hourglass_top,
                color: AppColors.sunDeep,
                value: summary.inProgressCount.toString(),
                label: 'בתהליך',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasRevenue)
          Text(
            'עוד לא הושלמו מכירות',
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
        if (atQueryLimit)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'מבוסס על ${OrderRepository.sellerOrdersQueryLimit} ההזמנות האחרונות',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _RevenueTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _RevenueTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.altSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RevenueRowPlaceholder extends StatelessWidget {
  const _RevenueRowPlaceholder();

  @override
  Widget build(BuildContext context) {
    Widget tile() => Expanded(
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: context.altSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
    return Row(
      children: [
        tile(),
        const SizedBox(width: 12),
        tile(),
        const SizedBox(width: 12),
        tile(),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TopProductTile extends StatelessWidget {
  final String title;
  final int views;
  final int likes;

  const _TopProductTile({
    required this.title,
    required this.views,
    required this.likes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Icon(Icons.visibility, size: 16, color: context.textSecondary),
              const SizedBox(width: 4),
              Text(views.toString()),
            ],
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              const Icon(Icons.favorite, size: 16, color: AppColors.coral),
              const SizedBox(width: 4),
              Text(likes.toString()),
            ],
          ),
        ],
      ),
    );
  }
}
