import 'package:flutter/material.dart';

import 'app_colors.dart';

extension ThemeColors on BuildContext {
  ColorScheme get _scheme => Theme.of(this).colorScheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get textPrimary => _scheme.onSurface;

  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  Color get textTertiary =>
      isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

  Color get cardSurface => _scheme.surface;

  Color get altSurface => _scheme.surfaceContainerHighest;

  Color get pageBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get hairline => _scheme.outline;

  Color get hairlineSoft => isDark
      ? AppColors.darkBorder.withValues(alpha: 0.55)
      : AppColors.lightBorderLight;

  Color get accentCobalt => isDark ? AppColors.cobaltLift : AppColors.cobalt;
}
