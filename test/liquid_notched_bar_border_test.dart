import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/widgets/liquid_nav/liquid_nav_geometry.dart';
import 'package:secondhand_marketplace/core/widgets/liquid_nav/liquid_notched_bar_border.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 328, 62);
  const slotWidth = 50.0;
  const notchRadius = 28.0;
  const cornerRadius = 10.0;

  group('LiquidNotchedBarBorder — the cut is a genuine hole in the path', () {
    test('directly under the notch centre, material is REMOVED', () {
      const cx = 189.0;
      final path = LiquidNotchedBarBorder(
        notchCenterX: cx,
        notchRadius: notchRadius,
        cornerRadius: cornerRadius,
      ).getOuterPath(rect);

      expect(
        path.contains(const Offset(cx, notchRadius - 2)),
        isFalse,
        reason: 'the belly of the carved notch must be a real hole',
      );
    });

    test('one full slot away, the bar is still solid', () {
      const cx = 189.0;
      final path = LiquidNotchedBarBorder(
        notchCenterX: cx,
        notchRadius: notchRadius,
        cornerRadius: cornerRadius,
      ).getOuterPath(rect);

      expect(
        path.contains(const Offset(cx + slotWidth, notchRadius - 2)),
        isTrue,
        reason: 'a neighbouring slot must not be carved away too',
      );
    });

    test('the notch never cuts all the way through the bar', () {
      const cx = 189.0;
      final path = LiquidNotchedBarBorder(
        notchCenterX: cx,
        notchRadius: notchRadius,
        cornerRadius: cornerRadius,
      ).getOuterPath(rect);

      expect(
        path.contains(Offset(cx, rect.bottom - 4)),
        isTrue,
        reason: 'the bar must stay a full-height strip below the notch',
      );
    });

    test('THE NOTCH TRAVELS: moving the centre swaps which slot is carved', () {
      const cxLeft = 189.0;
      const cxRight = 239.0;

      final pathAtLeft = LiquidNotchedBarBorder(
        notchCenterX: cxLeft,
        notchRadius: notchRadius,
        cornerRadius: cornerRadius,
      ).getOuterPath(rect);
      final pathAtRight = LiquidNotchedBarBorder(
        notchCenterX: cxRight,
        notchRadius: notchRadius,
        cornerRadius: cornerRadius,
      ).getOuterPath(rect);

      const probeLeft = Offset(cxLeft, notchRadius - 2);
      const probeRight = Offset(cxRight, notchRadius - 2);

      expect(pathAtLeft.contains(probeLeft), isFalse);
      expect(pathAtLeft.contains(probeRight), isTrue);

      expect(pathAtRight.contains(probeLeft), isTrue);
      expect(pathAtRight.contains(probeRight), isFalse);
    });

    test('the notch maths is relative to rect.top, not a hardcoded 0', () {
      final shiftedRect = rect.shift(const Offset(0, 24));
      const cx = 189.0;
      final path = LiquidNotchedBarBorder(
        notchCenterX: cx,
        notchRadius: notchRadius,
        cornerRadius: cornerRadius,
      ).getOuterPath(shiftedRect);

      expect(
        path.contains(Offset(cx, shiftedRect.top + notchRadius - 2)),
        isFalse,
      );
      expect(
        path.contains(
          Offset(cx + slotWidth, shiftedRect.top + notchRadius - 2),
        ),
        isTrue,
      );
    });
  });

  group('LiquidNotchedBarBorder — notchRadius <= 0 disables the cut', () {
    test('degrades to a plain rounded rect with no hole anywhere', () {
      final path = const LiquidNotchedBarBorder(
        notchCenterX: 189,
        notchRadius: 0,
        cornerRadius: cornerRadius,
      ).getOuterPath(rect);

      expect(path.contains(const Offset(189, 10)), isTrue);
    });
  });

  group(
    'LiquidNotchedBarBorder — outermost slot does not blow up the path',
    () {
      test(
        '320dp phone, 6 items: bounds stay within the rect (inflated 2dp)',
        () {
          const barWidth = 320.0 - 32.0;
          final geometry = LiquidNavGeometry(
            width: barWidth,
            itemCount: 6,
            direction: TextDirection.rtl,
          );
          final outerRect = Rect.fromLTWH(0, 0, barWidth, 62);
          final cx = geometry.cxFor(5);
          final path = LiquidNotchedBarBorder(
            notchCenterX: cx,
            notchRadius: geometry.notchRadius,
            cornerRadius: cornerRadius,
          ).getOuterPath(outerRect);

          final bounds = path.getBounds();
          expect(bounds.isEmpty, isFalse);
          final inflated = outerRect.inflate(2);
          expect(bounds.left, greaterThanOrEqualTo(inflated.left));
          expect(bounds.top, greaterThanOrEqualTo(inflated.top));
          expect(bounds.right, lessThanOrEqualTo(inflated.right));
          expect(bounds.bottom, lessThanOrEqualTo(inflated.bottom));
        },
      );
    },
  );
}
