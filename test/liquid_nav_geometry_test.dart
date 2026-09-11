import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/widgets/liquid_nav/liquid_nav_geometry.dart';

void main() {
  group('LiquidNavGeometry — RTL notch position (the bug this file guards)', () {
    test(
      '6 items, 360dp phone (328dp bar): index 0 sits on the RIGHT, not the left',
      () {
        final geo = LiquidNavGeometry(
          width: 328,
          itemCount: 6,
          direction: TextDirection.rtl,
        );
        const expected = [289.0, 239.0, 189.0, 139.0, 89.0, 39.0];
        for (var i = 0; i < 6; i++) {
          expect(
            geo.cxFor(i.toDouble()),
            closeTo(expected[i], 1e-9),
            reason: 'slot $i',
          );
        }
        expect(geo.cxFor(0), greaterThan(geo.cxFor(5)));
      },
    );

    test('LTR is the mirror image of RTL for every slot', () {
      const width = 328.0;
      for (final n in [3, 4, 6]) {
        final rtl = LiquidNavGeometry(
          width: width,
          itemCount: n,
          direction: TextDirection.rtl,
        );
        final ltr = LiquidNavGeometry(
          width: width,
          itemCount: n,
          direction: TextDirection.ltr,
        );
        for (var i = 0; i < n; i++) {
          expect(
            ltr.cxFor(i.toDouble()),
            closeTo(width - rtl.cxFor(i.toDouble()), 1e-9),
            reason: 'n=$n i=$i',
          );
        }
      }
    });
  });

  group('LiquidNavGeometry — cxFor is continuous and monotone', () {
    test('moving indexValue by a small step moves cx monotonically', () {
      final geo = LiquidNavGeometry(
        width: 328,
        itemCount: 6,
        direction: TextDirection.rtl,
      );
      double? previous;
      for (var step = 0; step <= 500; step++) {
        final v = step / 100.0;
        final cx = geo.cxFor(v);
        if (previous != null) {
          expect(
            cx,
            lessThanOrEqualTo(previous),
            reason: 'v=$v should not move cx backward for RTL',
          );
        }
        previous = cx;
      }
    });

    test('cxFor clamps indexValue to [0, itemCount - 1]', () {
      final geo = LiquidNavGeometry(
        width: 328,
        itemCount: 6,
        direction: TextDirection.rtl,
      );
      expect(geo.cxFor(-1), equals(geo.cxFor(0)));
      expect(geo.cxFor(-100), equals(geo.cxFor(0)));
      expect(geo.cxFor(5), equals(geo.cxFor(5)));
      expect(geo.cxFor(6), equals(geo.cxFor(5)));
      expect(geo.cxFor(999), equals(geo.cxFor(5)));
    });
  });

  group('LiquidNavGeometry — disc radius clamp', () {
    test(
      'engages the UPPER bound: 3 wide slots at 360dp would else be a beach ball',
      () {
        final geo = LiquidNavGeometry(
          width: 328,
          itemCount: 3,
          direction: TextDirection.rtl,
        );
        expect(geo.slotWidth, closeTo(100.0, 1e-9));
        expect(geo.discRadius, closeTo(24.0, 1e-9));
        expect(geo.notchRadius, closeTo(29.0, 1e-9));
      },
    );

    test(
      'engages the LOWER bound: 6 narrow slots on a folded-cover phone would else be illegible',
      () {
        final geo = LiquidNavGeometry(
          width: 248,
          itemCount: 6,
          direction: TextDirection.rtl,
        );
        expect(geo.slotWidth, closeTo(36.6667, 1e-3));
        expect(geo.discRadius, closeTo(18.0, 1e-9));
        expect(geo.notchRadius, closeTo(23.0, 1e-9));
      },
    );
  });

  group(
    'LiquidNavGeometry — no overflow at any real width/role combination',
    () {
      test('outermost notch never reaches more than 6dp past the bar edge', () {
        for (final screenWidth in [280.0, 320.0, 360.0, 412.0, 480.0]) {
          final barWidth = screenWidth - 32;
          for (final n in [3, 4, 6]) {
            for (final direction in [TextDirection.rtl, TextDirection.ltr]) {
              final geo = LiquidNavGeometry(
                width: barWidth,
                itemCount: n,
                direction: direction,
              );
              for (var i = 0; i < n; i++) {
                final cx = geo.cxFor(i.toDouble());
                final wn = geo.notchHalfExtent;
                expect(
                  cx - wn,
                  greaterThan(-6.0),
                  reason: 'screen=$screenWidth n=$n i=$i left overhang',
                );
                expect(
                  cx + wn,
                  lessThan(barWidth + 6.0),
                  reason: 'screen=$screenWidth n=$n i=$i right overhang',
                );
              }
            }
          }
        }
      });
    },
  );

  group('LiquidNavGeometry — riseFor', () {
    test('is 1.0 exactly on the travelling index and falls off linearly', () {
      final geo = LiquidNavGeometry(
        width: 328,
        itemCount: 6,
        direction: TextDirection.rtl,
      );
      expect(geo.riseFor(2, 2.0), closeTo(1.0, 1e-9));
      expect(geo.riseFor(2, 2.5), closeTo(0.5, 1e-9));
      expect(geo.riseFor(2, 3.0), closeTo(0.0, 1e-9));
      expect(geo.riseFor(2, 0.0), closeTo(0.0, 1e-9));
    });
  });
}
