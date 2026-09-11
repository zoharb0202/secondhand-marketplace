import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';

class SellerTrustBadges extends StatelessWidget {
  final UserModel seller;
  final bool center;

  const SellerTrustBadges({
    super.key,
    required this.seller,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    final badges = _earnedBadges(seller);
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );
  }

  static List<Widget> _earnedBadges(UserModel s) {
    final out = <Widget>[];

    if (s.isSellerVerified) {
      out.add(
        const _Badge(
          icon: Icons.verified,
          label: 'מוכר מאומת',
          color: AppColors.cobalt,
        ),
      );
    }

    final rating = s.sellerRating ?? 0;
    if (rating >= 4.5 && s.totalSales >= 5) {
      out.add(
        const _Badge(
          icon: Icons.workspace_premium,
          label: 'מוכר מצטיין',
          color: Color(0xFFE8930C),
        ),
      );
    }

    if (s.totalSales >= 20) {
      out.add(
        const _Badge(
          icon: Icons.trending_up,
          label: 'מוכר מנוסה',
          color: AppColors.palm,
        ),
      );
    }

    final daysMember = DateTime.now().difference(s.createdAt).inDays;
    if (daysMember >= 365) {
      final years = (daysMember / 365).floor();
      out.add(
        _Badge(
          icon: Icons.emoji_events_outlined,
          label: years >= 2 ? 'ותיק • $years שנים' : 'חבר ותיק',
          color: AppColors.textSecondary,
        ),
      );
    }

    return out;
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
