import 'package:flutter/material.dart';
import '../../../../core/constants/categories.dart';

class CategorySelector extends StatefulWidget {
  final String? initialCategoryId;
  final String? initialSubCategoryId;

  final Function(Category category, SubCategory? subCategory) onSelected;

  final Function(Category category, SubCategory? subCategory)? onConfirmed;

  const CategorySelector({
    super.key,
    this.initialCategoryId,
    this.initialSubCategoryId,
    required this.onSelected,
    this.onConfirmed,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  Category? _selectedCategory;
  SubCategory? _selectedSubCategory;

  @override
  void initState() {
    super.initState();
    _syncSelectionFromWidget();
  }

  @override
  void didUpdateWidget(CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategoryId != oldWidget.initialCategoryId ||
        widget.initialSubCategoryId != oldWidget.initialSubCategoryId) {
      _syncSelectionFromWidget();
    }
  }

  void _syncSelectionFromWidget() {
    final categoryId = widget.initialCategoryId;
    final subCategoryId = widget.initialSubCategoryId;

    _selectedCategory = categoryId == null
        ? null
        : Categories.findById(categoryId);
    _selectedSubCategory = (_selectedCategory == null || subCategoryId == null)
        ? null
        : Categories.findSubCategory(_selectedCategory!.id, subCategoryId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainCategorySelector(),

        if (_selectedCategory != null) ...[
          const SizedBox(height: 16),
          _buildSubCategorySelector(),
        ],
      ],
    );
  }

  Widget _buildMainCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'בחר קטגוריה:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Categories.all.map((category) {
            final isSelected = _selectedCategory?.id == category.id;
            return _buildCategoryChip(
              label: category.name,
              icon: category.icon,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                  _selectedSubCategory = null;
                });
                widget.onSelected(category, null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubCategorySelector() {
    if (_selectedCategory == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'תת-קטגוריה ב${_selectedCategory!.name} (לא חובה):',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSubCategoryChip(
              label: 'כל ה${_selectedCategory!.name}',
              isSelected: _selectedSubCategory == null,
              onTap: () {
                setState(() => _selectedSubCategory = null);
                widget.onSelected(_selectedCategory!, null);
                (widget.onConfirmed ?? widget.onSelected)(
                  _selectedCategory!,
                  null,
                );
              },
            ),
            ..._selectedCategory!.subCategories.map((subCategory) {
              final isSelected = _selectedSubCategory?.id == subCategory.id;
              return _buildSubCategoryChip(
                label: subCategory.name,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedSubCategory = subCategory;
                  });
                  widget.onSelected(_selectedCategory!, subCategory);
                  (widget.onConfirmed ?? widget.onSelected)(
                    _selectedCategory!,
                    subCategory,
                  );
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}

class CategorySelectorDialog extends StatelessWidget {
  final String? initialCategoryId;
  final String? initialSubCategoryId;

  const CategorySelectorDialog({
    super.key,
    this.initialCategoryId,
    this.initialSubCategoryId,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'בחירת קטגוריה',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: CategorySelector(
                    initialCategoryId: initialCategoryId,
                    initialSubCategoryId: initialSubCategoryId,
                    onSelected: (category, subCategory) {},
                    onConfirmed: (category, subCategory) {
                      Navigator.pop(context, {
                        'category': category,
                        'subCategory': subCategory,
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    String? initialCategoryId,
    String? initialSubCategoryId,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CategorySelectorDialog(
        initialCategoryId: initialCategoryId,
        initialSubCategoryId: initialSubCategoryId,
      ),
    );
  }
}
