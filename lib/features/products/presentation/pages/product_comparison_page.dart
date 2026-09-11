import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/product_model.dart';
import 'product_detail_page.dart';

final comparisonListProvider = StateProvider<List<ProductModel>>((ref) => []);

class ProductComparisonPage extends ConsumerWidget {
  const ProductComparisonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(comparisonListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('השוואת מוצרים'),
        actions: [
          if (products.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                ref.read(comparisonListProvider.notifier).state = [];
              },
              tooltip: 'נקה הכל',
            ),
        ],
      ),
      body: products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.compare_arrows, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'אין מוצרים להשוואה',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'הוסף מוצרים מעמוד המוצר',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 16,
                  columns: [
                    const DataColumn(label: Text('פרט')),
                    ...products.map(
                      (p) => DataColumn(
                        label: SizedBox(
                          width: 120,
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: p.imageUrls.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: p.imageUrls.first,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 160,
                                            placeholder: (context, url) =>
                                                Container(
                                                  width: 80,
                                                  height: 80,
                                                  color: Colors.grey[300],
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.image,
                                                      ),
                                                    ),
                                          )
                                        : Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image),
                                          ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        final list = ref.read(
                                          comparisonListProvider,
                                        );
                                        ref
                                            .read(
                                              comparisonListProvider.notifier,
                                            )
                                            .state = list
                                            .where((item) => item.id != p.id)
                                            .toList();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    _buildRow(
                      'מחיר',
                      products
                          .map((p) => '₪${p.price.toStringAsFixed(0)}')
                          .toList(),
                    ),
                    _buildRow(
                      'מצב',
                      products.map((p) => p.condition.displayName).toList(),
                    ),
                    _buildRow('עיר', products.map((p) => p.city).toList()),
                    _buildRow(
                      'קטגוריה',
                      products.map((p) => p.category.displayName).toList(),
                    ),
                    _buildRow(
                      'לייקים',
                      products.map((p) => p.likeCount.toString()).toList(),
                    ),
                    DataRow(
                      cells: [
                        const DataCell(Text('פעולות')),
                        ...products.map(
                          (p) => DataCell(
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProductDetailPage(productId: p.id),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: const Text(
                                'צפה',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: products.length >= 2
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_buildBestValue(products)],
              ),
            )
          : null,
    );
  }

  DataRow _buildRow(String label, List<String> values) {
    return DataRow(
      cells: [
        DataCell(
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        ...values.map(
          (v) => DataCell(
            SizedBox(
              width: 120,
              child: Text(
                v,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBestValue(List<ProductModel> products) {
    if (products.isEmpty) return const SizedBox.shrink();

    final cheapest = products.reduce((a, b) => a.price < b.price ? a : b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.thumb_up, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'המחיר הטוב ביותר: ${cheapest.title} (₪${cheapest.price.toStringAsFixed(0)})',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddToComparisonButton extends ConsumerWidget {
  final ProductModel product;

  const AddToComparisonButton({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonList = ref.watch(comparisonListProvider);
    final isInComparison = comparisonList.any((p) => p.id == product.id);

    return IconButton(
      icon: Icon(
        isInComparison ? Icons.compare : Icons.compare_arrows,
        color: isInComparison ? AppColors.primary : null,
      ),
      onPressed: () {
        final list = ref.read(comparisonListProvider);
        if (isInComparison) {
          ref.read(comparisonListProvider.notifier).state = list
              .where((p) => p.id != product.id)
              .toList();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('הוסר מההשוואה')));
        } else {
          if (list.length >= 4) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ניתן להשוות עד 4 מוצרים')),
            );
            return;
          }
          ref.read(comparisonListProvider.notifier).state = [...list, product];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('נוסף להשוואה (${list.length + 1}/4)'),
              action: SnackBarAction(
                label: 'השווה',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductComparisonPage(),
                    ),
                  );
                },
              ),
            ),
          );
        }
      },
      tooltip: isInComparison ? 'הסר מהשוואה' : 'הוסף להשוואה',
    );
  }
}
