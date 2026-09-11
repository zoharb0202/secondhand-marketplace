import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secondhand_marketplace/core/widgets/stream_error_view.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );

  group('StreamErrorView', () {
    testWidgets('shows the Hebrew headline it was given, not the exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          StreamErrorView(
            error: Exception(
              '[cloud_firestore/unavailable] backend unreachable',
            ),
            title: 'לא הצלחנו לטעון את ההזמנות',
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('לא הצלחנו לטעון את ההזמנות'), findsOneWidget);

      final rawLine = tester.widget<Text>(
        find.text(
          'Exception: [cloud_firestore/unavailable] backend unreachable',
        ),
      );
      expect(rawLine.style?.fontSize, 10);
      expect(rawLine.maxLines, 4);
    });

    testWidgets('a dropped connection and a denied read say different things', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          StreamErrorView(
            error: Exception(
              '[cloud_firestore/unavailable] backend unreachable',
            ),
            onRetry: () {},
          ),
        ),
      );
      expect(find.text('בדקו את החיבור לאינטרנט ונסו שוב.'), findsOneWidget);

      await tester.pumpWidget(
        host(
          StreamErrorView(
            error: Exception(
              '[cloud_firestore/permission-denied] Missing or insufficient permissions',
            ),
            onRetry: () {},
          ),
        ),
      );
      expect(find.text('החיבור לשרת נותק. נסו שוב.'), findsOneWidget);
    });

    testWidgets('the retry button fires the callback the screen supplied', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(StreamErrorView(error: Exception('boom'), onRetry: () => taps++)),
      );

      await tester.tap(find.text('נסו שוב'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('compact variant lays out inside an UNBOUNDED Column', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                StreamErrorView.compact(
                  error: Exception('boom'),
                  title: 'לא הצלחנו לטעון את הביקורות',
                  onRetry: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('לא הצלחנו לטעון את הביקורות'), findsOneWidget);
      expect(find.text('נסו שוב'), findsOneWidget);
    });

    testWidgets('page variant fills a bounded Scaffold body without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          StreamErrorView(
            error: Exception('boom'),
            title: 'לא הצלחנו לטעון את המוצרים',
            onRetry: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('לא הצלחנו לטעון את המוצרים'), findsOneWidget);
    });

    testWidgets('a caller-supplied message wins over the derived one', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          StreamErrorView(
            error: Exception('[cloud_firestore/permission-denied] nope'),
            title: 'לא הצלחנו לטעון את הקופונים',
            message:
                'עדיין אין הרשאה להציג את הקופונים שלך. נסו שוב מאוחר יותר.',
            onRetry: () {},
          ),
        ),
      );

      expect(
        find.text('עדיין אין הרשאה להציג את הקופונים שלך. נסו שוב מאוחר יותר.'),
        findsOneWidget,
      );
      expect(find.text('החיבור לשרת נותק. נסו שוב.'), findsNothing);
    });
  });

  group('isPermissionDeniedError', () {
    test('matches the cloud_firestore denial in both its shapes', () {
      expect(
        isPermissionDeniedError(
          Exception(
            '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
          ),
        ),
        isTrue,
      );
      expect(isPermissionDeniedError('permission-denied'), isTrue);
      expect(
        isPermissionDeniedError(
          Exception('[cloud_firestore/unavailable] backend unreachable'),
        ),
        isFalse,
      );
      expect(isPermissionDeniedError(null), isFalse);
    });
  });
}
