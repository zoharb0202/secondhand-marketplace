import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/layout_constants.dart';
import 'app_colors.dart';

class AppTheme {
  static final String? _fontBody = GoogleFonts.ibmPlexSansHebrew().fontFamily;

  static TextStyle _display(TextStyle base) => GoogleFonts.miriamLibre(
    textStyle: base.copyWith(
      fontWeight: base.fontWeight ?? FontWeight.w700,
      letterSpacing: base.letterSpacing ?? -0.3,
    ),
  );

  static TextStyle _body(TextStyle base) =>
      GoogleFonts.ibmPlexSansHebrew(textStyle: base);

  static TextStyle display(TextStyle base) => _display(base);

  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    insetPadding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      AppLayout.navBarHeight + AppLayout.navBarBottomMargin + AppSpacing.xs,
    ),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
  );

  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    Color tertiary,
  ) {
    return TextTheme(
      displayLarge: _display(
        TextStyle(fontSize: 40, height: 1.05, color: primary),
      ),
      displayMedium: _display(
        TextStyle(fontSize: 32, height: 1.08, color: primary),
      ),
      displaySmall: _display(
        TextStyle(fontSize: 26, height: 1.1, color: primary),
      ),
      headlineLarge: _display(
        TextStyle(fontSize: 24, height: 1.12, color: primary),
      ),
      headlineMedium: _display(TextStyle(fontSize: 20, color: primary)),
      headlineSmall: _display(TextStyle(fontSize: 18, color: primary)),
      titleLarge: _body(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary),
      ),
      titleMedium: _body(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primary),
      ),
      titleSmall: _body(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: secondary),
      ),
      bodyLarge: _body(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
      ),
      bodyMedium: _body(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: primary),
      ),
      bodySmall: _body(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
      ),
      labelLarge: _body(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      ),
      labelMedium: _body(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
      ),
      labelSmall: _body(
        TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: tertiary),
      ),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(
      AppColors.lightTextPrimary,
      AppColors.lightTextSecondary,
      AppColors.lightTextTertiary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontBody,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        tertiary: AppColors.sunDeep,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.lightBorder,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: _display(
          const TextStyle(fontSize: 22, color: AppColors.lightTextPrimary),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: const BorderSide(color: AppColors.lightBorderLight, width: 1),
        ),
        margin: const EdgeInsets.all(AppSpacing.xs),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: _body(const TextStyle(color: AppColors.lightTextTertiary)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
          textStyle: _body(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: _body(
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.6),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
          textStyle: _body(
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedColor: AppColors.ink,
        checkmarkColor: Colors.white,
        secondaryLabelStyle: _body(
          const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
        labelStyle: _body(
          const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextPrimary,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: const StadiumBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sheetR,
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        titleTextStyle: _display(
          const TextStyle(fontSize: 20, color: AppColors.lightTextPrimary),
        ),
        contentTextStyle: _body(
          const TextStyle(fontSize: 15, color: AppColors.lightTextSecondary),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),

      snackBarTheme: _snackBarTheme,

      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),

      textTheme: textTheme,
    );
  }

  static ThemeData get darkTheme {
    const darkBg = Color(0xFF0D0F10);
    const darkSurface = Color(0xFF17191B);
    const darkBorder = Color(0xFF2B2E31);
    const cobaltLift = Color(0xFF34B886);
    const onDark = Color(0xFFEDEDEA);
    const onDarkSecondary = Color(0xFFA2A5A8);

    final textTheme = _buildTextTheme(
      onDark,
      onDarkSecondary,
      const Color(0xFF6F7376),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _fontBody,
      colorScheme: const ColorScheme.dark(
        primary: cobaltLift,
        onPrimary: Color(0xFF06140E),
        secondary: AppColors.coral,
        onSecondary: Colors.white,
        tertiary: AppColors.sun,
        surface: darkSurface,
        onSurface: onDark,
        surfaceContainerHighest: Color(0xFF1F2224),
        error: Color(0xFFE8715C),
        onError: Colors.white,
        outline: darkBorder,
      ),
      scaffoldBackgroundColor: darkBg,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: darkBg,
        foregroundColor: onDark,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: _display(const TextStyle(fontSize: 22, color: onDark)),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: const EdgeInsets.all(AppSpacing.xs),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputR,
          borderSide: const BorderSide(color: cobaltLift, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: _body(const TextStyle(color: Color(0xFF6F7376))),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cobaltLift,
          foregroundColor: const Color(0xFF06140E),
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
          textStyle: _body(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cobaltLift,
          textStyle: _body(
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cobaltLift,
          side: const BorderSide(color: cobaltLift, width: 1.6),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
          textStyle: _body(
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: cobaltLift,
        foregroundColor: Color(0xFF06140E),
        elevation: 0,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: onDark,
        checkmarkColor: darkBg,
        secondaryLabelStyle: _body(
          const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: darkBg,
          ),
        ),
        side: const BorderSide(color: darkBorder, width: 1),
        labelStyle: _body(
          const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: onDark,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: const StadiumBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sheetR,
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        titleTextStyle: _display(const TextStyle(fontSize: 20, color: onDark)),
        contentTextStyle: _body(
          const TextStyle(fontSize: 15, color: onDarkSecondary),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),

      snackBarTheme: _snackBarTheme,

      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),

      textTheme: textTheme,
    );
  }
}
