import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Brand mark: two overlapping rounded squares (a "passed on" object),
/// ink and emerald, with the shared area in a deep green.
class AppLogoMark extends StatelessWidget {
  final double size;
  final bool onDark;

  const AppLogoMark({super.key, this.size = 30, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(onDark: onDark)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final bool onDark;

  _MarkPainter({required this.onDark});

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 30;
    RRect r(double x, double y) => RRect.fromRectAndRadius(
      Rect.fromLTWH(x * k, y * k, 17 * k, 17 * k),
      Radius.circular(5 * k),
    );
    final back = Path()..addRRect(r(2, 7));
    final front = Path()..addRRect(r(11, 2));
    canvas.drawPath(
      back,
      Paint()..color = onDark ? Colors.white : AppColors.ink,
    );
    canvas.drawPath(front, Paint()..color = AppColors.primary);
    canvas.drawPath(
      Path.combine(PathOperation.intersect, back, front),
      Paint()
        ..color = onDark ? const Color(0xFF7FD3B2) : const Color(0xFF0A4F37),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.onDark != onDark;
}

/// Mark + "secondhand" wordmark.
class AppLogo extends StatelessWidget {
  final double markSize;
  final double fontSize;
  final bool onDark;
  final bool showTagline;

  const AppLogo({
    super.key,
    this.markSize = 30,
    this.fontSize = 18,
    this.onDark = false,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = onDark || Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    return Semantics(
      label: 'Secondhand Marketplace',
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(size: markSize, onDark: isDark),
            SizedBox(width: markSize * 0.3),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'secondhand',
                  textDirection: TextDirection.ltr,
                  style: GoogleFonts.miriamLibre(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.0,
                    color: ink,
                  ),
                ),
                if (showTagline)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'MARKETPLACE',
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.ibmPlexSansHebrew(
                        fontSize: fontSize * 0.42,
                        fontWeight: FontWeight.w600,
                        letterSpacing: fontSize * 0.14,
                        height: 1.0,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
