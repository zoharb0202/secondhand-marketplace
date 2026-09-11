import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0E7C57);
  static const Color primaryLight = Color(0xFF3E9C78);
  static const Color primaryDark = Color(0xFF0A5A3F);

  static const Color accent = Color(0xFFD4553E);
  static const Color success = Color(0xFF0E7C57);
  static const Color warning = Color(0xFFC98A12);
  static const Color error = Color(0xFFC9432E);
  static const Color info = Color(0xFF0E7C57);

  static const Color cobalt = Color(0xFF0E7C57);
  static const Color sun = Color(0xFFE2A01E);
  static const Color sunDeep = Color(0xFFC98A12);
  static const Color coral = Color(0xFFD4553E);
  static const Color palm = Color(0xFF0E7C57);
  static const Color ink = Color(0xFF101214);

  static const Color lightBackground = Color(0xFFF6F6F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFECECE8);

  static const Color lightTextPrimary = Color(0xFF101214);
  static const Color lightTextSecondary = Color(0xFF6C6F73);
  static const Color lightTextTertiary = Color(0xFF9A9DA0);

  static const Color textOnPrimary = Colors.white;

  static const Color lightBorder = Color(0xFFE4E4E0);
  static const Color lightBorderLight = Color(0xFFEEEEEA);
  static const Color borderStrong = Color(0xFF101214);

  static const Color darkBackground = Color(0xFF0D0F10);
  static const Color darkSurface = Color(0xFF17191B);
  static const Color darkSurfaceVariant = Color(0xFF1F2224);
  static const Color darkBorder = Color(0xFF2B2E31);
  static const Color darkTextPrimary = Color(0xFFEDEDEA);
  static const Color darkTextSecondary = Color(0xFFA2A5A8);
  static const Color darkTextTertiary = Color(0xFF6F7376);
  static const Color cobaltLift = Color(0xFF34B886);

  @Deprecated(
    'light-theme literal. On a themed surface use '
    'context.pageBackground (lib/core/theme/theme_colors.dart). Only correct '
    'when the surface beneath is pinned light in BOTH themes — say so with '
    'AppColors.lightBackground.',
  )
  static const Color background = lightBackground;

  @Deprecated(
    'light-theme literal. On a themed surface use '
    'context.cardSurface. Only correct when the surface beneath is pinned '
    'light in BOTH themes (e.g. a chip over a photo) — say so with '
    'AppColors.lightSurface.',
  )
  static const Color surface = lightSurface;

  @Deprecated(
    'light-theme literal. On a themed surface use '
    'context.altSurface. If genuinely pinned light, say so with '
    'AppColors.lightSurfaceVariant.',
  )
  static const Color surfaceVariant = lightSurfaceVariant;

  @Deprecated(
    'This is #182238 — the EXACT colour of the dark theme card '
    '(darkSurface). Text painted with it on a dark card is invisible, not '
    'merely low-contrast; that is the bug. Use context.textPrimary, or '
    'Theme.of(context).textTheme.* which already carries the right colour. '
    'If the surface beneath is pinned light in BOTH themes, say so with '
    'AppColors.lightTextPrimary.',
  )
  static const Color textPrimary = lightTextPrimary;

  @Deprecated(
    'light-theme literal. Use context.textSecondary. If pinned '
    'light, say so with AppColors.lightTextSecondary.',
  )
  static const Color textSecondary = lightTextSecondary;

  @Deprecated(
    'light-theme literal. Use context.textTertiary. If pinned '
    'light, say so with AppColors.lightTextTertiary.',
  )
  static const Color textTertiary = lightTextTertiary;

  @Deprecated(
    'light-theme literal. Use context.hairline. If pinned light, '
    'say so with AppColors.lightBorder.',
  )
  static const Color border = lightBorder;

  @Deprecated(
    'light-theme literal. Use context.hairlineSoft. If pinned '
    'light, say so with AppColors.lightBorderLight.',
  )
  static const Color borderLight = lightBorderLight;

  static const Color selfPickup = Color(0xFF0E7C57);
  static const Color locker = Color(0xFFC98A12);

  static const Color statusOnline = Color(0xFF0E7C57);
  static const Color statusOffline = Color(0xFF9A9DA0);
  static const Color statusBusy = Color(0xFFC98A12);

  static const Color shimmerBase = Color(0xFFECECE8);
  static const Color shimmerHighlight = Color(0xFFF6F6F4);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF101214), Color(0xFF2B2E31)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static Color shadowColor = const Color(0xFF101214).withValues(alpha: 0.10);
  static Color shadowColorDark = const Color(
    0xFF101214,
  ).withValues(alpha: 0.20);

  static const List<Color> shiftingGradientColors = [
    Color(0xFF0E7C57),
    Color(0xFF0A5A3F),
    Color(0xFF101214),
    Color(0xFF2B2E31),
    Color(0xFF3E9C78),
    Color(0xFF0E7C57),
  ];

  static const LinearGradient luxuryGradient1 = LinearGradient(
    colors: [Color(0xFF0E7C57), Color(0xFF3E9C78)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient luxuryGradient2 = LinearGradient(
    colors: [Color(0xFF101214), Color(0xFF2B2E31)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient luxuryGradient3 = LinearGradient(
    colors: [Color(0xFF101214), Color(0xFF0E7C57)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient luxuryGradient4 = LinearGradient(
    colors: [Color(0xFF0E7C57), Color(0xFF0A5A3F)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static Color glassBg = Colors.white.withValues(alpha: 0.82);
  static Color glassBgDark = const Color(0xFF0D0F10).withValues(alpha: 0.78);
  static Color glassBorder = const Color(0xFF101214).withValues(alpha: 0.10);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.10);
  static const double glassBlur = 10.0;

  static List<BoxShadow> offsetShadow({
    Color color = const Color(0xFF101214),
    double dx = 0,
    double dy = 6,
    double alpha = 0.14,
  }) => [
    BoxShadow(
      color: const Color(0xFF101214).withValues(alpha: alpha * 0.5),
      offset: const Offset(0, 6),
      blurRadius: 20,
    ),
    BoxShadow(
      color: const Color(0xFF101214).withValues(alpha: alpha * 0.25),
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: const Color(0xFF101214).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF101214).withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF101214).withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class AppRadius {
  static const double chip = 18;
  static const double tag = 8;
  static const double card = 18;
  static const double input = 14;
  static const double sheet = 28;
  static const double pill = 999;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius chipR = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius sheetR = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius inputR = BorderRadius.all(Radius.circular(input));
}
