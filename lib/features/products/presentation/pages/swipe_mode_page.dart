import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/widgets/swipeable_product_card.dart';
import '../providers/swipe_provider.dart';
import '../providers/product_provider.dart';
import 'product_detail_page.dart';

class SwipeModePage extends ConsumerStatefulWidget {
  const SwipeModePage({super.key});

  @override
  ConsumerState<SwipeModePage> createState() => _SwipeModePageState();
}

class _SwipeModePageState extends ConsumerState<SwipeModePage> {
  bool _productsLoaded = false;

  void _loadProducts(List<ProductModel> products) {
    if (_productsLoaded) return;
    _productsLoaded = true;
    final availableProducts = products
        .where((p) => !p.isSold && p.isActive)
        .toList();
    ref.read(swipeControllerProvider.notifier).loadProducts(availableProducts);
  }

  void _reloadProducts() {
    _productsLoaded = false;
    final productsAsync = ref.read(productsStreamProvider);
    final products = productsAsync.valueOrNull;
    if (products != null) {
      _loadProducts(products);
    }
  }

  void _handleLike() {
    ref.read(swipeControllerProvider.notifier).swipeRight();
  }

  void _handleDislike() {
    ref.read(swipeControllerProvider.notifier).swipeLeft();
  }

  void _handleCardTap() {
    final state = ref.read(swipeControllerProvider);
    if (state.currentProduct != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ProductDetailPage(productId: state.currentProduct!.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final swipeState = ref.watch(swipeControllerProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    ref.listen<AsyncValue<List<ProductModel>>>(productsStreamProvider, (
      previous,
      next,
    ) {
      next.whenData(_loadProducts);
    });

    final isInitialLoading =
        swipeState.isLoading || (!_productsLoaded && productsAsync.isLoading);
    final streamError = !_productsLoaded
        ? productsAsync.error?.toString()
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('גלה מוצרים'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('איך זה עובד?'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_forward, color: Colors.red),
                          SizedBox(width: 8),
                          Text('החלק שמאלה - לא מעניין'),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.arrow_back, color: Colors.green),
                          SizedBox(width: 8),
                          Text('החלק ימינה - אהבתי! 💚'),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'ככל שתשתמש יותר, המערכת תלמד את ההעדפות שלך ותציג מוצרים מותאמים אישית!',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('הבנתי'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : (swipeState.error ?? streamError) != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'שגיאה: ${swipeState.error ?? streamError}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _reloadProducts,
                    child: const Text('נסה שוב'),
                  ),
                ],
              ),
            )
          : !swipeState.hasMore
          ? _buildNoMoreProducts()
          : Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 20,
                      left: 16,
                      right: 16,
                      bottom: 120,
                    ),
                    child: _buildCardStack(swipeState),
                  ),
                ),

                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: _buildActionButtons(),
                ),

                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${swipeState.currentIndex + 1} / ${swipeState.products.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCardStack(SwipeState state) {
    final cards = <Widget>[];

    for (
      int i = state.currentIndex;
      i < state.currentIndex + 3 && i < state.products.length;
      i++
    ) {
      final product = state.products[i];
      final isTopCard = i == state.currentIndex;
      final offset = (i - state.currentIndex) * 8.0;

      cards.add(
        Positioned(
          top: offset,
          left: offset,
          right: offset,
          bottom: -offset,
          child: IgnorePointer(
            ignoring: !isTopCard,
            child: Transform.scale(
              scale: 1.0 - (i - state.currentIndex) * 0.05,
              child: Opacity(
                opacity: 1.0 - (i - state.currentIndex) * 0.3,
                child: SwipeableProductCard(
                  product: product,
                  isTopCard: isTopCard,
                  onLike: isTopCard ? _handleLike : null,
                  onDislike: isTopCard ? _handleDislike : null,
                  onTap: isTopCard ? _handleCardTap : null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(children: cards.reversed.toList());
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.close,
            color: Colors.red,
            size: 60,
            onPressed: () {
              _handleDislike();
            },
          ),

          _ActionButton(
            icon: Icons.info_outline,
            color: AppColors.primary,
            size: 50,
            onPressed: _handleCardTap,
          ),

          _ActionButton(
            icon: Icons.favorite,
            color: Colors.green,
            size: 60,
            onPressed: () {
              _handleLike();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoMoreProducts() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'זהו! סיימת את כל המוצרים',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'בוא שוב מאוחר יותר לגלות מוצרים חדשים',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(swipeControllerProvider.notifier).reset();
              _reloadProducts();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('התחל מחדש'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('חזור לדף הבית'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon, color: color, size: size * 0.5),
        ),
      ),
    );
  }
}
