import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';

class SellerLevel {
  final int tier;
  final String name;
  final IconData icon;
  final Color color;
  final int floor;
  final int? nextFloor;

  const SellerLevel({
    required this.tier,
    required this.name,
    required this.icon,
    required this.color,
    required this.floor,
    required this.nextFloor,
  });

  bool get isMax => nextFloor == null;

  double progress(int sales) {
    if (nextFloor == null) return 1;
    final span = nextFloor! - floor;
    if (span <= 0) return 1;
    return ((sales - floor) / span).clamp(0.0, 1.0);
  }

  int salesToNext(int sales) =>
      nextFloor == null ? 0 : (nextFloor! - sales).clamp(0, nextFloor!);

  static const List<_Tier> _tiers = [
    _Tier(0, 'מוכר מתחיל', Icons.eco_outlined, AppColors.palm, 0),
    _Tier(
      1,
      'מוכר פעיל',
      Icons.local_fire_department_outlined,
      Color(0xFFE8930C),
      5,
    ),
    _Tier(2, 'מוכר מנוסה', Icons.trending_up, AppColors.cobalt, 20),
    _Tier(3, 'מוכר מקצוען', Icons.workspace_premium, Color(0xFFE75A4E), 50),
    _Tier(4, 'אלוף מכירות', Icons.emoji_events, Color(0xFFF5A623), 100),
  ];

  factory SellerLevel.forSales(int sales) {
    var current = _tiers.first;
    for (final t in _tiers) {
      if (sales >= t.floor) current = t;
    }
    final nextTier = current.tier + 1 < _tiers.length
        ? _tiers[current.tier + 1]
        : null;
    return SellerLevel(
      tier: current.tier,
      name: current.name,
      icon: current.icon,
      color: current.color,
      floor: current.floor,
      nextFloor: nextTier?.floor,
    );
  }
}

class _Tier {
  final int tier;
  final String name;
  final IconData icon;
  final Color color;
  final int floor;
  const _Tier(this.tier, this.name, this.icon, this.color, this.floor);
}

class SellerLevelCard extends StatelessWidget {
  final UserModel seller;

  const SellerLevelCard({super.key, required this.seller});

  @override
  Widget build(BuildContext context) {
    final sales = seller.totalSales;
    final level = SellerLevel.forSales(sales);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: level.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(level.icon, color: level.color, size: 22),
              const SizedBox(width: 8),
              Text(
                level.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: level.color,
                ),
              ),
              const Spacer(),
              Text(
                '$sales מכירות',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: level.progress(sales),
              minHeight: 8,
              backgroundColor: level.color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(level.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            level.isMax
                ? '🏆 הרמה הגבוהה ביותר!'
                : 'עוד ${level.salesToNext(sales)} מכירות לרמה הבאה',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
