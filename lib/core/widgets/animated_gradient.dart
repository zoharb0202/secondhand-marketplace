import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedGradientContainer extends StatelessWidget {
  final Widget? child;
  final BorderRadius? borderRadius;
  final Duration duration;
  final List<Color>? colors;
  final double? width;
  final double? height;
  final EdgeInsets? padding;

  const AnimatedGradientContainer({
    super.key,
    this.child,
    this.borderRadius,
    this.duration = const Duration(seconds: 4),
    this.colors,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final palette = colors;
    final Color start = (palette != null && palette.isNotEmpty)
        ? palette.first
        : AppColors.cobalt;
    final Color end = (palette != null && palette.length > 1)
        ? palette[1]
        : AppColors.primaryDark;

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: [start, end],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: child,
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient? gradient;
  final TextAlign? textAlign;

  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle();
    return Text(
      text,
      style: base.color == null ? base.copyWith(color: AppColors.ink) : base,
      textAlign: textAlign,
    );
  }
}
