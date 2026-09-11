import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SocialProofWidget extends StatelessWidget {
  final int viewCount;
  final int favoriteCount;
  final int recentViews;
  final bool showViewers;
  final bool showFavorites;

  const SocialProofWidget({
    super.key,
    required this.viewCount,
    required this.favoriteCount,
    this.recentViews = 0,
    this.showViewers = true,
    this.showFavorites = true,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> indicators = [];

    if (showViewers && recentViews >= 3) {
      indicators.add(_buildRecentViewersIndicator());
    }

    if (showFavorites && favoriteCount > 0) {
      indicators.add(_buildFavoritesIndicator());
    }

    if (indicators.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border(
          right: BorderSide(
            color: Colors.orange.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: indicators.map((indicator) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: indicator,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentViewersIndicator() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.visibility, size: 16, color: Colors.orange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getViewersText(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesIndicator() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.pink.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite, size: 16, color: Colors.pink),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getFavoritesText(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _getViewersText() {
    return 'נצפה $recentViews פעמים בשבוע האחרון';
  }

  String _getFavoritesText() {
    if (favoriteCount == 1) {
      return 'אדם אחד שמר את המוצר הזה';
    } else if (favoriteCount == 2) {
      return 'שני אנשים שמרו את המוצר הזה';
    } else {
      return '$favoriteCount אנשים שמרו את המוצר הזה';
    }
  }
}

class SocialProofBadge extends StatefulWidget {
  final int count;
  final IconData icon;
  final Color color;
  final String label;

  const SocialProofBadge({
    super.key,
    required this.count,
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  State<SocialProofBadge> createState() => _SocialProofBadgeState();
}

class _SocialProofBadgeState extends State<SocialProofBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 14, color: widget.color),
            const SizedBox(width: 4),
            Text(
              '${widget.count}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
