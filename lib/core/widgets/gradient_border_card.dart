import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GradientBorderCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final bool animateBorder;
  final Duration animationDuration;

  const GradientBorderCard({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.card,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.animateBorder = false,
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        backgroundColor ??
        (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorderLight;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: isDark ? 0.30 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
