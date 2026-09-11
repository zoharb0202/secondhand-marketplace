import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/product_model.dart';

class SwipeableProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onTap;
  final bool isTopCard;

  const SwipeableProductCard({
    super.key,
    required this.product,
    this.onLike,
    this.onDislike,
    this.onTap,
    this.isTopCard = false,
  });

  @override
  State<SwipeableProductCard> createState() => _SwipeableProductCardState();
}

class _SwipeableProductCardState extends State<SwipeableProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  Offset _dragOffset = Offset.zero;
  double _rotation = 0.0;
  bool _isDragging = false;

  static const double _swipeThreshold = 100.0;
  static const double _rotationFactor = 0.0003;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.isTopCard) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SwipeableProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTopCard && !oldWidget.isTopCard) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _rotation = _dragOffset.dx * _rotationFactor;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final swipeDirection = _getSwipeDirection();

    if (swipeDirection == SwipeDirection.right) {
      _animateSwipe(SwipeDirection.right);
    } else if (swipeDirection == SwipeDirection.left) {
      _animateSwipe(SwipeDirection.left);
    } else {
      _resetPosition();
    }

    setState(() {
      _isDragging = false;
    });
  }

  SwipeDirection _getSwipeDirection() {
    if (_dragOffset.dx > _swipeThreshold) {
      return SwipeDirection.right;
    } else if (_dragOffset.dx < -_swipeThreshold) {
      return SwipeDirection.left;
    }
    return SwipeDirection.none;
  }

  void _animateSwipe(SwipeDirection direction) {
    final targetOffset = direction == SwipeDirection.right
        ? Offset(MediaQuery.of(context).size.width * 1.5, _dragOffset.dy)
        : Offset(-MediaQuery.of(context).size.width * 1.5, _dragOffset.dy);

    final animation = Tween<Offset>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(from: 0.0).then((_) {
      if (direction == SwipeDirection.right) {
        widget.onLike?.call();
      } else {
        widget.onDislike?.call();
      }
      _controller.reset();
    });

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });
  }

  void _resetPosition() {
    final animation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    final rotationAnimation = Tween<double>(
      begin: _rotation,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward(from: 0.0).then((_) {
      _controller.reset();
    });

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    rotationAnimation.addListener(() {
      setState(() {
        _rotation = rotationAnimation.value;
      });
    });
  }

  void swipeRight() {
    setState(() {
      _dragOffset = Offset(_swipeThreshold + 10, 0);
    });
    _animateSwipe(SwipeDirection.right);
  }

  void swipeLeft() {
    setState(() {
      _dragOffset = Offset(-_swipeThreshold - 10, 0);
    });
    _animateSwipe(SwipeDirection.left);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final swipeProgress = (_dragOffset.dx.abs() / _swipeThreshold).clamp(
      0.0,
      1.0,
    );
    final isSwipingRight = _dragOffset.dx > 0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _rotation,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onTap: widget.onTap,
            child: Stack(
              children: [
                Container(
                  width: screenSize.width - 32,
                  height: screenSize.height * 0.65,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.product.imageUrls.isNotEmpty
                            ? Image.network(
                                widget.product.imageUrls.first,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppColors.surfaceVariant,
                                      child: const Icon(
                                        Icons.image_outlined,
                                        size: 64,
                                      ),
                                    ),
                              )
                            : Container(
                                color: AppColors.surfaceVariant,
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 64,
                                ),
                              ),

                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.product.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₪${widget.product.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.product.city,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getCategoryName(
                                          widget.product.category,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isDragging && isSwipingRight)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.green.withValues(
                              alpha: swipeProgress,
                            ),
                            width: 8,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Opacity(
                          opacity: swipeProgress,
                          child: Container(
                            color: Colors.green.withValues(alpha: 0.3),
                            child: Center(
                              child: Transform.rotate(
                                angle: -0.3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 4,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        color: Colors.green,
                                        size: 48,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'אהבתי!',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_isDragging && !isSwipingRight)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.red.withValues(alpha: swipeProgress),
                            width: 8,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Opacity(
                          opacity: swipeProgress,
                          child: Container(
                            color: Colors.red.withValues(alpha: 0.3),
                            child: Center(
                              child: Transform.rotate(
                                angle: 0.3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 4,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.close,
                                        color: Colors.red,
                                        size: 48,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'לא מעניין',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryName(dynamic category) {
    if (category == null) return '';
    return category.toString().split('.').last;
  }
}

enum SwipeDirection { left, right, none }
