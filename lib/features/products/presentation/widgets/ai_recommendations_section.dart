import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/user_interaction_model.dart';
import '../providers/product_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/recommendation_service.dart';
import '../../../search/data/services/ai_search_service.dart';
import '../pages/product_detail_page.dart';

class AIRecommendationsSection extends ConsumerStatefulWidget {
  const AIRecommendationsSection({super.key});

  @override
  ConsumerState<AIRecommendationsSection> createState() =>
      _AIRecommendationsSectionState();
}

class _AIRecommendationsSectionState
    extends ConsumerState<AIRecommendationsSection> {
  List<ProductModel>? _recommendedProducts;
  Map<String, String> _recommendationReasons = {};
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      final products = ref.read(productsStreamProvider).value;

      if (user == null || products == null || products.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final recommendationService = RecommendationService();
      final interactions = await recommendationService.getUserInteractions(
        user.id,
      );

      final favorites = <ProductSummary>[];
      final searchedTerms = <String>[];

      for (final interaction in interactions) {
        switch (interaction.type) {
          case InteractionType.like:
          case InteractionType.favorite:
            if (favorites.length < 20) {
              try {
                final product = products.firstWhere(
                  (p) => p.id == interaction.productId,
                );
                final summary = ProductSummary(
                  id: product.id,
                  title: product.title,
                  category: product.category.name,
                  subcategory: product.subCategoryId,
                  price: product.price,
                  condition: product.condition.name,
                  brand: product.brand,
                );
                favorites.add(summary);
              } catch (e) {
                continue;
              }
            }
            break;
          case InteractionType.search:
            if (interaction.category != null && searchedTerms.length < 20) {
              searchedTerms.add(interaction.category!);
            }
            break;
          default:
            break;
        }
      }

      final availableProducts = products
          .where((p) => p.sellerId != user.id)
          .take(50)
          .map(
            (p) => ProductSummary(
              id: p.id,
              title: p.title,
              category: p.category.name,
              subcategory: p.subCategoryId,
              price: p.price,
              condition: p.condition.name,
              brand: p.brand,
            ),
          )
          .toList();

      if (availableProducts.isEmpty) {
        if (mounted) {
          setState(() {
            _recommendedProducts = const [];
            _isLoading = false;
          });
        }
        return;
      }

      final userActivity = UserActivity(
        viewed: [],
        searches: searchedTerms,
        favorites: favorites,
        purchased: [],
      );

      final aiService = AISearchService();
      final response = await aiService.getPersonalizedRecommendations(
        userActivity: userActivity,
        availableProducts: availableProducts,
      );

      if (response.recommendations.isEmpty) {
        if (mounted) {
          setState(() {
            _recommendedProducts = const [];
            _isLoading = false;
          });
        }
        return;
      }

      final recommendedProducts = <ProductModel>[];
      final reasons = <String, String>{};

      for (final rec in response.recommendations) {
        try {
          final product = products.firstWhere((p) => p.id == rec.productId);
          recommendedProducts.add(product);
          reasons[product.id] = rec.reason;
        } catch (e) {
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _recommendedProducts = recommendedProducts;
          _recommendationReasons = reasons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) print('Error loading AI recommendations: $e');
      }
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _reloadIfPending() {
    if (_isLoading || _hasError || _recommendedProducts != null) return;
    _loadRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (_, __) => _reloadIfPending());
    ref.listen(productsStreamProvider, (_, __) => _reloadIfPending());

    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 18,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'לא הצלחנו לטעון המלצות כרגע',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: _loadRecommendations,
              child: const Text('נסה שוב'),
            ),
          ],
        ),
      );
    }

    if (_recommendedProducts == null || _recommendedProducts!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'מומלץ במיוחד בשבילך',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _recommendedProducts!.length,
            itemBuilder: (context, index) {
              final product = _recommendedProducts![index];
              final reason = _recommendationReasons[product.id] ?? '';

              return _AIRecommendationCard(product: product, reason: reason);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AIRecommendationCard extends StatelessWidget {
  final ProductModel product;
  final String reason;

  const _AIRecommendationCard({required this.product, required this.reason});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: product.id),
          ),
        );
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, size: 50),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, size: 50),
                        ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        '₪${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),

                      if (reason.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 12,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  reason,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
