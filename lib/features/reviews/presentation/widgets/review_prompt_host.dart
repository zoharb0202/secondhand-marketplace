import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/router/app_router.dart' show rootNavigatorKey;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../data/services/seller_review_service.dart';
import 'write_seller_review_sheet.dart';

const String kReviewPromptedOrderIdsPrefKey = 'review_prompted_order_ids';

const int _kMaxRememberedOrderIds = 200;

class ReviewPromptHost extends ConsumerStatefulWidget {
  const ReviewPromptHost({super.key});

  @override
  ConsumerState<ReviewPromptHost> createState() => _ReviewPromptHostState();
}

class _ReviewPromptHostState extends ConsumerState<ReviewPromptHost> {
  bool _promptOpen = false;

  final Set<String> _promptedOrderIds = {};
  bool _promptedIdsLoaded = false;

  List<OrderModel> _latestOrders = const [];
  Set<String> _reviewedOrderIds = const {};

  bool _ordersLoaded = false;
  bool _reviewedLoaded = false;

  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _loadPromptedIds();
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  Future<void> _loadPromptedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _promptedOrderIds.addAll(
        prefs.getStringList(kReviewPromptedOrderIdsPrefKey) ?? const [],
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [REVIEW] prompted-ids read failed: $e');
    }
    if (!mounted) return;
    _promptedIdsLoaded = true;
    _maybeShow();
  }

  Future<void> _rememberPrompted(String orderId) async {
    _promptedOrderIds.add(orderId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = <String>[
        ...?prefs.getStringList(kReviewPromptedOrderIdsPrefKey),
      ];
      if (!stored.contains(orderId)) stored.add(orderId);
      await prefs.setStringList(
        kReviewPromptedOrderIdsPrefKey,
        stored.length > _kMaxRememberedOrderIds
            ? stored.sublist(stored.length - _kMaxRememberedOrderIds)
            : stored,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [REVIEW] prompted-ids write failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider).value?.id;

    if (uid != null) {
      _absorbOrders(ref.read(buyerOrdersProvider(uid)));
      _absorbReviewed(ref.read(myReviewedOrderIdsProvider(uid)));

      ref.listen<AsyncValue<List<OrderModel>>>(
        buyerOrdersProvider(uid),
        (previous, next) => _absorbOrders(next),
      );
      ref.listen<AsyncValue<Set<String>>>(
        myReviewedOrderIdsProvider(uid),
        (previous, next) => _absorbReviewed(next),
      );
    }

    return const SizedBox.shrink();
  }

  void _absorbOrders(AsyncValue<List<OrderModel>> value) {
    final orders = value.valueOrNull;
    if (orders == null) return;
    _latestOrders = orders;
    _ordersLoaded = true;
    _maybeShow();
  }

  void _absorbReviewed(AsyncValue<Set<String>> value) {
    final reviewed = value.valueOrNull;
    if (reviewed == null) {
      if (value.hasError && kDebugMode) {
        debugPrint(
          '⚠️ [REVIEW] reviewed-order ids unavailable: ${value.error}',
        );
      }
      return;
    }
    _reviewedOrderIds = reviewed;
    _reviewedLoaded = true;
    _maybeShow();
  }

  void _maybeShow() {
    if (_promptOpen || !_promptedIdsLoaded) return;
    if (!_ordersLoaded || !_reviewedLoaded) return;

    final candidates = _latestOrders.where((order) {
      if (order.status != OrderStatus.completed) return false;
      if (_promptedOrderIds.contains(order.id)) return false;
      if (_reviewedOrderIds.contains(order.id)) return false;
      if (order.disputeStatus == 'open') return false;
      if (order.sellerId == order.buyerId) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return;

    candidates.sort(
      (a, b) => (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      ),
    );

    _promptOpen = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _show(candidates.first),
    );
  }

  Future<void> _show(OrderModel order) async {
    if (!mounted) {
      _promptOpen = false;
      return;
    }

    final OverlayState overlay;
    try {
      overlay = Overlay.of(context, rootOverlay: true);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [REVIEW] no root overlay: $e');
      _promptOpen = false;
      return;
    }

    _rememberPrompted(order.id);

    final sellerName = await _sellerName(order.sellerId);
    if (!mounted) {
      _promptOpen = false;
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ReviewPromptCard(
        order: order,
        sellerName: sellerName,
        onOpen: () {
          _close(entry);
          _openComposer(order, sellerName);
        },
        onDismiss: () => _close(entry),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  Future<String> _sellerName(String sellerId) async {
    try {
      return await ref.read(userDisplayNameProvider(sellerId).future);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [REVIEW] seller name lookup failed: $e');
      return 'המוכר';
    }
  }

  void _close(OverlayEntry entry) {
    if (_entry != entry) return;
    _entry = null;
    entry.remove();
    _promptOpen = false;
  }

  void _openComposer(OrderModel order, String sellerName) {
    final rootContext = rootNavigatorKey.currentContext;
    if (rootContext == null) return;
    WriteSellerReviewSheet.show(
      rootContext,
      orderId: order.id,
      sellerId: order.sellerId,
      sellerName: sellerName,
      productTitle: order.productTitle,
    );
  }
}

class _ReviewPromptCard extends StatefulWidget {
  final OrderModel order;
  final String sellerName;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _ReviewPromptCard({
    required this.order,
    required this.sellerName,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  State<_ReviewPromptCard> createState() => _ReviewPromptCardState();
}

class _ReviewPromptCardState extends State<_ReviewPromptCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _closing = false;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOut(VoidCallback then) async {
    if (_closing) return;
    _closing = true;
    if (mounted) await _controller.reverse();
    then();
  }

  @override
  Widget build(BuildContext context) {
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
                  key: ValueKey('review_prompt_${widget.order.id}'),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    _closing = true;
                    widget.onDismiss();
                  },
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: _card(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.ink, width: 1),
        boxShadow: AppColors.offsetShadow(),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.sunDeep, width: 4)),
          borderRadius: AppRadius.cardR,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.sunDeep.withValues(alpha: 0.12),
                    borderRadius: AppRadius.chipR,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.star_outline_rounded,
                    color: AppColors.sunDeep,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'איך הייתה הרכישה?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansHebrew(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bodyText(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansHebrew(
                          fontSize: 13,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                InkResponse(
                  onTap: () => _animateOut(widget.onDismiss),
                  radius: 18,
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                TextButton(
                  onPressed: () => _animateOut(widget.onDismiss),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  child: Text(
                    'לא עכשיו',
                    style: GoogleFonts.ibmPlexSansHebrew(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _animateOut(widget.onOpen),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cobalt,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.chipR,
                      side: const BorderSide(color: AppColors.ink),
                    ),
                  ),
                  child: Text(
                    'כתוב ביקורת',
                    style: GoogleFonts.ibmPlexSansHebrew(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _bodyText() {
    final title = widget.order.productTitle;
    if (title.isEmpty) {
      return 'ספר לקונים הבאים איך היה מול ${widget.sellerName}';
    }
    return 'קנית "$title" מ${widget.sellerName} — ספר לקונים הבאים איך היה';
  }
}
