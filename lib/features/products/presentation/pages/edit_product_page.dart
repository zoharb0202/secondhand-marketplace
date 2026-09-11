import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/product_model.dart';
import '../providers/product_provider.dart';
import '../widgets/category_selector.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/pages/addresses_page.dart';
import '../../../search/data/services/ai_search_service.dart';

ProductCategory _legacyCategoryFor(String categoryId) {
  switch (categoryId) {
    case 'fashion':
    case 'fashion_beauty':
    case 'fashionBeauty':
      return ProductCategory.fashion;
    case 'electronics':
      return ProductCategory.electronics;
    case 'vehicles':
      return ProductCategory.vehicles;
    case 'real_estate':
    case 'realEstate':
      return ProductCategory.realEstate;
    case 'furniture':
    case 'home_garden':
    case 'homeGarden':
      return ProductCategory.homeGarden;
    case 'sports':
      return ProductCategory.sports;
    case 'toys':
    case 'kids':
    case 'babyKids':
      return ProductCategory.babyKids;
    case 'pets':
    case 'animalsSupplies':
      return ProductCategory.animalsSupplies;
    case 'services':
      return ProductCategory.services;
    case 'jobs':
      return ProductCategory.jobs;
    default:
      return ProductCategory.other;
  }
}

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

const Map<String, String> _kCatalogToLegacySubCategory = {
  'smartphones': 'mobilePhones',
  'tv_audio': 'tvs',
  'gaming': 'consoles',
  'shoes': 'sneakers',
  'men_clothing': 'menClothing',
  'women_clothing': 'womenClothing',
  'kids_clothing': 'kidsClothing',
};

String? _legacySubCategoryFor(String? catalogSubCategoryId) {
  if (catalogSubCategoryId == null) return null;
  return _kCatalogToLegacySubCategory[catalogSubCategoryId] ??
      catalogSubCategoryId;
}

class EditProductPage extends ConsumerStatefulWidget {
  final ProductModel product;

  const EditProductPage({super.key, required this.product});

  @override
  ConsumerState<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends ConsumerState<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  late ProductCategory _selectedCategory;

  late String _selectedCategoryId;
  String? _selectedSubCategoryId;
  late final String _initialCategoryId;
  late final String? _initialSubCategoryId;

  late ProductCondition _selectedCondition;

  SavedAddress? _selectedPickupAddress;

  static const int _kMinStockQuantity = 2;
  static const int _kMaxStockQuantity = 99;
  late bool _hasMultipleUnits;
  late final TextEditingController _stockController;

  bool _isLoading = false;
  bool _isEnhancingDescription = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.product.title);
    _descriptionController = TextEditingController(
      text: widget.product.description,
    );
    _priceController = TextEditingController(
      text: widget.product.price.toStringAsFixed(0),
    );

    _selectedCategory = widget.product.category;

    final storedCategoryId = widget.product.categoryId;
    if (storedCategoryId != null &&
        Categories.findById(storedCategoryId) != null &&
        _legacyCategoryFor(storedCategoryId) == widget.product.category) {
      _selectedCategoryId = storedCategoryId;
    } else {
      _selectedCategoryId = _catalogCategoryIdForLegacy(
        widget.product.category,
      );
    }

    final storedSubCategoryId = widget.product.subCategoryId;
    if (storedSubCategoryId != null &&
        Categories.findSubCategory(_selectedCategoryId, storedSubCategoryId) !=
            null) {
      _selectedSubCategoryId = storedSubCategoryId;
    } else {
      final legacySub = widget.product.subcategory;
      String? reversed = legacySub;
      if (reversed != null) {
        for (final entry in _kCatalogToLegacySubCategory.entries) {
          if (entry.value == legacySub) {
            reversed = entry.key;
            break;
          }
        }
        if (Categories.findSubCategory(_selectedCategoryId, reversed!) ==
            null) {
          reversed = null;
        }
      }
      _selectedSubCategoryId = reversed;
    }
    _initialCategoryId = _selectedCategoryId;
    _initialSubCategoryId = _selectedSubCategoryId;

    _selectedCondition = widget.product.condition;

    _hasMultipleUnits = widget.product.hasStock;
    _stockController = TextEditingController(
      text: (widget.product.stockRemaining ?? widget.product.stockTotal ?? 2)
          .toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('עריכת מוצר'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProduct,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('שמור'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.product.imageUrls.isNotEmpty) ...[
              Text(
                'תמונות נוכחיות',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.product.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.product.imageUrls[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          placeholder: (context, url) => Container(
                            width: 100,
                            height: 100,
                            color: AppColors.surfaceVariant,
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 100,
                            height: 100,
                            color: AppColors.surfaceVariant,
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'כותרת',
                hintText: 'שם המוצר',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'נא להזין כותרת';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'תיאור',
                hintText: 'תאר את המוצר',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'נא להזין תיאור';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isEnhancingDescription ? null : _enhanceDescription,
                icon: _isEnhancingDescription
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _isEnhancingDescription ? 'משפר תיאור...' : 'שפר תיאור עם AI',
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'מחיר',
                suffixText: '₪',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'נא להזין מחיר';
                }
                if (double.tryParse(value) == null) {
                  return 'מחיר לא תקין';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('יש לי יותר מפריט אחד מהמוצר הזה'),
              subtitle: const Text(
                'נעדכן את הכמות שנותרה אוטומטית אחרי כל מכירה',
              ),
              value: _hasMultipleUnits,
              onChanged: (value) {
                setState(() {
                  _hasMultipleUnits = value ?? false;
                });
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _hasMultipleUnits
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: _stockController,
                        decoration: const InputDecoration(
                          labelText: 'כמות במלאי *',
                          hintText: '2',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (!_hasMultipleUnits) return null;
                          final qty = int.tryParse((value ?? '').trim());
                          if (qty == null ||
                              qty < _kMinStockQuantity ||
                              qty > _kMaxStockQuantity) {
                            return 'נא להזין כמות בין 2 ל-99';
                          }
                          return null;
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            Text(
              'כתובת איסוף',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildPickupAddressSection(),
            const SizedBox(height: 24),

            Text(
              'קטגוריה',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CategorySelector(
                initialCategoryId: _selectedCategoryId,
                initialSubCategoryId: _selectedSubCategoryId,
                onSelected: (category, subCategory) {
                  setState(() {
                    _selectedCategoryId = category.id;
                    _selectedSubCategoryId = subCategory?.id;
                    _selectedCategory = _legacyCategoryFor(category.id);
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'מצב המוצר',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ProductCondition.values.map((condition) {
                final isSelected = _selectedCondition == condition;
                return ChoiceChip(
                  label: Text(condition.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCondition = condition;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _showDeleteConfirmation,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              label: const Text(
                'מחק מוצר',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupAddressSection() {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return const SizedBox.shrink();

    final addressesAsync = ref.watch(savedAddressesProvider(user.id));

    return addressesAsync.when(
      data: (addresses) {
        if (addresses.isEmpty) {
          _selectedPickupAddress = null;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_off_outlined, color: AppColors.error),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'לא ניתן לעדכן מוצר ללא כתובת איסוף. הוסף כתובת כדי להמשיך.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddressesPage()),
                    );
                  },
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('הוסף כתובת איסוף'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        if (_selectedPickupAddress != null &&
            !addresses.any((a) => a.id == _selectedPickupAddress!.id)) {
          _selectedPickupAddress = null;
        }
        _selectedPickupAddress ??= addresses.firstWhere(
          (a) => a.id == widget.product.pickupAddressId,
          orElse: () => addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => addresses.first,
          ),
        );

        return DropdownButtonFormField<String>(
          initialValue: _selectedPickupAddress!.id,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: addresses
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.label} — ${a.fullAddress}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedPickupAddress = addresses.firstWhere(
                (a) => a.id == value,
              );
            });
          },
          validator: (_) =>
              _selectedPickupAddress == null ? 'נא לבחור כתובת איסוף' : null,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => StreamErrorView.compact(
        error: error,
        title: 'לא הצלחנו לטעון את כתובות האיסוף',
        onRetry: () => ref.invalidate(savedAddressesProvider(user.id)),
      ),
    );
  }

  Future<void> _enhanceDescription() async {
    if (_descriptionController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isEnhancingDescription = true;
    });

    try {
      final aiService = AISearchService();

      final enhancedDescription = await aiService.enhanceDescription(
        description: _descriptionController.text.trim(),
        title: _titleController.text.trim(),
        category: _selectedCategory.name,
        condition: _selectedCondition.name,
      );

      if (mounted) {
        final accept = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary),
                SizedBox(width: 8),
                Text('תיאור משופר'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'התיאור המקורי:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _descriptionController.text,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'התיאור המשופר:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    enhancedDescription,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ביטול'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('השתמש בתיאור המשופר'),
              ),
            ],
          ),
        );

        if (accept == true && mounted) {
          setState(() {
            _descriptionController.text = enhancedDescription;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error enhancing description: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשיפור התיאור: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEnhancingDescription = false;
        });
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final pickupAddress = _selectedPickupAddress;
    if (pickupAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('נא לבחור כתובת איסוף'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{
        'title': _titleController.text,
        'description': _descriptionController.text,
        'price': double.parse(_priceController.text),
        'location': pickupAddress.location,
        'city': pickupAddress.city,
        'pickupAddressId': pickupAddress.id,
        'categoryId': _selectedCategoryId,
        'subCategoryId': _selectedSubCategoryId,
        'category': _selectedCategory.name,
        'condition': _selectedCondition.name,
      };

      final legacySubcategory = _legacySubCategoryFor(_selectedSubCategoryId);
      if (legacySubcategory != null) {
        updates['subcategory'] = legacySubcategory;
      } else if (_selectedCategoryId != _initialCategoryId ||
          _initialSubCategoryId != null) {
        updates['subcategory'] = null;
      }

      if (_hasMultipleUnits) {
        final qty = int.tryParse(_stockController.text.trim());
        if (qty != null) {
          updates['stockTotal'] = qty;
          updates['stockRemaining'] = qty;
          if (qty > 0) {
            updates['isSold'] = false;
            updates['isActive'] = true;
          }
        }
      } else if (widget.product.hasStock) {
        updates['stockTotal'] = FieldValue.delete();
        updates['stockRemaining'] = FieldValue.delete();
      }

      await ref
          .read(productControllerProvider.notifier)
          .updateProduct(widget.product.id, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('המוצר עודכן בהצלחה'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון המוצר: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת מוצר'),
        content: const Text(
          'האם אתה בטוח שברצונך למחוק את המוצר? פעולה זו לא ניתנת לביטול.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                await ref
                    .read(productControllerProvider.notifier)
                    .deleteProduct(widget.product.id);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('המוצר נמחק בהצלחה'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('שגיאה במחיקת המוצר: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
  }
}
