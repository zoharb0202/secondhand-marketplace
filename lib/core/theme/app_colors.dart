import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2749C9);
  static const Color primaryLight = Color(0xFF5B7BFF);
  static const Color primaryDark = Color(0xFF1B3390);

  static const Color accent = Color(0xFFE75A4E);
  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFE8930C);
  static const Color error = Color(0xFFD64430);
  static const Color info = Color(0xFF2749C9);

  static const Color cobalt = Color(0xFF2749C9);
  static const Color sun = Color(0xFFF5A623);
  static const Color sunDeep = Color(0xFFE8930C);
  static const Color coral = Color(0xFFE75A4E);
  static const Color palm = Color(0xFF2E7D5B);
  static const Color ink = Color(0xFF182238);

  static const Color lightBackground = Color(0xFFF9F8F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1EFE8);

  static const Color lightTextPrimary = Color(0xFF182238);
  static const Color lightTextSecondary = Color(0xFF5A6472);
  static const Color lightTextTertiary = Color(0xFF95A0B0);

  static const Color textOnPrimary = Colors.white;

  static const Color lightBorder = Color(0xFFD9D6CC);
  static const Color lightBorderLight = Color(0xFFEBE8DF);
  static const Color borderStrong = Color(0xFF182238);

  static const Color darkBackground = Color(0xFF10141F);
  static const Color darkSurface = Color(0xFF182238);
  static const Color darkSurfaceVariant = Color(0xFF1E2A44);
  static const Color darkBorder = Color(0xFF2A3550);
  static const Color darkTextPrimary = Color(0xFFEDEFF5);
  static const Color darkTextSecondary = Color(0xFF9AA4BC);
  static const Color darkTextTertiary = Color(0xFF6B7695);
  static const Color cobaltLift = Color(0xFF5B7BFF);

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

  static const Color selfPickup = Color(0xFF2E7D5B);
  static const Color locker = Color(0xFFE8930C);

  static const Color statusOnline = Color(0xFF2E7D5B);
  static const Color statusOffline = Color(0xFF95A0B0);
  static const Color statusBusy = Color(0xFFE8930C);

  static const Color shimmerBase = Color(0xFFECEAE2);
  static const Color shimmerHighlight = Color(0xFFF9F8F4);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFE75A4E), Color(0xFFE8930C)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static Color shadowColor = const Color(0xFF182238).withValues(alpha: 0.10);
  static Color shadowColorDark = const Color(
    0xFF182238,
  ).withValues(alpha: 0.20);

  static const List<Color> shiftingGradientColors = [
    Color(0xFF2749C9),
    Color(0xFF5B7BFF),
    Color(0xFF2E7D5B),
    Color(0xFFE8930C),
    Color(0xFFE75A4E),
    Color(0xFF2749C9),
  ];

  static const LinearGradient luxuryGradient1 = LinearGradient(
    colors: [Color(0xFF2749C9), Color(0xFF5B7BFF)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient luxuryGradient2 = LinearGradient(
    colors: [Color(0xFFE75A4E), Color(0xFFE8930C)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient luxuryGradient3 = LinearGradient(
    colors: [Color(0xFF2749C9), Color(0xFF2E7D5B)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient luxuryGradient4 = LinearGradient(
    colors: [Color(0xFF2E7D5B), Color(0xFF1F5E43)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static Color glassBg = Colors.white.withValues(alpha: 0.82);
  static Color glassBgDark = const Color(0xFF10141F).withValues(alpha: 0.78);
  static Color glassBorder = const Color(0xFF182238).withValues(alpha: 0.10);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.10);
  static const double glassBlur = 10.0;

  static List<BoxShadow> offsetShadow({
    Color color = const Color(0xFF2749C9),
    double dx = -4,
    double dy = 4,
    double alpha = 0.14,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      offset: Offset(dx, dy),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: const Color(0xFF182238).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF182238).withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF182238).withValues(alpha: 0.06),
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
  static const double chip = 6;
  static const double tag = 4;
  static const double card = 10;
  static const double sheet = 20;
  static const double pill = 999;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius chipR = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius sheetR = BorderRadius.all(Radius.circular(sheet));
}
