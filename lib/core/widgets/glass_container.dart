import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.sheetR,
    this.blur = AppColors.glassBlur,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark ? const Color(0xFF182238) : AppColors.surface),
        borderRadius: borderRadius,
        border: Border.all(
          color:
              borderColor ??
              (isDark ? const Color(0xFF2A3550) : AppColors.border),
          width: borderWidth,
        ),
        boxShadow: AppColors.offsetShadow(
          color: isDark ? const Color(0xFF5B7BFF) : AppColors.cobalt,
          alpha: isDark ? 0.20 : 0.10,
        ),
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}
