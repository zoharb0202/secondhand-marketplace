import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/constants/manufacturers.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/services/ai_search_service.dart';
import '../../../../core/services/interaction_tracker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/product_detail_page.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../products/presentation/widgets/advanced_filter_sheet.dart';
import '../../../products/presentation/widgets/product_card.dart';
import 'visual_search_page.dart';

class AISearchPage extends ConsumerStatefulWidget {
  const AISearchPage({super.key});

  @override
  ConsumerState<AISearchPage> createState() => _AISearchPageState();
}

class _AISearchPageState extends ConsumerState<AISearchPage> {
  final AISearchService _aiService = AISearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<ProductModel> _searchResults = [];

  String? _searchId;

  SearchParameters? _parsedParams;
  bool _isSearching = false;
  bool _showResults = false;
  String? _errorMessage;
  ProductFilters _filters = ProductFilters();

  String _submittedQuery = '';

  bool _brandDeltaChecked = false;

  bool _submittingBrand = false;

  String? _brandSubmitMessage;

  String? _brandSubmitKey;

  List<ProductModel> _filteredResults() {
    Iterable<ProductModel> results = _searchResults;
    if (_filters.hasActiveFilters) {
      results = results.where((p) {
        if (_filters.categoryId != null &&
            p.categoryId != _filters.categoryId) {
          return false;
        }
        if (_filters.subCategoryId != null &&
            p.subCategoryId != _filters.subCategoryId) {
          return false;
        }
        if (_filters.minPrice != null && p.price < _filters.minPrice!) {
          return false;
        }
        if (_filters.maxPrice != null && p.price > _filters.maxPrice!) {
          return false;
        }
        if (_filters.condition != null && p.condition != _filters.condition) {
          return false;
        }
        return true;
      });
    }

    var list = results.toList();

    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _performAISearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _showResults = false;
        _searchResults = [];
        _searchId = null;
        _parsedParams = null;
        _submittedQuery = '';
        _brandSubmitMessage = null;
        _brandSubmitKey = null;
      });
      return;
    }

    InteractionTracker().track(InteractionType.search, query: query);

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔍 Starting AI search for: $query');
      final result = await _aiService.searchProducts(query: query, limit: 50);

      debugPrint('📦 Got ${result.products.length} products from AI');
      debugPrint('📊 Search params: ${result.searchParams.toJson()}');

      final products = <ProductModel>[];
      for (final data in result.products) {
        try {
          debugPrint('   Parsing product: ${data['title']}');
          products.add(ProductModel.fromMap(data, data['id'] as String));
        } catch (e) {
          debugPrint('   ❌ Error parsing product: $e');
          debugPrint('   Data: $data');
        }
      }

      debugPrint('✅ Successfully parsed ${products.length} products');

      setState(() {
        _searchResults = products;
        _searchId = result.searchId;
        _parsedParams = result.searchParams;
        _showResults = true;
        _isSearching = false;
        _submittedQuery = query;
        _brandSubmitMessage = null;
        _brandSubmitKey = null;
      });

      if (_isBrandCatalogueStaff(ref.read(currentUserProvider).value)) {
        unawaited(_ensureBrandDeltaLoaded());
      }
    } catch (e) {
      debugPrint('❌ AI Search error: $e');
      setState(() {
        _errorMessage = 'שגיאה בחיפוש: ${e.toString()}';
        _isSearching = false;
      });
    }
  }

  Future<void> _showFilters() async {
    final result = await AdvancedFilterSheet.show(context, _filters);
    if (result == null || !mounted) return;

    setState(() => _filters = result);

    if (_submittedQuery.isNotEmpty) return;

    if (!result.hasActiveFilters) {
      setState(() {
        _searchResults = [];
        _searchId = null;
        _parsedParams = null;
        _showResults = false;
        _errorMessage = null;
        _brandSubmitMessage = null;
        _brandSubmitKey = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final products = await ref
          .read(productRepositoryProvider)
          .getProductsStreamWithFilters(result)
          .first;
      if (!mounted) return;
      setState(() {
        _searchResults = products;
        _searchId = null;
        _parsedParams = null;
        _showResults = true;
        _isSearching = false;
        _brandSubmitMessage = null;
        _brandSubmitKey = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'שגיאה בטעינת תוצאות: ${e.toString()}';
        _isSearching = false;
      });
    }
  }

  void _openVisualSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VisualSearchPage()),
    );
  }

  bool _isBrandCatalogueStaff(UserModel? user) =>
      user != null &&
      (user.isAdmin ||
          user.role == UserRole.admin ||
          user.role == UserRole.supportAgent);

  static const _kCategoriesWithoutBrands = {'services', 'jobs', 'other'};

  String? get _brandCatalogueCategoryId {
    final raw = _parsedParams?.category?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (_kCategoriesWithoutBrands.contains(raw)) return null;
    return Categories.findById(raw) == null ? null : raw;
  }

  String? get _unknownBrandForCatalogue {
    final brand = _parsedParams?.brand?.trim();
    final categoryId = _brandCatalogueCategoryId;
    if (brand == null || brand.isEmpty || categoryId == null) return null;
    if (normalizeManufacturerName(brand).length < 2) return null;
    final known = matchManufacturer(
      brand,
      manufacturersFor(categoryId: categoryId),
    );
    return known == null ? brand : null;
  }

  Future<void> _ensureBrandDeltaLoaded() async {
    if (_brandDeltaChecked) return;
    _brandDeltaChecked = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('brand_catalog')
          .doc('index')
          .get();
      if (applyLearnedManufacturers(snapshot.data()) && mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
        'ℹ️ brand_catalog/index unavailable — bundled baseline only: $e',
      );
    }
  }

  String _brandRejectionMessage(String? reason) {
    switch (reason) {
      case 'already_known':
        return 'המותג כבר קיים בקטלוג — לא נדרשת פעולה.';
      case 'rate_limited':
        return 'נשלחו יותר מדי מותגים בשעה האחרונה. נסה שוב מאוחר יותר.';
      case 'unknown_category':
      case 'category_has_no_brands':
        return 'לא ניתן להוסיף מותג לקטגוריה הזו.';
      case 'invalid':
      case 'blocked':
        return 'שם המותג אינו תקין להוספה לקטלוג.';
      default:
        return 'ההצעה לא נקלטה. אפשר להוסיף את המותג ידנית מלוח הבקרה.';
    }
  }

  Future<void> _submitBrandToCatalogue({
    required String brand,
    required String categoryId,
  }) async {
    setState(() {
      _submittingBrand = true;
      _brandSubmitMessage = null;
    });

    String message;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('suggestBrand')
          .call<dynamic>({
            'brandName': brand,
            'categoryId': categoryId,
            if (_parsedParams?.subcategory != null)
              'subCategoryId': _parsedParams!.subcategory,
          })
          .timeout(const Duration(seconds: 15));
      final data = Map<String, dynamic>.from(result.data as Map);
      message = data['accepted'] == true
          ? 'המותג נשלח לבדיקה. אפשר לאשר אותו בלוח הבקרה, בלשונית "קטלוג מותגים".'
          : _brandRejectionMessage(data['reason'] as String?);
    } catch (e) {
      debugPrint('❌ suggestBrand failed: $e');
      message = 'שליחת המותג נכשלה. נסה שוב מאוחר יותר.';
    }

    if (!mounted) return;
    setState(() {
      _submittingBrand = false;
      _brandSubmitMessage = message;
      _brandSubmitKey = '$categoryId::$brand';
    });
  }

  Widget? _buildBrandCatalogueOffer(UserModel? currentUser) {
    if (!_showResults || _isSearching) return null;
    if (!_isBrandCatalogueStaff(currentUser)) return null;

    final brand = _unknownBrandForCatalogue;
    final categoryId = _brandCatalogueCategoryId;
    if (brand == null || categoryId == null) return null;

    final categoryName = Categories.findById(categoryId)?.name ?? categoryId;
    final message = _brandSubmitKey == '$categoryId::$brand'
        ? _brandSubmitMessage
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'לצוות בלבד',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'המותג "$brand" לא קיים בקטלוג המותגים של $categoryName.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (message != null)
            Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _submittingBrand
                    ? null
                    : () => _submitBrandToCatalogue(
                        brand: brand,
                        categoryId: categoryId,
                      ),
                icon: _submittingBrand
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add, size: 18),
                label: const Text('הצע לקטלוג המותגים'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('חיפוש חכם'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _openVisualSearch,
            tooltip: 'חיפוש באמצעות תמונה',
          ),
          IconButton(
            icon: Icon(
              Icons.tune,
              color: _filters.hasActiveFilters ? AppColors.primary : null,
            ),
            onPressed: _showFilters,
            tooltip: 'סינון',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.purple, Colors.blue],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'תאר מה אתה מחפש במילים שלך',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText:
                        'לדוגמה: "אייפון 13 במצב טוב עד 2000 שח מאיזור המרכז"',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _showResults = false;
                                _searchResults = [];
                                _searchId = null;
                                _parsedParams = null;
                                _filters = _filters.clear();
                                _submittedQuery = '';
                                _brandSubmitMessage = null;
                                _brandSubmitKey = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (_) => _performAISearch(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isSearching ? null : _performAISearch,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('חפש עם AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_parsedParams != null && _showResults)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _parsedSummary(_parsedParams!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  String _parsedSummary(SearchParameters params) {
    final parts = <String>[];
    if (params.keywords.isNotEmpty) {
      parts.add('מילות מפתח: ${params.keywords.join(", ")}');
    }
    final categoryId = params.category;
    if (categoryId != null && categoryId.isNotEmpty) {
      parts.add(
        'קטגוריה: ${Categories.findById(categoryId)?.name ?? categoryId}',
      );
    }
    final subCategoryId = params.subcategory;
    if (subCategoryId != null && subCategoryId.isNotEmpty) {
      parts.add(
        'תת-קטגוריה: '
        '${Categories.findSubCategory(categoryId ?? '', subCategoryId)?.name ?? subCategoryId}',
      );
    }
    if (params.minPrice != null && params.maxPrice != null) {
      parts.add('מחיר: ₪${params.minPrice} - ₪${params.maxPrice}');
    } else if (params.minPrice != null) {
      parts.add('מחיר מינימום: ₪${params.minPrice}');
    } else if (params.maxPrice != null) {
      parts.add('מחיר מקסימום: ₪${params.maxPrice}');
    }
    if (params.condition != null) parts.add('מצב: ${params.condition}');
    if (params.city != null) parts.add('מיקום: ${params.city}');
    if (params.brand != null) parts.add('מותג: ${params.brand}');
    if (params.model != null) parts.add('דגם: ${params.model}');
    return parts.join(' • ');
  }

  String _emptyResultHint() {
    if (_searchResults.isNotEmpty) return 'נסה להסיר חלק מהסינונים';
    final brand = _parsedParams?.brand?.trim();
    if (brand != null && brand.isNotEmpty) {
      return 'לא נמצאו מוצרים של "$brand".\nנסה לחפש בלי שם המותג.';
    }
    return 'נסה לשנות את החיפוש או להשתמש במילים אחרות';
  }

  Widget _buildContent() {
    final currentUser = ref.watch(currentUserProvider).value;

    if (!_showResults && !_isSearching) {
      return _buildEmptyState();
    }

    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'מחפש עם AI...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final filteredResults = _filteredResults();

    final brandOffer = _buildBrandCatalogueOffer(currentUser);

    if (filteredResults.isEmpty) {
      return SingleChildScrollView(
        padding: NavBarClearance.pad(
          context,
          base: const EdgeInsets.only(top: 32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              _searchResults.isEmpty
                  ? 'לא נמצאו מוצרים'
                  : 'אין תוצאות תואמות לסינון',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _emptyResultHint(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (brandOffer != null) ...[const SizedBox(height: 24), brandOffer],
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'נמצאו ${filteredResults.length} תוצאות',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        if (brandOffer != null) brandOffer,
        Expanded(
          child: GridView.builder(
            padding: NavBarClearance.pad(
              context,
              base: const EdgeInsets.only(left: 16, right: 16, top: 16),
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredResults.length,
            itemBuilder: (context, index) {
              final product = filteredResults[index];
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
                onTap: () {
                  if (_searchId != null) {
                    unawaited(
                      _aiService.logSearchClick(
                        productId: product.id,
                        searchId: _searchId,
                        rank: index,
                      ),
                    );
                  }
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
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: NavBarClearance.pad(context, base: const EdgeInsets.all(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'חיפוש חכם עם AI',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'תאר במילים שלך מה אתה מחפש',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildExampleChip('אייפון 13 במצב טוב עד 2000 שח'),
            const SizedBox(height: 8),
            _buildExampleChip('בגדי תינוקות מאיזור המרכז'),
            const SizedBox(height: 8),
            _buildExampleChip('מחשב נייד לגיימינג'),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return InkWell(
      onTap: () {
        _searchController.text = text;
        _performAISearch();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
