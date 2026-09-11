import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/product_model.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/product_detail_page.dart';

enum FavoritesSort { newest, priceAsc, priceDesc }

final favoritesSortProvider = StateProvider<FavoritesSort>(
  (ref) => FavoritesSort.newest,
);

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('מועדפים')),
        body: const Center(child: Text('יש להתחבר כדי לראות מועדפים')),
      );
    }

    final productsAsync = ref.watch(likedProductsProvider(user.id));
    final sort = ref.watch(favoritesSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('מועדפים'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              _showSortOptions(context, ref);
            },
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          final favorites = [...products];
          switch (sort) {
            case FavoritesSort.newest:
              favorites.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            case FavoritesSort.priceAsc:
              favorites.sort((a, b) => a.price.compareTo(b.price));
            case FavoritesSort.priceDesc:
              favorites.sort((a, b) => b.price.compareTo(a.price));
          }

          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'אין מוצרים במועדפים',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'לחץ על ❤️ כדי להוסיף מוצרים',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final product = favorites[index];
              return _FavoriteProductCard(
                product: product,
                onRemove: () {
                  ref
                      .read(productControllerProvider.notifier)
                      .toggleLike(product.id, user.id);
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailPage(productId: product.id),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StreamErrorView(
          error: error,
          title: 'לא הצלחנו לטעון את המועדפים',
          onRetry: () => ref.invalidate(likedProductsProvider(user.id)),
        ),
      ),
    );
  }

  void _showSortOptions(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(favoritesSortProvider);
    void select(FavoritesSort value) {
      ref.read(favoritesSortProvider.notifier).state = value;
      Navigator.pop(context);
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('החדשים ביותר'),
            trailing: currentSort == FavoritesSort.newest
                ? const Icon(Icons.check)
                : null,
            onTap: () => select(FavoritesSort.newest),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('מחיר: נמוך לגבוה'),
            trailing: currentSort == FavoritesSort.priceAsc
                ? const Icon(Icons.check)
                : null,
            onTap: () => select(FavoritesSort.priceAsc),
          ),
          ListTile(
            leading: const Icon(Icons.money_off),
            title: const Text('מחיר: גבוה לנמוך'),
            trailing: currentSort == FavoritesSort.priceDesc
                ? const Icon(Icons.check)
                : null,
            onTap: () => select(FavoritesSort.priceDesc),
          ),
        ],
      ),
    );
  }
}

class _FavoriteProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _FavoriteProductCard({
    required this.product,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.imageUrls.isNotEmpty
                      ? Image.network(
                          product.imageUrls.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: AppColors.surfaceVariant,
                              child: const Icon(Icons.image_not_supported),
                            );
                          },
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.image),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₪${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.city,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (product.isSold) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'נמכר',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
