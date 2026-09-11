import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class PremiumShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const PremiumShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 200,
    this.borderRadius = AppRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1500),
          color: AppColors.shimmerHighlight,
        );
  }
}

class PremiumShimmerCard extends StatelessWidget {
  const PremiumShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumShimmer(height: 160, borderRadius: AppRadius.card),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumShimmer(height: 16, width: 140, borderRadius: 8),
                SizedBox(height: 8),
                PremiumShimmer(height: 20, width: 80, borderRadius: 8),
                SizedBox(height: 8),
                PremiumShimmer(height: 12, width: 120, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumShimmerGrid extends StatelessWidget {
  final int itemCount;

  const PremiumShimmerGrid({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const PremiumShimmerCard(),
    );
  }
}
