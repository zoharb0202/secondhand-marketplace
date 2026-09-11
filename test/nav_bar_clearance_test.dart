import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/constants/layout_constants.dart';
import 'package:secondhand_marketplace/core/widgets/nav_bar_clearance.dart';

void main() {
  void setBottomInset(WidgetTester tester, double bottom) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(bottom: bottom);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
  }

  testWidgets(
    'on the FIRST route, clearance = padding.bottom + occupied bar height + its margin (86 + 8 + 24 = 118)',
    (tester) async {
      setBottomInset(tester, 24);
      double? clearance;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              clearance = NavBarClearance.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        clearance,
        24 + AppLayout.navBarHeight + AppLayout.navBarBottomMargin,
      );
      expect(clearance, 118);
    },
  );

  testWidgets(
    'on a PUSHED route, clearance degrades to exactly the OS inset and nothing more',
    (tester) async {
      setBottomInset(tester, 24);
      double? pushedClearance;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      pushedClearance = NavBarClearance.of(context);
                      return const SizedBox();
                    },
                  ),
                ),
                child: const Text('push'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      expect(pushedClearance, 24);
    },
  );
}
