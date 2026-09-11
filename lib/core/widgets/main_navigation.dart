import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/products/presentation/pages/home_page.dart';
import '../../features/search/presentation/pages/ai_search_page.dart';
import '../../features/products/presentation/pages/add_product_page.dart';
import '../../features/chat/presentation/pages/chats_list_page.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import '../../features/cart/presentation/pages/cart_page.dart';
import '../../features/cart/presentation/providers/cart_provider.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/widgets/notification_listener.dart'
    as notif;
import '../../features/offers/presentation/widgets/price_offer_host.dart';
import '../../features/reviews/presentation/widgets/review_prompt_host.dart';
import '../constants/user_roles.dart';
import '../../features/support/presentation/pages/support_agent_dashboard.dart';
import '../../features/support/presentation/pages/admin_dashboard.dart';
import '../../features/alerts/presentation/providers/alert_provider.dart';
import 'liquid_nav/liquid_nav_bar.dart';
import 'liquid_nav/nav_item.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  int? _pendingIndex;
  int get _displayIndex => _pendingIndex ?? _currentIndex;

  late AnimationController _navEntryController;

  @override
  void initState() {
    super.initState();
    _navEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _navEntryController.dispose();
    super.dispose();
  }

  UserRole get _userRole =>
      ref.watch(currentUserProvider).value?.role ?? UserRole.customer;

  List<Widget> get _pages {
    if (_userRole == UserRole.admin) {
      return [
        const AdminDashboard(),
        const ChatsListPage(),
        const ProfilePage(),
      ];
    }
    if (_userRole == UserRole.supportAgent) {
      return [
        const SupportAgentDashboard(),
        const ChatsListPage(),
        const ProfilePage(),
      ];
    }
    return [
      const HomePage(),
      const AISearchPage(),
      Container(),
      const CartPage(),
      const ChatsListPage(),
      const ProfilePage(),
    ];
  }

  List<NavItem> _getNavItems() {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final unreadCount = currentUser != null
        ? ref.watch(unreadCountProvider(currentUser.id)).valueOrNull ?? 0
        : 0;
    final cartItemCount = currentUser != null
        ? ref.watch(cartItemCountProvider(currentUser.id)).valueOrNull ?? 0
        : 0;
    final alertMatchCount =
        (_userRole == UserRole.customer && currentUser != null)
        ? ref.watch(unreadMatchesCountProvider).valueOrNull ?? 0
        : 0;

    if (_userRole == UserRole.admin) {
      return [
        NavItem(Icons.dashboard_outlined, Icons.dashboard, 'דשבורד'),
        NavItem(
          Icons.chat_bubble_outline,
          Icons.chat_bubble,
          'הודעות',
          badge: unreadCount,
        ),
        NavItem(Icons.person_outline, Icons.person, 'פרופיל'),
      ];
    }
    if (_userRole == UserRole.supportAgent) {
      return [
        NavItem(Icons.support_agent_outlined, Icons.support_agent, 'פניות'),
        NavItem(
          Icons.chat_bubble_outline,
          Icons.chat_bubble,
          'הודעות',
          badge: unreadCount,
        ),
        NavItem(Icons.person_outline, Icons.person, 'פרופיל'),
      ];
    }
    return [
      NavItem(Icons.home_outlined, Icons.home_rounded, 'בית'),
      NavItem(Icons.search_outlined, Icons.search_rounded, 'חיפוש'),
      NavItem(Icons.add_rounded, Icons.add_rounded, 'הוסף'),
      NavItem(
        Icons.shopping_cart_outlined,
        Icons.shopping_cart_rounded,
        'עגלה',
        badge: cartItemCount,
      ),
      NavItem(
        Icons.chat_bubble_outline,
        Icons.chat_bubble_rounded,
        'הודעות',
        badge: unreadCount,
      ),
      NavItem(
        Icons.person_outline,
        Icons.person_rounded,
        'פרופיל',
        badge: alertMatchCount,
      ),
    ];
  }

  int? get _addActionIndex =>
      (_userRole != UserRole.admin && _userRole != UserRole.supportAgent)
      ? 2
      : null;

  void _navigateToAddProduct() async {
    setState(() => _pendingIndex = 2);
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddProductPage()),
      );
      if (result == true && mounted) {
        setState(() => _currentIndex = 0);
      }
    } finally {
      if (mounted) setState(() => _pendingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getNavItems();

    return notif.NotificationListener(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: IndexedStack(index: _currentIndex, children: _pages),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 2),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _navEntryController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: LiquidNavBar(
                items: navItems,
                selectedIndex: _displayIndex,
                onSelect: (i) => setState(() => _currentIndex = i),
                addActionIndex: _addActionIndex,
                onAddAction: _navigateToAddProduct,
              ),
            ),
          ),

          if (_userRole == UserRole.customer) const PriceOfferHost(),

          if (_userRole == UserRole.customer) const ReviewPromptHost(),
        ],
      ),
    );
  }
}
