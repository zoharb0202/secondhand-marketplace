import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/models/availability_window.dart';
import '../../../../shared/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/data/services/opening_hours_service.dart';
import '../../../profile/presentation/pages/addresses_page.dart';

String _catalogCategoryIdForLegacy(ProductCategory category) {
  final id = switch (category) {
    ProductCategory.vehicles => 'vehicles',
    ProductCategory.realEstate => 'real_estate',
    ProductCategory.electronics => 'electronics',
    ProductCategory.fashion => 'fashion',
    ProductCategory.homeGarden => 'home_garden',
    ProductCategory.sports => 'sports',
    ProductCategory.babyKids => 'kids',
    ProductCategory.animalsSupplies => 'pets',
    ProductCategory.officeSupplies => 'other',
    ProductCategory.services => 'services',
    ProductCategory.jobs => 'jobs',
    ProductCategory.other => 'other',
  };
  return Categories.findById(id) != null ? id : 'other';
}

class BulkUploadPage extends ConsumerStatefulWidget {
  const BulkUploadPage({super.key});

  @override
  ConsumerState<BulkUploadPage> createState() => _BulkUploadPageState();
}

class _BulkUploadPageState extends ConsumerState<BulkUploadPage> {
  final List<_ProductDraft> _products = [];
  bool _isUploading = false;
  int _uploadedCount = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('יש להתחבר')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('העלאה מרובה'),
        actions: [
          if (_products.isNotEmpty)
            TextButton.icon(
              onPressed: _isUploading ? null : () => _uploadAll(user.uid),
              icon: const Icon(Icons.cloud_upload),
              label: Text('העלה ${_products.length}'),
            ),
        ],
      ),
      body: _products.isEmpty ? _buildEmptyState() : _buildProductList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('הוסף מוצר'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'העלאה מרובה של מוצרים',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'הוסף מספר מוצרים והעלה אותם בבת אחת',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add),
            label: const Text('הוסף מוצר ראשון'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Column(
      children: [
        if (_isUploading)
          LinearProgressIndicator(value: _uploadedCount / _products.length),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return _ProductDraftCard(
                product: product,
                index: index + 1,
                onEdit: () => _editProduct(index),
                onDelete: () {
                  setState(() {
                    _products.removeAt(index);
                  });
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_products.length} מוצרים',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'סה"כ: ₪${_products.fold(0.0, (sum, p) => sum + p.price).toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMissingAddressDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('נדרשת כתובת איסוף'),
        content: const Text(
          'כדי לפרסם מוצרים יש להוסיף לפחות כתובת אחת שממנה ניתן לאסוף אותם.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressesPage()),
              );
            },
            child: const Text('הוסף כתובת'),
          ),
        ],
      ),
    );
  }

  void _addProduct() {
    _showProductDialog(null, null);
  }

  void _editProduct(int index) {
    _showProductDialog(_products[index], index);
  }

  void _showProductDialog(_ProductDraft? existing, int? index) {
    final titleController = TextEditingController(text: existing?.title);
    final descController = TextEditingController(text: existing?.description);
    final priceController = TextEditingController(
      text: existing?.price.toString() ?? '',
    );
    final cityController = TextEditingController(text: existing?.city);
    ProductCategory category = existing?.category ?? ProductCategory.other;
    ProductCondition condition = existing?.condition ?? ProductCondition.good;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'מוצר חדש' : 'ערוך מוצר'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'שם המוצר *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'תיאור',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'מחיר *',
                    prefixText: '₪ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'עיר *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProductCategory>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'קטגוריה',
                    border: OutlineInputBorder(),
                  ),
                  items: ProductCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      category = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProductCondition>(
                  value: condition,
                  decoration: const InputDecoration(
                    labelText: 'מצב',
                    border: OutlineInputBorder(),
                  ),
                  items: ProductCondition.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      condition = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final price = double.tryParse(priceController.text) ?? 0;
                final city = cityController.text.trim();
                final description = descController.text.trim();

                if (title.isEmpty || price <= 0 || city.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('יש למלא שדות חובה')),
                  );
                  return;
                }
                if (category == ProductCategory.other) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('נא לבחור קטגוריה')),
                  );
                  return;
                }
                if (description.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('נא להזין תיאור')),
                  );
                  return;
                }

                final draft = _ProductDraft(
                  title: title,
                  description: description,
                  price: price,
                  city: city,
                  category: category,
                  condition: condition,
                );

                setState(() {
                  if (index != null) {
                    _products[index] = draft;
                  } else {
                    _products.add(draft);
                  }
                });

                Navigator.pop(context);
              },
              child: Text(existing == null ? 'הוסף' : 'שמור'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAll(String userId) async {
    final SavedAddress pickupAddress;
    try {
      final addresses = await ref.read(savedAddressesProvider(userId).future);
      if (addresses.isEmpty) {
        if (mounted) _showMissingAddressDialog();
        return;
      }
      pickupAddress = addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => addresses.first,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה בטעינת כתובת איסוף: $e')));
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
    });

    final String? pickupGeohash = ProductModel.geohashForLocation(
      pickupAddress.location,
    );

    List<Map<String, dynamic>>? sellerHoursMirror;
    try {
      sellerHoursMirror = (await OpeningHoursService().loadFor(
        userId,
      )).map((w) => w.toMap()).toList();
    } catch (_) {
      sellerHoursMirror = null;
    }

    try {
      for (final product in _products) {
        await FirebaseFirestore.instance.collection('products').add({
          'sellerId': userId,
          'title': product.title,
          'description': product.description,
          'price': product.price,
          'city': product.city,
          'category': product.category.name,
          'categoryId': _catalogCategoryIdForLegacy(product.category),
          'subCategoryId': null,
          'condition': product.condition.name,
          'imageUrls': [],
          'location': pickupAddress.location,
          if (pickupGeohash != null) 'geohash': pickupGeohash,
          'pickupAddressId': pickupAddress.id,
          if (sellerHoursMirror != null)
            kProductSellerHoursField: sellerHoursMirror,
          'isActive': true,
          'isSold': false,
          'likeCount': 0,
          'viewCount': 0,
          'likedByUserIds': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _uploadedCount++;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_products.length} מוצרים הועלו בהצלחה!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _products.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}

class _ProductDraft {
  final String title;
  final String description;
  final double price;
  final String city;
  final ProductCategory category;
  final ProductCondition condition;

  _ProductDraft({
    required this.title,
    required this.description,
    required this.price,
    required this.city,
    required this.category,
    required this.condition,
  });
}

class _ProductDraftCard extends StatelessWidget {
  final _ProductDraft product;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductDraftCard({
    required this.product,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            index.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          product.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₪${product.price.toStringAsFixed(0)} • ${product.city}'),
            Text(
              '${product.category.displayName} • ${product.condition.displayName}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
