import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart' show rootNavigatorKey;
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/my_offers_page.dart';

const String kPriceOfferPromptedIdsPrefKey = 'price_offer_prompted_ids';

const int _kMaxRememberedOfferIds = 200;

const int _kOfferScanLimit = 20;

class _PendingOffer {
  final String id;
  final String productTitle;
  final String buyerName;
  final double offeredPrice;
  final double originalPrice;
  final DateTime? createdAt;

  const _PendingOffer({
    required this.id,
    required this.productTitle,
    required this.buyerName,
    required this.offeredPrice,
    required this.originalPrice,
    required this.createdAt,
  });

  factory _PendingOffer.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAtRaw = data['createdAt'];
    return _PendingOffer(
      id: doc.id,
      productTitle: (data['productTitle'] as String?) ?? '',
      buyerName: (data['buyerName'] as String?) ?? 'משתמש',
      offeredPrice: (data['offeredPrice'] as num?)?.toDouble() ?? 0,
      originalPrice: (data['originalPrice'] as num?)?.toDouble() ?? 0,
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : null,
    );
  }
}

final _pendingSellerOffersProvider = StreamProvider.autoDispose
    .family<List<_PendingOffer>, String>((ref, sellerId) {
      return FirebaseFirestore.instance
          .collection('price_offers')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(_kOfferScanLimit)
          .snapshots()
          .map(
            (snap) => snap.docs
                .where((d) => (d.data()['status'] ?? 'pending') == 'pending')
                .map(_PendingOffer.fromDoc)
                .toList(),
          );
    });

class PriceOfferHost extends ConsumerStatefulWidget {
  const PriceOfferHost({super.key});

  @override
  ConsumerState<PriceOfferHost> createState() => _PriceOfferHostState();
}

class _PriceOfferHostState extends ConsumerState<PriceOfferHost> {
  bool _promptOpen = false;

  final Set<String> _promptedOfferIds = {};
  bool _promptedIdsLoaded = false;

  final DateTime _sessionStartedAt = DateTime.now();

  List<_PendingOffer> _latestOffers = const [];

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
      _promptedOfferIds.addAll(
        prefs.getStringList(kPriceOfferPromptedIdsPrefKey) ?? const [],
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [OFFERS] prompted-ids read failed: $e');
    }
    if (!mounted) return;
    _promptedIdsLoaded = true;
    _maybeShow(_latestOffers);
  }

  Future<void> _rememberPrompted(Iterable<String> ids) async {
    _promptedOfferIds.addAll(ids);
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = <String>[
        ...?prefs.getStringList(kPriceOfferPromptedIdsPrefKey),
      ];
      for (final id in ids) {
        if (!stored.contains(id)) stored.add(id);
      }
      await prefs.setStringList(
        kPriceOfferPromptedIdsPrefKey,
        stored.length > _kMaxRememberedOfferIds
            ? stored.sublist(stored.length - _kMaxRememberedOfferIds)
            : stored,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [OFFERS] prompted-ids write failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider).value?.id;

    if (uid != null) {
      ref.listen<AsyncValue<List<_PendingOffer>>>(
        _pendingSellerOffersProvider(uid),
        (previous, next) {
          if (next.hasError && kDebugMode) {
            debugPrint(
              '⚠️ [OFFERS] pending-offers stream error: ${next.error}',
            );
          }
          final offers = next.valueOrNull;
          if (offers != null) {
            _latestOffers = offers;
            _maybeShow(offers);
          }
        },
      );
    }

    return const SizedBox.shrink();
  }

  void _maybeShow(List<_PendingOffer> offers) {
    if (_promptOpen || !_promptedIdsLoaded) return;

    final unseen = offers.where((o) {
      if (_promptedOfferIds.contains(o.id)) return false;
      final createdAt = o.createdAt;
      return createdAt != null && createdAt.isBefore(_sessionStartedAt);
    }).toList();
    if (unseen.isEmpty) return;

    unseen.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );

    _promptOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) => _show(unseen));
  }

  void _show(List<_PendingOffer> unseen) {
    if (!mounted) {
      _promptOpen = false;
      return;
    }

    final OverlayState overlay;
    try {
      overlay = Overlay.of(context, rootOverlay: true);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [OFFERS] no root overlay: $e');
      _promptOpen = false;
      return;
    }

    _rememberPrompted(unseen.map((o) => o.id));

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PriceOfferPromptCard(
        offer: unseen.first,
        additionalCount: unseen.length - 1,
        onOpen: () {
          _close(entry);
          _openMyOffers();
        },
        onDismiss: () => _close(entry),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void _close(OverlayEntry entry) {
    if (_entry != entry) return;
    _entry = null;
    entry.remove();
    _promptOpen = false;
  }

  void _openMyOffers() {
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const MyOffersPage()),
    );
  }
}

class _PriceOfferPromptCard extends StatefulWidget {
  final _PendingOffer offer;
  final int additionalCount;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _PriceOfferPromptCard({
    required this.offer,
    required this.additionalCount,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  State<_PriceOfferPromptCard> createState() => _PriceOfferPromptCardState();
}

class _PriceOfferPromptCardState extends State<_PriceOfferPromptCard>
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
                  key: ValueKey('price_offer_prompt_${widget.offer.id}'),
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
                          color: AppColors.cobalt.withValues(alpha: 0.10),
                          borderRadius: AppRadius.chipR,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.local_offer_outlined,
                          color: AppColors.cobalt,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'הצעת מחיר חדשה',
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
                  if (widget.additionalCount > 0) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'ועוד ${widget.additionalCount} הצעות חדשות ממתינות לך',
                      style: GoogleFonts.ibmPlexSansHebrew(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
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
                          'צפייה בהצעה',
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
          ),
        ],
      ),
    );
  }

  String _bodyText() {
    final offer = widget.offer;
    final price = '₪${offer.offeredPrice.toStringAsFixed(0)}';
    final priceText = offer.originalPrice > offer.offeredPrice
        ? '$price במקום ₪${offer.originalPrice.toStringAsFixed(0)}'
        : price;
    if (offer.productTitle.isEmpty) {
      return '${offer.buyerName} הציע/ה $priceText';
    }
    return '${offer.buyerName} הציע/ה $priceText על ${offer.productTitle}';
  }
}
