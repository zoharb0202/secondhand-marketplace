import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/opening_hours.dart';
import '../../../../core/services/share_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../core/widgets/price_text.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/image_variants.dart';
import '../../../../shared/models/cart_model.dart';
import '../../../../shared/models/availability_window.dart';
import '../providers/product_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/data/repositories/cart_repository.dart';
import '../../../orders/presentation/pages/checkout_page.dart';
import '../widgets/price_offer_dialog.dart';
import '../widgets/seller_card.dart';
import '../widgets/social_proof_widget.dart';
import '../widgets/similar_products_section.dart';
import 'product_comparison_page.dart';
import '../../../../core/services/providers/recommendation_provider.dart';
import '../../../../core/services/recommendation_service.dart';
import '../../../../core/services/interaction_tracker.dart';
import 'recently_viewed_page.dart';

const int _kMaxUnitsPerOrder = 10;

class ProductDetailPage extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _currentImageIndex = 0;
  bool _isSellerAvailableNow = false;
  bool _isLoadingAvailability = true;

  final Stopwatch _dwellStopwatch = Stopwatch();
  final RecommendationService _recommendationService = RecommendationService();
  String? _dwellUserId;

  ProductModel? _viewedProduct;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _stockSub;
  int? _stockTotal;
  int? _stockRemaining;

  bool get _hasStock => _stockTotal != null;

  int _unitsAvailableFor(ProductModel product) {
    if (_hasStock) return _stockRemaining ?? 0;
    return product.isAvailableForSale ? 1 : 0;
  }

  bool get _showsLowStockHint {
    final total = _stockTotal;
    final remaining = _stockRemaining;
    if (total == null || remaining == null) return false;
    return total >= 3 && remaining >= 1 && remaining <= 2;
  }

  @override
  void initState() {
    super.initState();
    _dwellStopwatch.start();
    _dwellUserId = ref.read(currentUserProvider).value?.id;
    Future.microtask(() {
      ref
          .read(productControllerProvider.notifier)
          .incrementViewCount(widget.productId);

      _trackProductView();

      RecentlyViewedService.addProduct(widget.productId);
    });

    _stockSub = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          final data = snap.data();
          setState(() {
            _stockTotal = (data?['stockTotal'] as num?)?.toInt();
            _stockRemaining = (data?['stockRemaining'] as num?)?.toInt();
          });
        });
  }

  @override
  void dispose() {
    _stockSub?.cancel();
    _dwellStopwatch.stop();
    final userId = _dwellUserId;
    final product = _viewedProduct;
    if (userId != null && product != null) {
      final seconds = _dwellStopwatch.elapsed.inSeconds;
      _recommendationService.trackDwell(
        userId,
        widget.productId,
        product.category.name,
        seconds,
        price: product.price,
      );
      InteractionTracker().track(
        InteractionType.dwell,
        product: product,
        dwellMs: _dwellStopwatch.elapsedMilliseconds,
      );
    }
    super.dispose();
  }

  Future<void> _trackProductView() async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();

      if (productDoc.exists) {
        final product = ProductModel.fromFirestore(productDoc);
        _viewedProduct = product;
        ref
            .read(recommendationControllerProvider.notifier)
            .trackView(widget.productId, product.category.name);
        InteractionTracker().track(
          InteractionType.viewDetail,
          product: product,
        );
      }
    } catch (_) {}
  }

  Future<void> _checkSellerAvailability(String sellerId) async {
    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();

      if (sellerDoc.exists) {
        final data = sellerDoc.data();
        if (data != null && data['availabilityWindows'] != null) {
          final windows = (data['availabilityWindows'] as List<dynamic>)
              .map((w) => AvailabilityWindow.fromMap(w as Map<String, dynamic>))
              .toList();

          if (isOpenAt(windows, DateTime.now())) {
            if (mounted) {
              setState(() {
                _isSellerAvailableNow = true;
                _isLoadingAvailability = false;
              });
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isSellerAvailableNow = false;
          _isLoadingAvailability = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSellerAvailableNow = false;
          _isLoadingAvailability = false;
        });
      }
    }
  }

  Future<void> _addToCart(BuildContext context, ProductModel product) async {
    final currentUser = ref.read(currentUserProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להתחבר כדי להוסיף לעגלה')),
      );
      return;
    }

    if (product.isSold) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('המוצר נמכר'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!product.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('המוצר אינו פעיל'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final unitsAvailable = _unitsAvailableFor(product);
    if (unitsAvailable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אזל המלאי'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String sellerName = 'מוכר';
    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(product.sellerId)
          .get();
      if (sellerDoc.exists) {
        sellerName = sellerDoc.data()?['displayName'] ?? 'מוכר';
      }
    } catch (_) {}

    final cartItem = CartItem(
      productId: product.id,
      productTitle: product.title,
      productImage: product.imageUrls.isNotEmpty ? product.imageUrls[0] : null,
      price: product.price,
      quantity: 1,
      sellerId: product.sellerId,
      sellerName: sellerName,
      availableStock: math.min(unitsAvailable, _kMaxUnitsPerOrder),
    );

    try {
      final result = await ref
          .read(cartControllerProvider.notifier)
          .addItem(currentUser.id, cartItem);

      if (!context.mounted) return;

      final String message;
      final Color color;
      switch (result.outcome) {
        case AddToCartOutcome.added:
          message = 'המוצר נוסף לעגלה';
          color = Colors.green;
        case AddToCartOutcome.incremented:
          message = 'עודכן בעגלה · כמות: ${result.quantity}';
          color = Colors.green;
        case AddToCartOutcome.alreadyInCart:
          message = 'המוצר כבר בעגלה';
          color = AppColors.warning;
        case AddToCartOutcome.stockLimitReached:
          message = unitsAvailable > _kMaxUnitsPerOrder
              ? 'מוגבל ל-$_kMaxUnitsPerOrder יחידות בהזמנה'
              : 'כל המלאי הזמין כבר בעגלה (${result.quantity})';
          color = AppColors.warning;
        case AddToCartOutcome.outOfStock:
          message = 'אזל המלאי';
          color = AppColors.error;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהוספה לעגלה: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productProvider(widget.productId));
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: productAsync.when(
        data: (product) {
          if (product != null && _isLoadingAvailability) {
            _checkSellerAvailability(product.sellerId);
          }

          if (product == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text('המוצר לא נמצא'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('חזור'),
                  ),
                ],
              ),
            );
          }

          final isLiked =
              currentUser != null &&
              product.likedByUserIds.contains(currentUser.id);
          final isMyProduct =
              currentUser != null && product.sellerId == currentUser.id;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildImageCarousel(product),
                ),
                actions: [
                  if (!isMyProduct && currentUser != null)
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_outline,
                        color: AppColors.accent,
                      ),
                      onPressed: () {
                        ref
                            .read(productControllerProvider.notifier)
                            .toggleLike(product.id, currentUser.id);
                      },
                    ),
                  AddToComparisonButton(product: product),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () {
                      final product = ref
                          .read(productProvider(widget.productId))
                          .value;
                      if (product != null) {
                        InteractionTracker().track(
                          InteractionType.share,
                          product: product,
                        );
                        ShareService.showShareSheet(context, product);
                      }
                    },
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: priceText(
                                  product.price,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: AppColors.sunDeep,
                                        fontSize: 32,
                                      ),
                                ),
                              ),
                              if (_isSellerAvailableNow && !product.isSold)
                                Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.palm,
                                    borderRadius: AppRadius.chipR,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.flash_on_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'זמין לאיסוף מיידי',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (product.isSold)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.palm,
                                    borderRadius: AppRadius.chipR,
                                  ),
                                  child: const Text(
                                    'נמכר',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          _buildStockInfo(product, isMyProduct),
                          if (!product.isSold)
                            Consumer(
                              builder: (context, ref, _) {
                                final pct = marketDealPercent(
                                  product,
                                  ref.watch(marketMediansProvider),
                                );
                                if (pct == null) return const SizedBox.shrink();
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.palm.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.palm.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_offer,
                                        size: 16,
                                        color: AppColors.palm,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'מחיר מעולה · $pct% מתחת למחיר השוק',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.palm,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 8),
                          Text(
                            product.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: context.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                product.city,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: context.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.visibility_outlined,
                                size: 16,
                                color: context.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${product.viewCount} צפיות',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: context.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.favorite_outline,
                                size: 16,
                                color: context.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${product.likeCount}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: context.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Consumer(
                            builder: (context, ref, _) {
                              final recent = ref
                                  .watch(recentProductStatsProvider(product.id))
                                  .maybeWhen(
                                    data: (s) => s.views,
                                    orElse: () => 0,
                                  );
                              return SocialProofWidget(
                                viewCount: product.viewCount,
                                favoriteCount: product.likeCount,
                                recentViews: recent,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: context.hairline,
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'פרטי המוצר',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            label: 'קטגוריה',
                            value: product.category.displayName,
                          ),
                          _InfoRow(
                            label: 'מצב',
                            value: product.condition.displayName,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'תיאור',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.description,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: context.hairline,
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_pin_circle_outlined,
                            size: 22,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              product.city.isNotEmpty
                                  ? 'איסוף עצמי מהמוכר · ${product.city}'
                                  : 'איסוף עצמי מהמוכר',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: context.hairline,
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'המוכר',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          SellerCard(sellerId: product.sellerId),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    SimilarProductsSection(currentProduct: product),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 16),
                Text(
                  'טוען מוצר...',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms),
          ),
        ),
        error: (error, _) => Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamErrorView(
                error: error,
                title: 'לא הצלחנו לטעון את המוצר',
                onRetry: () =>
                    ref.invalidate(productProvider(widget.productId)),
              ),
              GradientButton(
                text: 'חזור',
                onPressed: () => Navigator.pop(context),
                height: 48,
                borderRadius: 14,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: productAsync.when(
        data: (product) {
          if (product == null) return const SizedBox.shrink();

          final isMyProduct =
              currentUser != null && product.sellerId == currentUser.id;

          if (isMyProduct) {
            return const SizedBox.shrink();
          }

          final outOfStock = _hasStock && _unitsAvailableFor(product) <= 0;
          if (product.isSold || !product.isActive || outOfStock) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardSurface,
                boxShadow: AppColors.premiumShadow,
              ),
              child: GradientButton(
                text: (product.isSold || outOfStock)
                    ? (_hasStock ? 'אזל המלאי' : 'המוצר נמכר')
                    : 'המוצר אינו זמין',
                onPressed: null,
                height: 52,
                borderRadius: 16,
                gradient: LinearGradient(
                  colors: [
                    context.textTertiary,
                    context.textTertiary.withValues(alpha: 0.8),
                  ],
                ),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardSurface,
              boxShadow: AppColors.premiumShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (currentUser == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('יש להתחבר כדי לשלוח הודעה'),
                              ),
                            );
                            return;
                          }

                          final chat = await ref
                              .read(chatControllerProvider.notifier)
                              .getOrCreateChat(
                                productId: product.id,
                                productTitle: product.title,
                                productImageUrl: product.imageUrls.isNotEmpty
                                    ? product.imageUrls.first
                                    : '',
                                sellerId: product.sellerId,
                                sellerName:
                                    ref
                                        .read(
                                          userDisplayNameProvider(
                                            product.sellerId,
                                          ),
                                        )
                                        .valueOrNull ??
                                    'מוכר',
                                buyerId: currentUser.id,
                                buyerName: currentUser.displayName ?? 'קונה',
                                buyerPhotoUrl: currentUser.photoUrl,
                              );

                          if (!context.mounted) return;

                          if (chat == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'לא ניתן לפתוח את הצ׳אט כרגע, נסה שוב',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          InteractionTracker().track(
                            InteractionType.chatStarted,
                            product: product,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(chatId: chat.id),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('הודעה'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    if (!_hasStock) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('יש להתחבר כדי להציע מחיר'),
                                ),
                              );
                              return;
                            }

                            showDialog(
                              context: context,
                              builder: (context) => PriceOfferDialog(
                                productId: product.id,
                                productTitle: product.title,
                                sellerId: product.sellerId,
                                originalPrice: product.price,
                                product: product,
                              ),
                            );
                          },
                          icon: const Icon(Icons.local_offer_outlined),
                          label: const Text('הצע מחיר'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.accent),
                            foregroundColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _addToCart(context, product);
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('הוסף לעגלה'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        text: 'קנה עכשיו',
                        icon: Icons.shopping_cart_checkout_rounded,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CheckoutPage(product: product),
                          ),
                        ),
                        height: 52,
                        borderRadius: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildStockInfo(ProductModel product, bool isMyProduct) {
    if (!_hasStock) return const SizedBox.shrink();
    final remaining = _stockRemaining ?? 0;
    final total = _stockTotal ?? 0;

    if (isMyProduct) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'נותרו $remaining מתוך $total',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'במלאי: $remaining יח׳',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          if (_showsLowStockHint) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'נותרו רק $remaining',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageCarousel(ProductModel product) {
    if (product.imageUrls.isEmpty) {
      return Container(
        color: context.altSurface,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 80,
            color: context.textTertiary,
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          itemCount: product.imageUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl:
                  product.imageUrlAt(index, variant: ImageVariant.medium) ??
                  product.imageUrls[index],
              fit: BoxFit.cover,
              memCacheWidth: kMediumDecodeWidth,
              placeholder: (context, url) => Container(
                color: context.altSurface,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: context.altSurface,
                child: const Center(
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                ),
              ),
            );
          },
        ),
        if (product.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                product.imageUrls.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentImageIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: _currentImageIndex == index
                        ? AppColors.cobalt
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: context.textSecondary),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
