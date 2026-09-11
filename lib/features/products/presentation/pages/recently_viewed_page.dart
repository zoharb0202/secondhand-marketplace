import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/product_model.dart';
import 'product_detail_page.dart';

final recentlyViewedProvider = FutureProvider<List<ProductModel>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final viewedIds = prefs.getStringList('recently_viewed') ?? [];

  if (viewedIds.isEmpty) return [];

  final products = <ProductModel>[];
  for (final id in viewedIds.take(20)) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(id)
          .get();
      if (doc.exists) {
        products.add(ProductModel.fromFirestore(doc));
      }
    } catch (_) {}
  }

  return products;
});

class RecentlyViewedService {
  static Future<void> addProduct(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final viewed = prefs.getStringList('recently_viewed') ?? [];

    viewed.remove(productId);
    viewed.insert(0, productId);
    if (viewed.length > 50) {
      viewed.removeRange(50, viewed.length);
    }

    await prefs.setStringList('recently_viewed', viewed);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recently_viewed');
  }
}

class RecentlyViewedPage extends ConsumerWidget {
  const RecentlyViewedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentlyViewedAsync = ref.watch(recentlyViewedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('נצפו לאחרונה'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('נקה היסטוריה'),
                  content: const Text('האם למחוק את כל ההיסטוריה?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ביטול'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('מחק'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await RecentlyViewedService.clearHistory();
                ref.invalidate(recentlyViewedProvider);
              }
            },
          ),
        ],
      ),
      body: recentlyViewedAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'אין מוצרים שנצפו',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'מוצרים שתצפה בהם יופיעו כאן',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _RecentProductCard(
                product: product,
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
          title: 'לא הצלחנו לטעון את הנצפים לאחרונה',
          onRetry: () => ref.invalidate(recentlyViewedProvider),
        ),
      ),
    );
  }
}

class _RecentProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _RecentProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.cover,
                          memCacheWidth: 500,
                          placeholder: (context, url) =>
                              Container(color: AppColors.surfaceVariant),
                          errorWidget: (context, url, error) {
                            return Container(
                              color: AppColors.surfaceVariant,
                              child: const Icon(Icons.image_not_supported),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.image),
                        ),
                  if (product.isSold)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Text(
                            'נמכר',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₪${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
