import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/gradient_border_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../../core/widgets/animated_gradient.dart';
import '../../../../shared/models/cart_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../../../products/presentation/pages/product_detail_page.dart';
import 'cart_checkout_page.dart';

const int kMaxUnitsPerOrder = 10;

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  bool _isSyncing = false;

  Future<void> _syncCart(String userId) async {
    if (!mounted) return;

    setState(() => _isSyncing = true);
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .syncCartWithProducts(userId);
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _removeItem(String userId, String productId) async {
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .removeItem(userId, productId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהסרת פריט: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateQuantity(
    String userId,
    String productId,
    int newQuantity,
  ) async {
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .updateItemQuantity(
            userId,
            productId,
            math.min(newQuantity, kMaxUnitsPerOrder),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון כמות: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _clearCart(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'ריקון עגלה',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'האם אתה בטוח שברצונך לרוקן את העגלה?',
          style: TextStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('אישור'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(cartControllerProvider.notifier).clearCart(userId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בריקון עגלה: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _proceedToCheckout(ShoppingCart cart) {
    if (cart.hasStockIssues) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'יש פריטים שאינם זמינים במלאי. אנא הסר אותם לפני המשך.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CartCheckoutPage(cart: cart)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return Scaffold(
            appBar: AppBar(
              title: GradientText(
                'עגלת קניות',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            body: const Center(
              child: Text(
                'יש להתחבר כדי לצפות בעגלת הקניות',
                style: TextStyle(),
              ),
            ),
          );
        }

        return _buildCartView(context, currentUser);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: GradientText(
            'עגלת קניות',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.accentCobalt),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('עגלת קניות')),
        body: _CartStreamError(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildCartView(BuildContext context, UserModel currentUser) {
    final cartAsync = ref.watch(cartProvider(currentUser.id));

    final bottomClearance = NavBarClearance.of(context);

    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          'עגלת קניות',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isSyncing)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.accentCobalt,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => _syncCart(currentUser.id),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.altSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: context.textSecondary,
                ),
              ),
            ),
          GestureDetector(
            onTap: () => _clearCart(currentUser.id),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.luxuryGradient3,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                      )
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                  const Text(
                        'העגלה ריקה',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms)
                      .moveY(begin: 10, end: 0, duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    'הוסף פריטים לעגלה כדי להתחיל',
                    style: TextStyle(color: context.textSecondary),
                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return _CartItemCard(
                      item: item,
                      index: index,
                      onRemove: () =>
                          _removeItem(currentUser.id, item.productId),
                      onQuantityChanged: (newQuantity) => _updateQuantity(
                        currentUser.id,
                        item.productId,
                        newQuantity,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductDetailPage(productId: item.productId),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              Padding(
                padding: EdgeInsets.only(bottom: bottomClearance),
                child: GlassContainer(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  blur: 12,
                  padding: const EdgeInsets.all(20),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'סה"כ פריטים:',
                              style: TextStyle(
                                fontSize: 15,
                                color: context.textSecondary,
                              ),
                            ),
                            Text(
                              '${cart.totalItems}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'סה"כ לתשלום:',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            GradientText(
                              '₪${cart.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: GradientButton(
                            text: 'המשך לתשלום',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: cart.hasStockIssues
                                ? null
                                : () => _proceedToCheckout(cart),
                            height: 54,
                            borderRadius: 16,
                          ),
                        ),
                        if (cart.hasStockIssues)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'יש פריטים שאינם זמינים במלאי',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.accentCobalt),
        ),
        error: (error, stack) => _CartStreamError(
          onRetry: () => ref.invalidate(cartProvider(currentUser.id)),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final int index;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;
  final VoidCallback onTap;

  const _CartItemCard({
    required this.item,
    required this.index,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasStockIssue = !item.hasEnoughStock;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child:
          GradientBorderCard(
                borderRadius: 16,
                borderWidth: hasStockIssue ? 2.0 : 1.2,
                animateBorder: !hasStockIssue,
                animationDuration: Duration(seconds: 4 + (index % 3)),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.productImage != null
                              ? Image.network(
                                  item.productImage!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: context.altSurface,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.image_not_supported_rounded,
                                          color: context.textTertiary,
                                        ),
                                      ),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: context.altSurface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.shopping_bag_rounded,
                                    color: context.textTertiary,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'מוכר: ${item.sellerName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (hasStockIssue)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.error,
                                        AppColors.error.withValues(alpha: 0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.availableStock == 0
                                        ? 'אזל מהמלאי'
                                        : 'נותרו רק ${item.availableStock}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        AppColors.luxuryGradient1.createShader(
                                          Rect.fromLTWH(
                                            0,
                                            0,
                                            bounds.width,
                                            bounds.height,
                                          ),
                                        ),
                                    blendMode: BlendMode.srcIn,
                                    child: Text(
                                      '₪${item.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (item.availableStock > 1)
                                    _QuantityControl(
                                      quantity: item.quantity,
                                      maxQuantity: math.min(
                                        item.availableStock,
                                        kMaxUnitsPerOrder,
                                      ),
                                      onLimitReached:
                                          item.availableStock >
                                              kMaxUnitsPerOrder
                                          ? () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'מוגבל ל-$kMaxUnitsPerOrder יחידות בהזמנה',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.warning,
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            }
                                          : null,
                                      onChanged: onQuantityChanged,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: 60 * index))
              .fadeIn(duration: 400.ms, curve: Curves.easeOut)
              .moveX(
                begin: 30,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final int maxQuantity;
  final Function(int) onChanged;

  final VoidCallback? onLimitReached;

  const _QuantityControl({
    required this.quantity,
    required this.maxQuantity,
    required this.onChanged,
    this.onLimitReached,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: quantity > 1 ? () => onChanged(quantity - 1) : null,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.remove_rounded,
                size: 18,
                color: quantity > 1
                    ? context.textPrimary
                    : context.textTertiary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$quantity',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: quantity < maxQuantity
                ? () => onChanged(quantity + 1)
                : onLimitReached,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.add_rounded,
                size: 18,
                color: quantity < maxQuantity
                    ? context.textPrimary
                    : context.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartStreamError extends StatelessWidget {
  final VoidCallback onRetry;

  const _CartStreamError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: context.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'לא הצלחנו לטעון את העגלה',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'בדקו את החיבור לאינטרנט ונסו שוב.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('נסו שוב'),
            ),
          ],
        ),
      ),
    );
  }
}
