import 'package:flutter/material.dart';

import '../constants/layout_constants.dart';

class NavBarClearance {
  const NavBarClearance._();

  static bool appliesTo(BuildContext context) =>
      ModalRoute.of(context)?.isFirst ?? false;

  static double of(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    if (!appliesTo(context)) return safeBottom;
    return safeBottom + AppLayout.navBarHeight + AppLayout.navBarBottomMargin;
  }

  static EdgeInsets pad(
    BuildContext context, {
    EdgeInsets base = EdgeInsets.zero,
  }) => base.copyWith(bottom: base.bottom + of(context));
}

class NavBarClearanceGap extends StatelessWidget {
  const NavBarClearanceGap({super.key, this.extra = 0});

  final double extra;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: NavBarClearance.of(context) + extra);
}

class NavBarClearanceInset extends StatelessWidget {
  const NavBarClearanceInset({super.key, required this.child, this.extra = 0});

  final Widget child;
  final double extra;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: NavBarClearance.of(context) + extra),
    child: child,
  );
}
