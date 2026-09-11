import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_border_card.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../../core/widgets/premium_shimmer.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/image_variants.dart';
import '../providers/product_provider.dart';
import '../providers/feed_order_provider.dart';
import '../../../../core/services/interaction_tracker.dart';
import '../../../../core/services/location_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../../core/services/notification_service.dart'
    show kUnreadNotificationsBadgeCap;
import '../widgets/product_video_player.dart';
import '../widgets/product_card.dart';
import '../widgets/ai_recommendations_section.dart';
import '../widgets/advanced_filter_sheet.dart';
import 'product_detail_page.dart';
import 'product_map_page.dart';
import 'search_page.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/constants/feature_flags.dart';
import 'deals_page.dart';
import '../../../stories/presentation/widgets/stories_bar.dart';

enum ViewMode { vertical, grid }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  final PageController _pageController = PageController();
  final ScrollController _gridScrollController = ScrollController();
  ViewMode _currentViewMode = ViewMode.grid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  DateTime? _pausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(userTasteProfileProvider);
      ref.invalidate(trendingScoresProvider);
      ref.invalidate(userGeoPointProvider);

      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) >= kFeedResumeRerankThreshold) {
        ref.read(feedOrderEpochProvider.notifier).state++;
      }
    }
  }

  void _switchFeedSource(FeedSource source) {
    if (ref.read(feedSourceProvider) == source) return;
    _flushFeedDwell();
    _dwellProduct = null;
    _feedDwellStarted = false;
    ref.read(feedSourceProvider.notifier).state = source;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    if (_gridScrollController.hasClients) {
      _gridScrollController.jumpTo(0);
    }
  }

  Future<void> _openFilters() async {
    final result = await AdvancedFilterSheet.show(
      context,
      ref.read(activeFiltersProvider),
    );
    if (result == null || !mounted) return;
    _flushFeedDwell();
    _dwellProduct = null;
    _feedDwellStarted = false;
    ref.read(activeFiltersProvider.notifier).state = result;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    if (_gridScrollController.hasClients) {
      _gridScrollController.jumpTo(0);
    }
  }

  final Stopwatch _feedDwellStopwatch = Stopwatch();
  bool _feedDwellStarted = false;

  ProductModel? _dwellProduct;

  void _onFeedPageChanged(int index, List<ProductModel> products) {
    _flushFeedDwell();
    _dwellProduct = (index >= 0 && index < products.length)
        ? products[index]
        : null;
    _feedDwellStopwatch
      ..reset()
      ..start();
    _maybeGrowPageWindow(index, products.length);
  }

  void _growFeedWindow() {
    if (ref.read(feedSourceProvider) != FeedSource.forYou) return;
    final pageSize = ref.read(feedPageSizeProvider);
    if (pageSize >= kFeedMaxPageSize) return;
    if (ref.read(feedRawFetchCountProvider) < pageSize) return;
    ref
        .read(feedPageSizeProvider.notifier)
        .update((s) => (s + kFeedPageIncrement).clamp(0, kFeedMaxPageSize));
  }

  void _maybeGrowPageWindow(int index, int total) {
    if (index >= total - 3) _growFeedWindow();
  }

  void _flushFeedDwell() {
    if (!_feedDwellStopwatch.isRunning &&
        _feedDwellStopwatch.elapsedMilliseconds == 0) {
      return;
    }
    final elapsedMs = _feedDwellStopwatch.elapsedMilliseconds;
    _feedDwellStopwatch.stop();
    final product = _dwellProduct;
    if (product != null) {
      InteractionTracker().track(
        InteractionType.dwell,
        product: product,
        dwellMs: elapsedMs,
      );
    }
  }

  void _rerankAndScrollToTop() {
    ref.read(feedOrderEpochProvider.notifier).state++;
    if (_currentViewMode == ViewMode.vertical) {
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    } else {
      if (_gridScrollController.hasClients) {
        _gridScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _showNewArrivals() {
    final targetIds =
        ref.read(feedOrderProvider).valueOrNull?.newArrivalIds ??
        const <String>{};

    ref.read(feedOrderEpochProvider.notifier).state++;

    if (targetIds.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final products =
          ref.read(feedOrderProvider).valueOrNull?.products ??
          const <ProductModel>[];
      int? target;
      for (var i = 0; i < products.length; i++) {
        if (targetIds.contains(products[i].id)) {
          target = i;
          break;
        }
      }
      if (target == null) return;
      if (_currentViewMode == ViewMode.vertical) {
        if (_pageController.hasClients) _pageController.jumpToPage(target);
      } else if (_gridScrollController.hasClients) {
        _gridScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _retryFeedAfterError() {
    if (ref.read(feedSourceProvider) == FeedSource.forYou) {
      ref.invalidate(productsStreamProvider);
    } else {
      ref.invalidate(followedSellersRawFeedProvider);
    }
  }

  List<Widget> _buildFeedStatusOverlay(StableFeed feed) {
    final widgets = <Widget>[];
    if (feed.isRefreshing) {
      widgets.add(
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: AppColors.cobalt,
          ),
        ),
      );
    }
    if (feed.error != null) {
      widgets.add(
        Positioned(
          bottom: NavBarClearance.of(context) + 8,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'שגיאה בעדכון הפיד — מוצג העדכון האחרון שנטען',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _retryFeedAfterError,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'נסה שוב',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushFeedDwell();
    _pageController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedSource = ref.watch(feedSourceProvider);
    final productsAsync = ref.watch(feedOrderProvider);

    final isVerticalMode = _currentViewMode == ViewMode.vertical;
    return Scaffold(
      backgroundColor: isVerticalMode ? AppColors.ink : context.pageBackground,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: isVerticalMode
            ? _FeedSourceToggle(
                current: feedSource,
                onChanged: _switchFeedSource,
                onDark: isVerticalMode,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(markSize: 28, fontSize: 17),
                  if (FeatureFlags.demoMode) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.hairline),
                      ),
                      child: Text(
                        'דמו',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          GestureDetector(
            onTap: () {
              setState(() {
                _currentViewMode = _currentViewMode == ViewMode.vertical
                    ? ViewMode.grid
                    : ViewMode.vertical;
              });
            },
            child: GlassContainer(
              borderRadius: BorderRadius.circular(14),
              blur: 8,
              padding: const EdgeInsets.all(10),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    RotationTransition(turns: animation, child: child),
                child: Icon(
                  _currentViewMode == ViewMode.vertical
                      ? Icons.grid_view_rounded
                      : Icons.view_day_rounded,
                  key: ValueKey(_currentViewMode),
                  size: 20,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (context) {
              final activeCount = ref
                  .watch(activeFiltersProvider)
                  .activeFilterCount;
              return GestureDetector(
                onTap: _openFilters,
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(14),
                  blur: 8,
                  padding: const EdgeInsets.all(10),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: context.textPrimary,
                      ),
                      if (activeCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.cobalt,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          if (isVerticalMode) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DealsPage()),
                );
              },
              child: GlassContainer(
                borderRadius: BorderRadius.circular(14),
                blur: 8,
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.local_offer_outlined,
                  size: 20,
                  color: context.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductMapPage(),
                  ),
                );
              },
              child: GlassContainer(
                borderRadius: BorderRadius.circular(14),
                blur: 8,
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.map_outlined,
                  size: 20,
                  color: context.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const _NotificationBellButton(),
          const SizedBox(width: 16),
        ],
      ),
      body: productsAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (feed) {
          final products = feed.products;
          if (kDebugMode) {
            print('📦 Products loaded: ${products.length} products found');
          }
          for (int i = 0; i < products.length && i < 5; i++) {
            final p = products[i];
            if (kDebugMode) {
              print(
                '📦 Product $i: ${p.title} (active: ${p.isActive}, sold: ${p.isSold})',
              );
            }
          }

          if (!_feedDwellStarted && products.isNotEmpty) {
            _feedDwellStarted = true;
            _onFeedPageChanged(0, products);
          }

          if (products.isEmpty) {
            final isFollowingEmpty = feedSource == FeedSource.following;
            final emptyTitleColor = isVerticalMode
                ? AppColors.darkTextPrimary
                : context.textPrimary;
            final emptyBodyColor = isVerticalMode
                ? AppColors.darkTextTertiary
                : context.textTertiary;
            return Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: AppColors.cobalt,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFollowingEmpty
                                  ? Icons.people_outline_rounded
                                  : Icons.shopping_bag_outlined,
                              size: 48,
                              color: Colors.white,
                            ),
                          )
                          .animate()
                          .scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.0, 1.0),
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          )
                          .fadeIn(duration: 400.ms),
                      const SizedBox(height: 24),
                      Text(
                            isFollowingEmpty
                                ? 'אין עדיין מוצרים מהעוקבים שלך'
                                : 'אין מוצרים להצגה',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: emptyTitleColor,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .moveY(begin: 10, end: 0, duration: 400.ms),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          isFollowingEmpty
                              ? 'עקוב אחרי מוכרים כדי לראות כאן את המוצרים שלהם, ממוינים במיוחד בשבילך'
                              : 'נסה להוסיף מוצרים חדשים דרך כפתור הפלוס',
                          style: TextStyle(fontSize: 14, color: emptyBodyColor),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                      if (isFollowingEmpty) ...[
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () => _switchFeedSource(FeedSource.forYou),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cobalt,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.explore_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'גלה מוכרים ומוצרים',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                      ],
                    ],
                  ),
                ),
                ..._buildFeedStatusOverlay(feed),
              ],
            );
          }

          return Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _currentViewMode == ViewMode.vertical
                    ? PageView.builder(
                        key: const ValueKey('vertical'),
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        itemCount: products.length,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) =>
                            _onFeedPageChanged(index, products),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _ProductCard(
                            key: ValueKey(product.id),
                            product: product,
                          );
                        },
                      )
                    : _ProductGridView(
                        key: const ValueKey('grid'),
                        header: HomeGridHeader(
                          feedSource: feedSource,
                          onFeedSourceChanged: _switchFeedSource,
                        ),
                        controller: _gridScrollController,
                        products: products,
                        onNearBottom: _growFeedWindow,
                        onPullToRefresh: _rerankAndScrollToTop,
                      ),
              ),
              if (_currentViewMode == ViewMode.vertical) ...[
                Positioned(
                  top: MediaQuery.of(context).padding.top + 52,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black45, Colors.transparent],
                      ),
                    ),
                    child: const StoriesBar(onDark: true),
                  ),
                ),
              ],
              if (feed.newArrivalCount > 0)
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight - 4,
                  left: 0,
                  right: 0,
                  child:
                      Center(
                            child: GestureDetector(
                              onTap: _showNewArrivals,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cobalt,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.fiber_new_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      feed.newArrivalCount > 1
                                          ? '${feed.newArrivalCount} מוצרים חדשים · הצג'
                                          : 'מוצר חדש · הצג',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .moveY(begin: -10, end: 0, duration: 300.ms),
                ),
              ..._buildFeedStatusOverlay(feed),
            ],
          );
        },
        loading: () => const PremiumShimmerGrid(itemCount: 6),
        error: (error, _) => StreamErrorView(
          error: error,
          title: 'לא הצלחנו לטעון את המוצרים',
          onRetry: _retryFeedAfterError,
        ),
      ),
    );
  }
}

class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;
    final hasUnread = unread > 0;

    return Semantics(
      button: true,
      label: hasUnread ? 'התראות, $unread שלא נקראו' : 'התראות',
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsPage()),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassContainer(
              borderRadius: BorderRadius.circular(14),
              blur: 8,
              padding: const EdgeInsets.all(10),
              borderColor: hasUnread ? context.accentCobalt : null,
              borderWidth: hasUnread ? 1.5 : 1.0,
              child: Icon(
                hasUnread
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                size: 20,
                color: hasUnread ? context.accentCobalt : context.textPrimary,
              ),
            ),
            if (hasUnread)
              PositionedDirectional(
                top: -5,
                end: -5,
                child: _UnreadCountBubble(count: unread),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnreadCountBubble extends StatelessWidget {
  final int count;

  const _UnreadCountBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > kUnreadNotificationsBadgeCap
        ? '$kUnreadNotificationsBadgeCap+'
        : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.cardSurface, width: 1.5),
      ),
      child: Text(
        label,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

class _FeedSourceToggle extends StatelessWidget {
  final FeedSource current;
  final ValueChanged<FeedSource> onChanged;
  final bool onDark;

  const _FeedSourceToggle({
    required this.current,
    required this.onChanged,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(3),
      backgroundColor: onDark ? Colors.black.withValues(alpha: 0.28) : null,
      borderColor: onDark ? Colors.white24 : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(context, 'בשבילך', FeedSource.forYou),
          _chip(context, 'עוקב', FeedSource.following),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, FeedSource source) {
    final selected = current == source;
    return GestureDetector(
      onTap: () => onChanged(source),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.cobalt : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected
                ? Colors.white
                : (onDark ? Colors.white70 : context.textSecondary),
          ),
        ),
      ),
    );
  }
}

class HomeGridHeader extends StatelessWidget {
  final FeedSource feedSource;
  final ValueChanged<FeedSource> onFeedSourceChanged;

  const HomeGridHeader({
    super.key,
    required this.feedSource,
    required this.onFeedSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentCobalt;
    final headline = AppTheme.display(
      TextStyle(
        fontSize: 30,
        height: 1.08,
        letterSpacing: -0.5,
        color: context.textPrimary,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'מה נמצא\n'),
                TextSpan(
                  text: 'בשבילך',
                  style: TextStyle(color: accent),
                ),
                const TextSpan(text: ' היום'),
              ],
            ),
            style: headline,
          ),
          const SizedBox(height: 14),
          Material(
            color: context.cardSurface,
            borderRadius: BorderRadius.circular(26),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              ),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: context.hairlineSoft),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 21,
                      color: context.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'מה מחפשים? ספה, אופניים, אייפון...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _HeaderChip(
                  label: 'בשבילך',
                  selected: feedSource == FeedSource.forYou,
                  onTap: () => onFeedSourceChanged(FeedSource.forYou),
                ),
                const SizedBox(width: 8),
                _HeaderChip(
                  label: 'עוקב',
                  selected: feedSource == FeedSource.following,
                  onTap: () => onFeedSourceChanged(FeedSource.following),
                ),
                const SizedBox(width: 8),
                _HeaderChip(
                  label: 'מבצעים',
                  icon: Icons.local_offer_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DealsPage()),
                  ),
                ),
                const SizedBox(width: 8),
                _HeaderChip(
                  label: 'על המפה',
                  icon: Icons.map_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductMapPage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _HeaderChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? context.textPrimary : context.cardSurface;
    final fg = selected ? context.pageBackground : context.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.transparent : context.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductModel product;

  const _ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isLiked =
        currentUser != null && product.likedByUserIds.contains(currentUser.id);
    final userLoc = ref.watch(userGeoPointProvider).valueOrNull;
    final distanceKm = productDistanceKm(userLoc, product.location);
    final cityLabel = distanceKm == null
        ? product.city
        : '${product.city} · ${LocationService.formatDistance(distanceKm)}';

    final firstMedia = product.videoUrls.isNotEmpty
        ? product.videoUrls.first
        : (product.imageUrls.isNotEmpty ? product.imageUrls.first : null);
    final isVideo = product.videoUrls.isNotEmpty;

    final bottomNavHeight = NavBarClearance.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: product.id),
          ),
        );
      },
      child: Container(
        color: AppColors.ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 200),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (firstMedia != null)
                            isVideo
                                ? ProductVideoPlayer(
                                    videoUrl: firstMedia,
                                    autoPlay: true,
                                    showControls: false,
                                    fit: BoxFit.contain,
                                  )
                                : CachedNetworkImage(
                                    imageUrl:
                                        product.mediumImageUrl ?? firstMedia,
                                    fit: BoxFit.contain,
                                    memCacheWidth: kMediumDecodeWidth,
                                    placeholder: (context, url) =>
                                        Container(color: context.altSurface),
                                    errorWidget: (context, url, error) {
                                      return Container(
                                        color: context.altSurface,
                                        child: Icon(
                                          Icons.image_not_supported_rounded,
                                          size: 64,
                                          color: context.textTertiary,
                                        ),
                                      );
                                    },
                                  )
                          else
                            Container(
                              color: context.altSurface,
                              child: Icon(
                                Icons.image_rounded,
                                size: 64,
                                color: context.textTertiary,
                              ),
                            ),

                          Positioned(
                            bottom: 12,
                            left: 12,
                            child:
                                Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: currentUser != null
                                                ? () {
                                                    ref
                                                        .read(
                                                          productControllerProvider
                                                              .notifier,
                                                        )
                                                        .toggleLike(
                                                          product.id,
                                                          currentUser.id,
                                                        );
                                                  }
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: const BoxDecoration(
                                                color: AppColors.lightSurface,
                                                shape: BoxShape.circle,
                                              ),
                                              child: AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                transitionBuilder:
                                                    (child, animation) =>
                                                        ScaleTransition(
                                                          scale: animation,
                                                          child: child,
                                                        ),
                                                child: Icon(
                                                  isLiked
                                                      ? Icons.favorite_rounded
                                                      : Icons
                                                            .favorite_outline_rounded,
                                                  key: ValueKey(isLiked),
                                                  color: isLiked
                                                      ? AppColors.coral
                                                      : AppColors
                                                            .lightTextPrimary,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '${product.likedByUserIds.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                    .animate()
                                    .fadeIn(delay: 200.ms, duration: 400.ms)
                                    .moveX(
                                      begin: -20,
                                      end: 0,
                                      duration: 400.ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                          ),

                          if (isVideo)
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 60,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.ink.withValues(alpha: 0.72),
                                  borderRadius: AppRadius.chipR,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'וידאו',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: bottomNavHeight + 16,
                    ),
                    child:
                        Container(
                              clipBehavior: Clip.hardEdge,
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: AppColors.lightSurface,
                                borderRadius: AppRadius.cardR,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.title,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            height: 1.3,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.lightTextPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      CardPrice(
                                        price: product.price,
                                        fontSize: 22,
                                        color: AppColors.lightTextPrimary,
                                      ),
                                    ],
                                  ),
                                  if (product.isDemo) ...[
                                    const SizedBox(height: 8),
                                    const Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: DemoItemChip(),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: AppColors.lightTextTertiary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          cityLabel,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.lightTextSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (product.description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      product.description,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.lightTextTertiary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .moveY(
                              begin: 20,
                              end: 0,
                              duration: 500.ms,
                              curve: Curves.easeOutCubic,
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductGridView extends ConsumerWidget {
  final List<ProductModel> products;
  final VoidCallback onNearBottom;
  final ScrollController controller;
  final VoidCallback onPullToRefresh;
  final Widget? header;

  const _ProductGridView({
    super.key,
    this.header,
    required this.products,
    required this.onNearBottom,
    required this.controller,
    required this.onPullToRefresh,
  });

  bool _isFeatured(int index) => index > 0 && index % 7 == 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[];
    int i = 0;
    while (i < products.length) {
      if (_isFeatured(i)) {
        final product = products[i];
        rows.add(
          Padding(
            key: ValueKey('row-${product.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: _FeaturedProductCard(
              key: ValueKey(product.id),
              product: product,
            ),
          ),
        );
        i += 1;
      } else {
        final first = products[i];
        ProductModel? second;
        if (i + 1 < products.length && !_isFeatured(i + 1)) {
          second = products[i + 1];
          i += 2;
        } else {
          i += 1;
        }
        rows.add(
          Padding(
            key: ValueKey('row-${first.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.68,
                    child: _GridProductCard(
                      key: ValueKey(first.id),
                      product: first,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: second != null
                      ? AspectRatio(
                          aspectRatio: 0.68,
                          child: _GridProductCard(
                            key: ValueKey(second.id),
                            product: second,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
    }
    final rowIndexByKey = <Key, int>{
      for (var idx = 0; idx < rows.length; idx++)
        if (rows[idx].key != null) rows[idx].key!: idx,
    };

    Future<void> handleRefresh() async {
      onPullToRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    return RefreshIndicator(
      onRefresh: handleRefresh,
      color: AppColors.cobalt,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 800) {
            onNearBottom();
          }
          return false;
        },
        child: CustomScrollView(
          key: const PageStorageKey('home_feed_grid'),
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 56,
              ),
            ),

            if (header != null) SliverToBoxAdapter(child: header),

            const SliverToBoxAdapter(child: StoriesBar()),

            const SliverToBoxAdapter(child: AIRecommendationsSection()),

            SliverPadding(
              padding: NavBarClearance.pad(
                context,
                base: const EdgeInsets.only(left: 12, right: 12),
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => rows[index],
                  childCount: rows.length,
                  findChildIndexCallback: (key) => rowIndexByKey[key],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridProductCard extends ConsumerWidget {
  final ProductModel product;

  const _GridProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isLiked =
        currentUser != null && product.likedByUserIds.contains(currentUser.id);
    final userLoc = ref.watch(userGeoPointProvider).valueOrNull;
    final distanceKm = productDistanceKm(userLoc, product.location);
    final cityLabel = distanceKm == null
        ? product.city
        : '${product.city} · ${LocationService.formatDistance(distanceKm)}';
    final firstMedia = product.videoUrls.isNotEmpty
        ? product.videoUrls.first
        : (product.imageUrls.isNotEmpty ? product.imageUrls.first : null);
    final isVideo = product.videoUrls.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: product.id),
          ),
        );
      },
      child: Hero(
        tag: 'product-${product.id}',
        child: GradientBorderCard(
          borderRadius: AppRadius.card,
          borderWidth: 1,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.card),
                        ),
                        child: firstMedia != null
                            ? (isVideo
                                  ? ProductVideoPlayer(
                                      videoUrl: firstMedia,
                                      autoPlay: false,
                                      showControls: false,
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl:
                                          product.thumbnailUrl ?? firstMedia,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      memCacheWidth: kThumbDecodeWidth,
                                      placeholder: (context, url) =>
                                          Container(color: context.altSurface),
                                      errorWidget: (context, url, error) {
                                        return Container(
                                          color: context.altSurface,
                                          child: Icon(
                                            Icons.image_not_supported_rounded,
                                            size: 32,
                                            color: context.textTertiary,
                                          ),
                                        );
                                      },
                                    ))
                            : Container(
                                color: context.altSurface,
                                child: Center(
                                  child: Icon(
                                    Icons.image_rounded,
                                    size: 32,
                                    color: context.textTertiary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (isVideo)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: currentUser != null
                              ? () {
                                  ref
                                      .read(productControllerProvider.notifier)
                                      .toggleLike(product.id, currentUser.id);
                                }
                              : null,
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.lightSurface,
                              shape: BoxShape.circle,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                key: ValueKey(isLiked),
                                color: isLiked
                                    ? AppColors.coral
                                    : AppColors.lightTextPrimary,
                                size: 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (product.isDemo)
                      const Positioned(
                        bottom: 10,
                        right: 10,
                        child: DemoItemChip(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardPrice(price: product.price),
                    const SizedBox(height: 3),
                    Text(
                      product.title,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cityLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedProductCard extends ConsumerWidget {
  final ProductModel product;

  const _FeaturedProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstMedia = product.imageUrls.isNotEmpty
        ? product.imageUrls.first
        : (product.videoUrls.isNotEmpty ? product.videoUrls.first : null);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: product.id),
          ),
        );
      },
      child: GradientBorderCard(
        borderRadius: AppRadius.card,
        borderWidth: 1.5,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 150,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(AppRadius.card),
                  ),
                  child: firstMedia != null
                      ? CachedNetworkImage(
                          imageUrl: product.thumbnailUrl ?? firstMedia,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          memCacheWidth: kCompactThumbDecodeWidth,
                          placeholder: (context, url) =>
                              Container(color: context.altSurface),
                          errorWidget: (context, url, error) =>
                              Container(color: context.altSurface),
                        )
                      : Container(color: context.altSurface),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? const Color(0xFF12261E)
                              : const Color(0xFFE2F1EA),
                          borderRadius: AppRadius.chipR,
                        ),
                        child: Text(
                          product.isDemo ? 'מומלץ · מוצר לדוגמה' : 'מומלץ',
                          style: TextStyle(
                            color: context.accentCobalt,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.title,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      CardPrice(price: product.price, fontSize: 19),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
