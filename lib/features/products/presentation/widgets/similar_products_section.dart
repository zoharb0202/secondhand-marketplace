import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/image_variants.dart';
import '../../../../shared/models/product_similarity.dart';
import '../providers/product_provider.dart';
import '../pages/product_detail_page.dart';

class SimilarProductsSection extends ConsumerWidget {
  final ProductModel currentProduct;

  const SimilarProductsSection({super.key, required this.currentProduct});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kDebugMode) {
      print(
        '🔍 [SIMILAR_PRODUCTS_SECTION] Building for category: ${currentProduct.category.name}',
      );
    }

    final similarProductsAsync = ref.watch(
      similarProductsProvider(SimilarityFeatures.fromProduct(currentProduct)),
    );

    return similarProductsAsync.when(
      data: (products) {
        if (kDebugMode) {
          print(
            '✅ [SIMILAR_PRODUCTS_SECTION] Received ${products.length} products',
          );
        }

        if (products.isEmpty) {
          if (kDebugMode) {
            print(
              '⚠️ [SIMILAR_PRODUCTS_SECTION] No similar products found, hiding section',
            );
          }
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'מוצרים דומים',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    products.length == 1
                        ? 'מוצר אחד'
                        : '${products.length} מוצרים',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final scored = products[index];
                  return _SimilarProductCard(
                    product: scored.product,
                    fromSameSeller: scored.isFromSameSeller,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () {
        if (kDebugMode) print('⏳ [SIMILAR_PRODUCTS_SECTION] Loading...');
        return const SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        if (kDebugMode) print('❌ [SIMILAR_PRODUCTS_SECTION] Error: $error');
        return const SizedBox.shrink();
      },
    );
  }
}

class _SimilarProductCard extends StatelessWidget {
  final ProductModel product;

  final bool fromSameSeller;

  const _SimilarProductCard({
    required this.product,
    this.fromSameSeller = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentCobalt;

    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(productId: product.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: fromSameSeller
                ? BorderSide(color: accent, width: 2)
                : BorderSide.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: product.thumbnailUrl ?? '',
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: kCompactThumbDecodeWidth,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.condition.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  if (fromSameSeller)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront,
                              size: 11,
                              color: AppColors.textOnPrimary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'מהמוכר הזה',
                              style: TextStyle(
                                color: AppColors.textOnPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (product.isSold)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'נמכר',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const Spacer(),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₪${product.price.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),

                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: context.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                product.city,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.textSecondary,
                                      fontSize: 10,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
