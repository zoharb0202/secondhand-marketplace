import 'package:flutter/material.dart';
import '../../shared/models/seller_storefront_model.dart';

class StorefrontThemePreset {
  final String name;
  final String description;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  final LinearGradient? headerGradient;
  final Color cardColor;
  final Color dividerColor;

  const StorefrontThemePreset({
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    this.headerGradient,
    required this.cardColor,
    required this.dividerColor,
  });

  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  static Map<StorefrontTheme, StorefrontThemePreset> get presets => {
    StorefrontTheme.modern: modern,
    StorefrontTheme.vibrant: vibrant,
    StorefrontTheme.elegant: elegant,
    StorefrontTheme.eco: eco,
  };

  static const StorefrontThemePreset modern = StorefrontThemePreset(
    name: 'Modern/Minimalist',
    description: 'נקי, פשוט, צבעים רכים, הרבה רווח לבן',
    primaryColor: Color(0xFF6366F1),
    accentColor: Color(0xFFA5B4FC),
    backgroundColor: Color(0xFFF8FAFC),
    textColor: Color(0xFF1E293B),
    headerGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    ),
    cardColor: Color(0xFFFFFFFF),
    dividerColor: Color(0xFFE2E8F0),
  );

  static const StorefrontThemePreset vibrant = StorefrontThemePreset(
    name: 'Bold/Vibrant',
    description: 'צבעוני, אנרגטי, גראדיאנטים חזקים',
    primaryColor: Color(0xFFEC4899),
    accentColor: Color(0xFFF59E0B),
    backgroundColor: Color(0xFFFEF3C7),
    textColor: Color(0xFF78350F),
    headerGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    cardColor: Color(0xFFFFFFFF),
    dividerColor: Color(0xFFFBCAB3),
  );

  static const StorefrontThemePreset elegant = StorefrontThemePreset(
    name: 'Elegant/Classic',
    description: 'אלגנטי, צבעים כהים, זהב/כסף',
    primaryColor: Color(0xFF1F2937),
    accentColor: Color(0xFFD97706),
    backgroundColor: Color(0xFFF3F4F6),
    textColor: Color(0xFF111827),
    headerGradient: null,
    cardColor: Color(0xFFFFFFFF),
    dividerColor: Color(0xFFD1D5DB),
  );

  static const StorefrontThemePreset eco = StorefrontThemePreset(
    name: 'Eco/Natural',
    description: 'ירוקים, חומים, טבעי, אורגני',
    primaryColor: Color(0xFF059669),
    accentColor: Color(0xFF92400E),
    backgroundColor: Color(0xFFF0FDF4),
    textColor: Color(0xFF14532D),
    headerGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF059669), Color(0xFF10B981)],
    ),
    cardColor: Color(0xFFFFFFFF),
    dividerColor: Color(0xFFBBF7D0),
  );

  static StorefrontThemePreset getPreset(StorefrontTheme theme) {
    return presets[theme]!;
  }

  static StorefrontThemePreset applyCustomization(
    StorefrontTheme theme,
    StorefrontCustomization customization,
  ) {
    final preset = getPreset(theme);

    return StorefrontThemePreset(
      name: preset.name,
      description: preset.description,
      primaryColor: customization.getPrimaryColor() ?? preset.primaryColor,
      accentColor: customization.getAccentColor() ?? preset.accentColor,
      backgroundColor:
          customization.getBackgroundColor() ?? preset.backgroundColor,
      textColor: customization.getTextColor() ?? preset.textColor,
      headerGradient: customization.hasCustomColors()
          ? null
          : preset.headerGradient,
      cardColor: preset.cardColor,
      dividerColor: preset.dividerColor,
    );
  }
}
