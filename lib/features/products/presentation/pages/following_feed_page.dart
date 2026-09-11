import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import 'product_detail_page.dart';

class FollowingFeedPage extends ConsumerWidget {
  const FollowingFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(followedSellersFeedProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('מוכרים שאני עוקב')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(followedSellersRawFeedProvider),
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 120),
              StreamErrorView(
                error: error,
                title: 'לא הצלחנו לטעון את הפיד',
                onRetry: () => ref.invalidate(followedSellersRawFeedProvider),
              ),
            ],
          ),
          data: (products) {
            if (products.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'עדיין אינך עוקב אחרי מוכרים',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'עקוב אחרי מוכרים כדי לראות כאן את המוצרים החדשים שלהם',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final isLiked =
                    currentUser != null &&
                    product.likedByUserIds.contains(currentUser.id);
                return ProductCard(
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
