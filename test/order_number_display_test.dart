import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secondhand_marketplace/shared/models/order_number.dart';

void main() {
  group('orderNumberDisplay', () {
    test(
      'null/empty/whitespace-only all return null — the render-nothing contract',
      () {
        expect(orderNumberDisplay(null), isNull);
        expect(orderNumberDisplay(''), isNull);
        expect(orderNumberDisplay('   '), isNull);
      },
    );

    test('wraps a real number in LRI/PDI bidi isolates, payload unchanged', () {
      final result = orderNumberDisplay('AB-142');
      expect(result, '\u{2066}AB-142\u{2069}');
      expect(result, contains('AB-142'));
    });

    test('trims surrounding whitespace before wrapping', () {
      expect(orderNumberDisplay('  AB-142  '), '\u{2066}AB-142\u{2069}');
    });
  });

  group(
    'the shared conditional-render pattern the three display surfaces use',
    () {
      Widget hostWithOrderNumber(String? orderNumber) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                if (orderNumberDisplay(orderNumber) case final n?)
                  Text('$orderNumberLabelHe $n'),
              ],
            ),
          ),
        ),
      );

      testWidgets(
        'no number -> the label never renders at all (no empty row, no dash)',
        (tester) async {
          await tester.pumpWidget(hostWithOrderNumber(null));
          expect(find.textContaining(orderNumberLabelHe), findsNothing);
        },
      );

      testWidgets(
        'a real number -> the Hebrew label and the number both render',
        (tester) async {
          await tester.pumpWidget(hostWithOrderNumber('AB-142'));
          expect(find.textContaining(orderNumberLabelHe), findsOneWidget);
          expect(find.textContaining('AB-142'), findsOneWidget);
        },
      );
    },
  );
}
