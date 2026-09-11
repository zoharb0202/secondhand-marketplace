import 'package:flutter/widgets.dart';

class NavItem {
  NavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});

  final IconData icon;

  final IconData activeIcon;

  final String label;
  final int badge;
}
