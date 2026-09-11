import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/notification_coordinator.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';

class InAppBanner {
  InAppBanner._();

  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, AppNotification notification) {
    final overlay = Overlay.of(context, rootOverlay: true);

    _currentEntry?.remove();
    _currentEntry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _InAppBannerView(
        notification: notification,
        onDismissed: () {
          if (_currentEntry == entry) _currentEntry = null;
          entry.remove();
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _InAppBannerView extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismissed;

  const _InAppBannerView({
    required this.notification,
    required this.onDismissed,
  });

  @override
  State<_InAppBannerView> createState() => _InAppBannerViewState();
}

class _InAppBannerViewState extends State<_InAppBannerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_dismissing) _dismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismissed();
  }

  void _handleTap() {
    final n = widget.notification;
    NotificationService().markAsRead(n.id);

    final data = <String, dynamic>{'type': n.type.wire, ...?n.data};
    NotificationCoordinator.instance.handleNotificationTap(data);

    _dismiss();
  }

  String? _thumbnailUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in ['productImage', 'imageUrl', 'image', 'thumbnail']) {
      final v = data[key];
      if (v is String && v.startsWith('http')) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final thumb = _thumbnailUrl(n.data);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            0,
          ),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                type: MaterialType.transparency,
                child: Dismissible(
                  key: ValueKey('in_app_banner_${n.id}'),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    _dismissing = true;
                    widget.onDismissed();
                  },
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: _card(n, thumb),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(AppNotification n, String? thumb) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: AppRadius.cardR,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardR,
          border: Border.all(color: AppColors.ink, width: 1),
          boxShadow: AppColors.offsetShadow(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppColors.cobalt,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(AppRadius.card),
                  bottomRight: Radius.circular(AppRadius.card),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    _leading(n, thumb),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSansHebrew(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (n.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.ibmPlexSansHebrew(
                                fontSize: 13,
                                height: 1.3,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    InkResponse(
                      onTap: _dismiss,
                      radius: 18,
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leading(AppNotification n, String? thumb) {
    if (thumb != null) {
      return ClipRRect(
        borderRadius: AppRadius.chipR,
        child: Image.network(
          thumb,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconBadge(n),
        ),
      );
    }
    return _iconBadge(n);
  }

  Widget _iconBadge(AppNotification n) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.cobalt.withValues(alpha: 0.10),
        borderRadius: AppRadius.chipR,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(n.type.icon, color: AppColors.cobalt, size: 22),
    );
  }
}
