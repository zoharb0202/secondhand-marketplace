import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/services/location_service.dart';
import '../providers/product_provider.dart';
import 'category_selector.dart';

class AdvancedFilterSheet extends ConsumerStatefulWidget {
  final ProductFilters initialFilters;

  const AdvancedFilterSheet({super.key, required this.initialFilters});

  static Future<ProductFilters?> show(
    BuildContext context,
    ProductFilters currentFilters,
  ) {
    return showModalBottomSheet<ProductFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdvancedFilterSheet(initialFilters: currentFilters),
    );
  }

  @override
  ConsumerState<AdvancedFilterSheet> createState() =>
      _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends ConsumerState<AdvancedFilterSheet> {
  late ProductFilters _filters;
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    if (_filters.minPrice != null) {
      _minPriceController.text = _filters.minPrice!.toStringAsFixed(0);
    }
    if (_filters.maxPrice != null) {
      _maxPriceController.text = _filters.maxPrice!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context, _filters),
                      ),
                      const Expanded(
                        child: Text(
                          'סינון וחיפוש',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filters = _filters.clear();
                            _minPriceController.clear();
                            _maxPriceController.clear();
                          });
                        },
                        child: const Text('נקה הכל'),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSection('מיון', Icons.sort, _buildSortFilter()),

                      const SizedBox(height: 20),

                      _buildSection(
                        'קטגוריה',
                        Icons.category,
                        _buildCategoryFilter(),
                      ),

                      const SizedBox(height: 20),

                      _buildSection(
                        'טווח מחירים',
                        Icons.attach_money,
                        _buildPriceFilter(),
                      ),

                      const SizedBox(height: 20),

                      _buildSection(
                        'מצב המוצר',
                        Icons.verified_outlined,
                        _buildConditionFilter(),
                      ),

                      const SizedBox(height: 20),

                      _buildSection(
                        'מרחק מקסימלי',
                        Icons.location_on,
                        _buildDistanceFilter(),
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        if (_filters.hasActiveFilters)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_filters.activeFilterCount} סינונים',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, _filters),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'הצג תוצאות',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final selectedCategory = _filters.categoryId != null
        ? Categories.findById(_filters.categoryId!)
        : null;
    final selectedSub =
        (selectedCategory != null && _filters.subCategoryId != null)
        ? Categories.findSubCategory(
            _filters.categoryId!,
            _filters.subCategoryId!,
          )
        : null;
    final categoryLabel = selectedCategory == null
        ? 'כל הקטגוריות'
        : (selectedSub != null
              ? '${selectedCategory.name} › ${selectedSub.name}'
              : 'כל ה${selectedCategory.name}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final result = await CategorySelectorDialog.show(
              context,
              initialCategoryId: _filters.categoryId,
              initialSubCategoryId: _filters.subCategoryId,
            );

            if (result != null && mounted) {
              setState(() {
                _filters = _filters.copyWith(
                  categoryId: result['category'].id,
                  subCategoryId: result['subCategory']?.id,
                );
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    categoryLabel,
                    style: TextStyle(
                      color: selectedCategory != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        if (_filters.categoryId != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(categoryLabel),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _filters = _filters.copyWith(
                      categoryId: null,
                      subCategoryId: null,
                    );
                  });
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _minPriceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'מינימום',
              prefixText: '₪',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _filters = _filters.copyWith(minPrice: double.tryParse(value));
              });
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('-'),
        ),
        Expanded(
          child: TextField(
            controller: _maxPriceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'מקסימום',
              prefixText: '₪',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _filters = _filters.copyWith(maxPrice: double.tryParse(value));
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConditionFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ProductCondition.values.map((condition) {
        final isSelected = _filters.condition == condition;
        return FilterChip(
          label: Text(condition.displayName),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _filters = _filters.copyWith(
                condition: selected ? condition : null,
              );
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSortFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SortOption.values.map((option) {
        final isSelected = _filters.sortBy == option;
        return ChoiceChip(
          label: Text(option.displayName),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _filters = _filters.copyWith(sortBy: option);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildDistanceFilter() {
    final enabled = _filters.maxDistance != null;
    final userLoc = ref.watch(userGeoPointProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('סינון לפי מרחק'),
          value: enabled,
          onChanged: (value) {
            setState(() {
              _filters = _filters.copyWith(maxDistance: value ? 25.0 : null);
            });
          },
        ),
        if (enabled) ...[
          Slider(
            value: _filters.maxDistance!,
            min: 1,
            max: 100,
            divisions: 20,
            label: '${_filters.maxDistance!.toStringAsFixed(0)} ק"מ',
            onChanged: (value) {
              setState(() {
                _filters = _filters.copyWith(maxDistance: value);
              });
            },
          ),
          Text(
            'עד ${_filters.maxDistance!.toStringAsFixed(0)} ק"מ',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (userLoc == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'אפשר גישה למיקום כדי לסנן לפי מרחק',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await LocationService().checkAndRequestPermission();
                    ref.invalidate(userGeoPointProvider);
                  },
                  child: const Text('אפשר גישה'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
