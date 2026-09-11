import 'dart:ui' show TextDirection;

class LiquidNavGeometry {
  LiquidNavGeometry({
    required this.width,
    required this.itemCount,
    required this.direction,
    this.sideInset = 14,
  }) : assert(itemCount > 0),
       assert(width > 0),
       slotWidth = (width - 2 * sideInset) / itemCount {
    discRadius = _clampD(slotWidth * 0.46, 18, 24);
    notchRadius = discRadius + 5;
    fillet = notchRadius * 0.48;
    iconSize = _clampD(slotWidth * 0.44, 18, 22);
  }

  final double width;

  final int itemCount;

  final TextDirection direction;

  final double sideInset;

  final double slotWidth;

  late final double discRadius;

  late final double notchRadius;

  late final double fillet;

  late final double iconSize;

  static const double kRise = 24;

  static const double kBarHeight = 62;

  static const double kTotalHeight = kRise + kBarHeight;

  double get notchHalfExtent => notchRadius + 1.0 + fillet;

  double cxFor(double indexValue) {
    final v = _clampD(indexValue, 0, (itemCount - 1).toDouble());
    final offset = (v + 0.5) * slotWidth;
    return direction == TextDirection.rtl
        ? width - sideInset - offset
        : sideInset + offset;
  }

  double riseFor(int i, double indexValue) =>
      _clampD(1 - (indexValue - i).abs(), 0, 1);

  static double _clampD(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);
}
