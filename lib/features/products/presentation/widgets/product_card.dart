import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/gradient_border_card.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/image_variants.dart';
import '../pages/product_detail_page.dart';
import '../providers/product_provider.dart';

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final bool isLiked;
  final VoidCallback? onLike;

  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.isLiked,
    this.onLike,
    this.onTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  bool get _isSellerAvailableNow =>
      widget.product.sellerIsOpenAt(DateTime.now()) ?? false;

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap != null) {
      onTap();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(productId: widget.product.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (mounted) _pressController.forward();
      },
      onTapUp: (_) {
        if (mounted) _pressController.reverse();
      },
      onTapCancel: () {
        if (mounted) _pressController.reverse();
      },
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GradientBorderCard(
          borderRadius: AppRadius.card,
          borderWidth: 1,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    SizedBox.expand(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.card),
                        ),
                        child: widget.product.imageUrls.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl:
                                    widget.product.thumbnailUrl ??
                                    widget.product.imageUrls.first,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                memCacheWidth: kThumbDecodeWidth,
                                fadeInDuration: 400.ms,
                                placeholder: (context, url) => Container(
                                  color: context.altSurface,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.accentCobalt.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  return Container(
                                    color: context.altSurface,
                                    child: Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 40,
                                        color: context.textTertiary,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: context.altSurface,
                                child: Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 40,
                                    color: context.textTertiary,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    if (widget.onLike != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: widget.onLike,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.lightSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.lightBorder,
                                width: 1,
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                widget.isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                key: ValueKey(widget.isLiked),
                                size: 18,
                                color: widget.isLiked
                                    ? AppColors.coral
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (_isSellerAvailableNow && !widget.product.isSold)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.palm,
                            borderRadius: AppRadius.chipR,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flash_on_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'זמין מיידי',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (!widget.product.isSold)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final dealPct = marketDealPercent(
                              widget.product,
                              ref.watch(marketMediansProvider),
                            );
                            if (dealPct != null) {
                              return _CardTagBadge(
                                icon: Icons.local_offer,
                                label: '$dealPct%- משוק',
                                color: AppColors.palm,
                              );
                            }
                            final isTrending = ref
                                .watch(trendingScoresProvider)
                                .maybeWhen(
                                  data: (m) => m.containsKey(widget.product.id),
                                  orElse: () => false,
                                );
                            if (!isTrending) return const SizedBox.shrink();
                            return const _CardTagBadge(
                              icon: Icons.local_fire_department,
                              label: 'מבוקש',
                              color: AppColors.coral,
                            );
                          },
                        ),
                      ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.sunDeep,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(AppRadius.chip),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          '${widget.product.price.toStringAsFixed(0)} ₪',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.chipR,
                            border: Border.all(
                              color: context.hairline,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.product.condition.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.product.city,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTagBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CardTagBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.chipR),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
