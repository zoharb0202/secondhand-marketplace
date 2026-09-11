import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/constants/layout_constants.dart';
import 'package:secondhand_marketplace/core/widgets/liquid_nav/liquid_nav_bar.dart';
import 'package:secondhand_marketplace/core/widgets/liquid_nav/liquid_notched_bar_border.dart';
import 'package:secondhand_marketplace/core/widgets/liquid_nav/nav_item.dart';

void main() {
  List<NavItem> sixCustomerItems({int badgeOn4 = 0}) => [
    NavItem(Icons.home_outlined, Icons.home_rounded, 'בית'),
    NavItem(Icons.search_outlined, Icons.search_rounded, 'חיפוש'),
    NavItem(Icons.add_rounded, Icons.add_rounded, 'הוסף'),
    NavItem(Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'עגלה'),
    NavItem(
      Icons.chat_bubble_outline,
      Icons.chat_bubble_rounded,
      'הודעות',
      badge: badgeOn4,
    ),
    NavItem(Icons.person_outline, Icons.person_rounded, 'פרופיל'),
  ];

  Widget host({
    required double width,
    required List<NavItem> items,
    required int selectedIndex,
    ValueChanged<int>? onSelect,
    int? addActionIndex,
    VoidCallback? onAddAction,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: width,
              child: LiquidNavBar(
                items: items,
                selectedIndex: selectedIndex,
                onSelect: onSelect ?? (_) {},
                addActionIndex: addActionIndex,
                onAddAction: onAddAction,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('LiquidNavBar — RTL tap-to-index (the bug this bar must not repeat)', () {
    testWidgets(
      'tapping each of 6 slots at 328dp selects indices 0..5 in RTL order — via REAL hit-testing, not the geometry formula',
      (tester) async {
        final taps = <int>[];
        await tester.pumpWidget(
          host(
            width: 328,
            items: sixCustomerItems(),
            selectedIndex: 0,
            onSelect: taps.add,
          ),
        );
        await tester.pumpAndSettle();

        const expectedCx = [289.0, 239.0, 189.0, 139.0, 89.0, 39.0];
        final topLeft = tester.getTopLeft(find.byType(LiquidNavBar));
        for (var i = 0; i < 6; i++) {
          await tester.tapAt(topLeft + Offset(expectedCx[i], 50));
          await tester.pump();
        }

        expect(taps, [0, 1, 2, 3, 4, 5]);
      },
    );
  });

  group('LiquidNavBar — the merged add slot', () {
    testWidgets('tapping the add slot fires onAddAction and NEVER onSelect', (
      tester,
    ) async {
      final selects = <int>[];
      var addTaps = 0;
      await tester.pumpWidget(
        host(
          width: 328,
          items: sixCustomerItems(),
          selectedIndex: 0,
          onSelect: selects.add,
          addActionIndex: 2,
          onAddAction: () => addTaps++,
        ),
      );
      await tester.pumpAndSettle();

      final topLeft = tester.getTopLeft(find.byType(LiquidNavBar));
      await tester.tapAt(topLeft + const Offset(189.0, 50));
      await tester.pump();

      expect(addTaps, 1);
      expect(selects, isEmpty);
    });

    testWidgets('the other 5 slots are unaffected by addActionIndex', (
      tester,
    ) async {
      final selects = <int>[];
      await tester.pumpWidget(
        host(
          width: 328,
          items: sixCustomerItems(),
          selectedIndex: 0,
          onSelect: selects.add,
          addActionIndex: 2,
          onAddAction: () {},
        ),
      );
      await tester.pumpAndSettle();

      final topLeft = tester.getTopLeft(find.byType(LiquidNavBar));
      await tester.tapAt(topLeft + const Offset(89.0, 50));
      await tester.pump();

      expect(selects, [4]);
    });
  });

  group('LiquidNavBar — occupied height', () {
    testWidgets(
      'height equals AppLayout.navBarHeight, so the widget and the clearance constant cannot silently drift apart',
      (tester) async {
        await tester.pumpWidget(
          host(width: 328, items: sixCustomerItems(), selectedIndex: 0),
        );
        await tester.pumpAndSettle();

        final size = tester.getSize(find.byType(LiquidNavBar));
        expect(size.height, AppLayout.navBarHeight);
      },
    );
  });

  group('LiquidNavBar — no overflow at real widths, every role item count', () {
    for (final screenWidth in [280.0, 320.0, 360.0, 412.0]) {
      for (final n in [3, 4, 6]) {
        testWidgets('screen=$screenWidth n=$n', (tester) async {
          final items = List.generate(
            n,
            (i) => NavItem(Icons.circle_outlined, Icons.circle, 'פריט $i'),
          );
          await tester.pumpWidget(
            host(
              width: screenWidth - 32,
              items: items,
              selectedIndex: 0,
              addActionIndex: n == 6 ? 2 : null,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('LiquidNavBar — labels are active-item-only', () {
    testWidgets('exactly one Text renders, for the selected slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(width: 328, items: sixCustomerItems(), selectedIndex: 3),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Text), findsOneWidget);
      expect(find.text('עגלה'), findsOneWidget);
    });
  });

  group('LiquidNavBar — badges survive the rise', () {
    testWidgets('a badge > 0 renders even when its item is the active one', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          width: 328,
          items: sixCustomerItems(badgeOn4: 3),
          selectedIndex: 4,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('liquid-nav-badge-4')), findsWidgets);
    });

    testWidgets('no badge renders when the count is 0', (tester) async {
      await tester.pumpWidget(
        host(width: 328, items: sixCustomerItems(), selectedIndex: 4),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('liquid-nav-badge-4')), findsNothing);
    });
  });

  group('LiquidNavBar — both themes render without exception', () {
    for (final entry in {
      'light': ThemeData.light(),
      'dark': ThemeData.dark(),
    }.entries) {
      testWidgets('${entry.key}: no exception, correct height', (tester) async {
        await tester.pumpWidget(
          host(
            width: 328,
            items: sixCustomerItems(),
            selectedIndex: 2,
            addActionIndex: 2,
            theme: entry.value,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(LiquidNavBar)).height,
          AppLayout.navBarHeight,
        );
      });
    }

    testWidgets(
      'the bar frame colour is never equal to the bar fill colour, in either theme',
      (tester) async {
        for (final theme in [ThemeData.light(), ThemeData.dark()]) {
          await tester.pumpWidget(
            host(
              width: 328,
              items: sixCustomerItems(),
              selectedIndex: 0,
              theme: theme,
            ),
          );
          await tester.pumpAndSettle();

          final decoratedBox = tester.widget<DecoratedBox>(
            find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is ShapeDecoration &&
                  (w.decoration as ShapeDecoration).shape
                      is LiquidNotchedBarBorder,
            ),
          );
          final decoration = decoratedBox.decoration as ShapeDecoration;
          final shape = decoration.shape as LiquidNotchedBarBorder;
          final fill = decoration.color;
          final frame = shape.side.color;

          expect(fill, isNotNull);
          expect(
            frame,
            isNot(equals(fill)),
            reason:
                'bar fill and frame must differ — an equal pair is a regression '
                '(borderStrong on the exact dark-surface hex) verbatim',
          );
        }
      },
    );
  });
}
