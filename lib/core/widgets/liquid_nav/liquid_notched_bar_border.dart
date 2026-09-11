import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class LiquidNotchedBarBorder extends ShapeBorder {
  const LiquidNotchedBarBorder({
    required this.notchCenterX,
    required this.notchRadius,
    required this.cornerRadius,
    this.side = BorderSide.none,
  });

  final double notchCenterX;

  final double notchRadius;

  final double cornerRadius;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) => LiquidNotchedBarBorder(
    notchCenterX: notchCenterX * t,
    notchRadius: notchRadius * t,
    cornerRadius: cornerRadius * t,
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is LiquidNotchedBarBorder) {
      return LiquidNotchedBarBorder(
        notchCenterX: lerpDouble(a.notchCenterX, notchCenterX, t)!,
        notchRadius: lerpDouble(a.notchRadius, notchRadius, t)!,
        cornerRadius: lerpDouble(a.cornerRadius, cornerRadius, t)!,
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is LiquidNotchedBarBorder) {
      return LiquidNotchedBarBorder(
        notchCenterX: lerpDouble(notchCenterX, b.notchCenterX, t)!,
        notchRadius: lerpDouble(notchRadius, b.notchRadius, t)!,
        cornerRadius: lerpDouble(cornerRadius, b.cornerRadius, t)!,
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _pathFor(rect.deflate(side.width), rect.left + notchCenterX);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _pathFor(rect, rect.left + notchCenterX);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final strokeRect = rect.deflate(side.width / 2);
    final path = _pathFor(strokeRect, rect.left + notchCenterX);
    canvas.drawPath(path, side.toPaint());
  }

  Path _pathFor(Rect rect, double cx) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)));
    if (notchRadius <= 0) return body;
    return Path.combine(PathOperation.difference, body, _cutter(rect.top, cx));
  }

  Path _cutter(double top, double cx) {
    final r = notchRadius;
    const s2 = 1.0;
    final s1 = 0.48 * r;
    final p2x = -r * r / (r + s2);
    final p2y = r * math.sqrt(s2 * (2 * r + s2)) / (r + s2);
    final wn = r + s2 + s1;
    return Path()
      ..moveTo(cx - wn, top - 1)
      ..lineTo(cx - wn, top)
      ..quadraticBezierTo(cx - (r + s2), top, cx + p2x, top + p2y)
      ..arcToPoint(
        Offset(cx - p2x, top + p2y),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..quadraticBezierTo(cx + (r + s2), top, cx + wn, top)
      ..lineTo(cx + wn, top - 1)
      ..close();
  }
}

class LiquidBarClipper extends CustomClipper<Path> {
  const LiquidBarClipper({required this.border, required this.barTop});

  final LiquidNotchedBarBorder border;
  final double barTop;

  @override
  Path getClip(Size size) => border.getOuterPath(
    Rect.fromLTWH(0, barTop, size.width, size.height - barTop),
  );

  @override
  bool shouldReclip(covariant LiquidBarClipper oldClipper) =>
      oldClipper.barTop != barTop ||
      oldClipper.border.notchCenterX != border.notchCenterX ||
      oldClipper.border.notchRadius != border.notchRadius ||
      oldClipper.border.cornerRadius != border.cornerRadius;
}

class LiquidDiscClipper extends CustomClipper<Path> {
  const LiquidDiscClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant LiquidDiscClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}
