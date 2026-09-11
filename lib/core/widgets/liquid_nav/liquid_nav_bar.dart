import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import 'liquid_nav_geometry.dart';
import 'liquid_notched_bar_border.dart';
import 'nav_item.dart';

class LiquidNavBar extends StatefulWidget {
  const LiquidNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.addActionIndex,
    this.onAddAction,
  }) : assert(items.length > 0);

  final List<NavItem> items;

  final int selectedIndex;

  final ValueChanged<int> onSelect;

  final int? addActionIndex;

  final VoidCallback? onAddAction;

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<LiquidNavBar>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 260);

  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  late double _animFrom;
  late double _animTo;

  @override
  void initState() {
    super.initState();
    _animFrom = widget.selectedIndex.toDouble();
    _animTo = widget.selectedIndex.toDouble();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..value = 1;
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant LiquidNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _retarget(widget.selectedIndex);
    } else if (widget.items.length != oldWidget.items.length) {
      final maxIndex = widget.items.length - 1;
      final clamped = widget.selectedIndex
          .clamp(0, maxIndex < 0 ? 0 : maxIndex)
          .toDouble();
      _animFrom = clamped;
      _animTo = clamped;
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  double _indexValueAt(double t) {
    final raw = _animFrom + (_animTo - _animFrom) * t;
    final maxIndex = (widget.items.length - 1).toDouble();
    if (raw < 0) return 0;
    if (raw > maxIndex) return maxIndex;
    return raw;
  }

  double get _indexValue => _indexValueAt(_curved.value);

  void _retarget(int to) {
    final current = _indexValue;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _animFrom = current;
    _animTo = to.toDouble();
    _controller
      ..duration = reduceMotion ? Duration.zero : _duration
      ..value = 0
      ..forward();
  }

  void _handleTap(int i) {
    if (widget.addActionIndex != null && i == widget.addActionIndex) {
      widget.onAddAction?.call();
    } else {
      widget.onSelect(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barFill = isDark ? context.cardSurface : AppColors.lightSurface;
    final frameColor = isDark ? context.hairline : AppColors.lightBorder;
    final shadowTint = isDark ? AppColors.cobaltLift : AppColors.cobalt;
    final barShadowAlpha = isDark ? 0.30 : 0.16;
    final discShadowAlpha = isDark ? 0.26 : 0.18;
    final restColor = context.textSecondary;
    final addRestColor = context.accentCobalt;
    final labelColor = context.textPrimary;
    final discFill = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final discIcon = isDark ? AppColors.darkBackground : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final width = constraints.maxWidth;
        final geometry = LiquidNavGeometry(
          width: width,
          itemCount: widget.items.length,
          direction: direction,
        );

        return RepaintBoundary(
          child: SizedBox(
            width: width,
            height: LiquidNavGeometry.kTotalHeight,
            child: AnimatedBuilder(
              animation: _curved,
              builder: (context, _) {
                final indexValue = _indexValue;
                final cx = geometry.cxFor(indexValue);
                final border = LiquidNotchedBarBorder(
                  notchCenterX: cx,
                  notchRadius: geometry.notchRadius,
                  cornerRadius: AppRadius.card,
                  side: BorderSide(color: frameColor, width: 1),
                );
                final ringOuterRadius = geometry.discRadius + 0.5;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: LiquidNavGeometry.kRise,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: barFill,
                          shadows: AppColors.offsetShadow(
                            color: shadowTint,
                            alpha: barShadowAlpha,
                          ),
                          shape: border,
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: ClipPath(
                        clipBehavior: Clip.antiAlias,
                        clipper: LiquidBarClipper(
                          border: border,
                          barTop: LiquidNavGeometry.kRise,
                        ),
                        child: _NavIcons(
                          items: widget.items,
                          geometry: geometry,
                          indexValue: indexValue,
                          selectedIndex: widget.selectedIndex,
                          iconColorOf: (i) => i == widget.addActionIndex
                              ? addRestColor
                              : restColor,
                          badgeRingColor: barFill,
                          showLabels: true,
                          labelColor: labelColor,
                          useActiveGlyph: false,
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: cx - ringOuterRadius,
                            top: LiquidNavGeometry.kRise - ringOuterRadius,
                            width: ringOuterRadius * 2,
                            height: ringOuterRadius * 2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: frameColor, width: 1),
                                boxShadow: AppColors.offsetShadow(
                                  color: shadowTint,
                                  alpha: discShadowAlpha,
                                ),
                              ),
                            ),
                          ),
                          ClipPath(
                            clipBehavior: Clip.antiAlias,
                            clipper: LiquidDiscClipper(
                              center: Offset(cx, LiquidNavGeometry.kRise),
                              radius: geometry.discRadius,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: ColoredBox(color: discFill),
                                ),
                                _NavIcons(
                                  items: widget.items,
                                  geometry: geometry,
                                  indexValue: indexValue,
                                  selectedIndex: widget.selectedIndex,
                                  iconColorOf: (_) => discIcon,
                                  badgeRingColor: discIcon,
                                  showLabels: false,
                                  labelColor: labelColor,
                                  useActiveGlyph: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned.fill(
                      child: _NavHitLayer(
                        geometry: geometry,
                        itemCount: widget.items.length,
                        onTap: _handleTap,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _NavIcons extends StatelessWidget {
  const _NavIcons({
    required this.items,
    required this.geometry,
    required this.indexValue,
    required this.selectedIndex,
    required this.iconColorOf,
    required this.badgeRingColor,
    required this.showLabels,
    required this.labelColor,
    required this.useActiveGlyph,
  });

  final List<NavItem> items;
  final LiquidNavGeometry geometry;
  final double indexValue;
  final int selectedIndex;
  final Color Function(int i) iconColorOf;
  final Color badgeRingColor;
  final bool showLabels;
  final Color labelColor;
  final bool useActiveGlyph;

  static const double _iconRise = 24;
  static const double _restCenterY = LiquidNavGeometry.kRise + _iconRise;
  static const double _labelRestY = LiquidNavGeometry.kRise + 56;
  static const double _labelRiseY = LiquidNavGeometry.kRise + 46;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (int i = 0; i < items.length; i++) ..._buildItem(i),
    ];
    return Stack(clipBehavior: Clip.none, children: children);
  }

  List<Widget> _buildItem(int i) {
    final item = items[i];
    final cx = geometry.cxFor(i.toDouble());
    final t = geometry.riseFor(i, indexValue);
    final iconCenterY = _restCenterY - _iconRise * t;
    final size = geometry.iconSize;
    final color = iconColorOf(i);

    final result = <Widget>[
      Positioned(
        left: cx - size / 2,
        top: iconCenterY - size / 2,
        width: size,
        height: size,
        child: Icon(
          useActiveGlyph ? item.activeIcon : item.icon,
          size: size,
          color: color,
        ),
      ),
    ];

    if (item.badge > 0) {
      result.add(
        Positioned(
          left: cx + size / 2 - 5,
          top: iconCenterY - size / 2 - 5,
          child: Container(
            key: ValueKey('liquid-nav-badge-$i'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.coral,
              shape: BoxShape.circle,
              border: Border.all(color: badgeRingColor, width: 1.5),
            ),
          ),
        ),
      );
    }

    if (showLabels && i == selectedIndex) {
      final labelT = const Interval(
        0.30,
        1.0,
        curve: Curves.easeOut,
      ).transform(t);
      final labelWidth = geometry.slotWidth * 1.6;
      final labelY = _labelRestY - (_labelRestY - _labelRiseY) * labelT;
      result.add(
        Positioned(
          left: cx - labelWidth / 2,
          top: labelY - 7,
          width: labelWidth,
          child: Opacity(
            opacity: labelT,
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.1,
                letterSpacing: 0,
                color: labelColor,
              ),
            ),
          ),
        ),
      );
    }

    return result;
  }
}

class _NavHitLayer extends StatelessWidget {
  const _NavHitLayer({
    required this.geometry,
    required this.itemCount,
    required this.onTap,
  });

  final LiquidNavGeometry geometry;
  final int itemCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 0; i < itemCount; i++)
          Positioned(
            left: geometry.cxFor(i.toDouble()) - geometry.slotWidth / 2,
            top: 0,
            bottom: 0,
            width: geometry.slotWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
            ),
          ),
      ],
    );
  }
}
