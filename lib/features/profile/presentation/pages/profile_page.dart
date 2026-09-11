import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/animated_gradient.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/constants/enums.dart';
import '../../../../shared/models/product_model.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import 'my_products_page.dart';
import 'addresses_page.dart';
import 'settings_page.dart';
import 'help_page.dart';
import 'edit_profile_page.dart';
import 'availability_settings_page.dart';
import 'notification_settings_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../products/presentation/pages/my_offers_page.dart';
import '../../../products/presentation/pages/following_feed_page.dart';
import '../widgets/seller_level_card.dart';
import '../../../admin/presentation/pages/admin_users_page.dart';
import '../../../chat/presentation/pages/chats_list_page.dart';
import '../../../products/presentation/pages/recently_viewed_page.dart';
import '../../../favorites/presentation/pages/favorites_page.dart' as fav;
import '../../../products/presentation/pages/saved_searches_page.dart';
import '../../../products/presentation/pages/search_page.dart';
import '../../../analytics/presentation/pages/seller_analytics_page.dart';
import '../../../products/presentation/pages/product_comparison_page.dart';
import '../../../products/presentation/pages/swipe_mode_page.dart';
import '../../../products/presentation/pages/bulk_upload_page.dart';
import '../../../support/presentation/pages/contact_support_page.dart';
import 'chatbot_page.dart';
import '../../../../scripts/add_sample_products_button.dart';
import '../../../alerts/presentation/pages/alerts_page.dart';
import '../../../alerts/presentation/providers/alert_provider.dart';
import '../../../storefront/presentation/pages/storefront_editor_page.dart';
import 'seller_profile_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          'פרופיל',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.altSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 20,
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('לא נמצאו פרטי משתמש'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),

                AnimatedGradientContainer(
                      borderRadius: BorderRadius.circular(60),
                      duration: const Duration(seconds: 4),
                      padding: const EdgeInsets.all(3),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: context.cardSurface,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? GradientText(
                                user.displayName
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    'U',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 16),

                Text(
                  user.displayName ?? 'User',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),

                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.cardSurface,
                        borderRadius: AppRadius.chipR,
                        border: Border.all(
                          color: context.accentCobalt,
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        user.role.displayName,
                        style: TextStyle(
                          color: context.accentCobalt,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                GradientButton(
                  text: 'ערוך פרופיל',
                  icon: Icons.edit_outlined,
                  outlined: true,
                  height: 42,
                  borderRadius: 14,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'מכירות',
                          value: user.totalSales.toString(),
                        ),
                        _StatItem(
                          label: 'דירוג',
                          value: user.sellerRating?.toStringAsFixed(1) ?? '-',
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FollowingFeedPage(),
                            ),
                          ),
                          child: _StatItem(
                            label: 'עוקב אחרי',
                            value: user.followingSellerIds.length.toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SellerLevelCard(seller: user),
                  ),
                  const SizedBox(height: 24),
                ],

                Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () {
                          _showSupportOptions(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cobalt,
                            borderRadius: AppRadius.cardR,
                            border: Border.all(
                              color: AppColors.borderStrong,
                              width: 1.5,
                            ),
                            boxShadow: AppColors.offsetShadow(
                              color: AppColors.cobalt,
                              alpha: 0.26,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: AppRadius.chipR,
                                ),
                                child: const Icon(
                                  Icons.support_agent_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'שירות לקוחות',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'נשמח לעזור בכל שאלה',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms)
                    .moveY(
                      begin: 15,
                      end: 0,
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 24),

                const Divider(),

                ...[
                  _MenuItem(
                    icon: Icons.remove_red_eye_outlined,
                    title: 'תצוגה מקדימה של הפרופיל שלי',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SellerProfilePage(
                            sellerId: user.id,
                            sellerName: user.displayName,
                          ),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'המוצרים שלי',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyProductsPage(),
                        ),
                      );
                    },
                  ),
                ],

                _MenuItem(
                  icon: Icons.favorite_outline,
                  title: 'מועדפים',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const fav.FavoritesPage(),
                      ),
                    );
                  },
                ),
                ...[
                  _MenuItemWithBadge(
                    icon: Icons.notifications_active_outlined,
                    title: 'התראות חכמות',
                    badgeCount:
                        ref.watch(unreadMatchesCountProvider).value ?? 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AlertsPage(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.history,
                    title: 'נצפו לאחרונה',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecentlyViewedPage(),
                        ),
                      );
                    },
                  ),
                ],

                _MenuItem(
                  icon: Icons.shopping_bag_outlined,
                  title: 'ההזמנות שלי',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrdersPage(),
                      ),
                    );
                  },
                ),

                _MenuItem(
                  icon: Icons.local_offer_outlined,
                  title: 'הצעות מחיר',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyOffersPage(),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'התראות',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsPage(),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.tune_outlined,
                  title: 'הגדרות התראות',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationSettingsPage(),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.chat_outlined,
                  title: 'הודעות',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatsListPage(),
                      ),
                    );
                  },
                ),
                ...[
                  _MenuItem(
                    icon: Icons.access_time,
                    title: 'זמינות לאיסוף',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AvailabilitySettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
                ...[
                  _MenuItem(
                    icon: Icons.compare_arrows,
                    title: 'השוואת מוצרים',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProductComparisonPage(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.swipe,
                    title: 'גלה מוצרים',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SwipeModePage(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.search,
                    title: 'חיפושים שמורים',
                    onTap: () async {
                      final query = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedSearchesPage(),
                        ),
                      );
                      if (query != null &&
                          query.isNotEmpty &&
                          context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SearchPage(initialQuery: query),
                          ),
                        );
                      }
                    },
                  ),
                ],
                ...[
                  _MenuItem(
                    icon: Icons.palette_outlined,
                    title: 'עיצוב החנות שלי',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StorefrontEditorPage(),
                        ),
                      );
                    },
                  ),
                  _MenuItemWithSwitch(
                    icon: Icons.storefront_outlined,
                    title: 'חנות פתוחה',
                    value: user.isStoreOpen,
                    onChanged: (value) async {
                      try {
                        await ref.read(authRepositoryProvider).updateUserData(
                          user.id,
                          {'isStoreOpen': value},
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'החנות סומנה כפתוחה'
                                    : 'החנות סומנה כסגורה',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('שגיאה בעדכון סטטוס החנות: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _MenuItem(
                    icon: Icons.analytics_outlined,
                    title: 'אנליטיקס',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SellerAnalyticsPage(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.upload_file,
                    title: 'העלאה מרובה',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BulkUploadPage(),
                        ),
                      );
                    },
                  ),
                ],

                _MenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'כתובות',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddressesPage(),
                      ),
                    );
                  },
                ),
                _MenuItemWithSwitch(
                  icon: Icons.dark_mode_outlined,
                  title: 'מצב כהה',
                  value: ref.watch(themeModeProvider),
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).setDarkMode(value);
                  },
                ),
                _MenuItem(
                  icon: Icons.help_outline,
                  title: 'עזרה ותמיכה',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HelpPage()),
                    );
                  },
                ),
                if (user.isAdmin)
                  _MenuItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'ניהול משתמשים',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminUsersPage(),
                        ),
                      );
                    },
                  ),
                if (kDebugMode) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Card(
                      elevation: 2,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.science_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'כלי פיתוח',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const AddSampleProductsButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  _MenuItem(
                    icon: Icons.science,
                    title: 'צור מוצר דוגמה (דיבוג)',
                    onTap: () async {
                      try {
                        final productController = ref.read(
                          productControllerProvider.notifier,
                        );

                        final sampleProduct = ProductModel(
                          id: '',
                          sellerId: user.id,
                          title: 'iPhone 15 Pro Max - דוגמה',
                          description:
                              'מוצר דוגמה ליבוא - iPhone 15 Pro Max במצב מעולה',
                          price: 4500,
                          category: ProductCategory.electronics,
                          subcategory: 'smartphones',
                          brand: 'Apple',
                          condition: ProductCondition.likeNew,
                          imageUrls: [],
                          createdAt: DateTime.now(),
                          location:
                              user.location ?? const GeoPoint(32.0853, 34.7818),
                          city: user.city ?? 'תל אביב',
                          categoryId: 'electronics',
                          subCategoryId: 'smartphones',
                        );

                        final createdProduct = await productController
                            .createProduct(
                              product: sampleProduct,
                              imageFiles: [],
                            );

                        if (createdProduct != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('מוצר דוגמה נוצר בהצלחה!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('שגיאה ביצירת מוצר דוגמה: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
                const Divider(),
                _MenuItem(
                  icon: Icons.logout,
                  title: 'התנתק',
                  textColor: AppColors.error,
                  onTap: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('התנתקות'),
                        content: const Text('האם אתה בטוח שברצונך להתנתק?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ביטול'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('התנתק'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true && context.mounted) {
                      await ref.read(authControllerProvider.notifier).signOut();
                    }
                  },
                ),
                const NavBarClearanceGap(extra: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StreamErrorView(
          error: error,
          title: 'לא הצלחנו לטעון את הפרופיל',
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: context.hairline, width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: context.accentCobalt,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

void _showSupportOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'איך נוכל לעזור?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),

          _SupportOptionCard(
            icon: Icons.smart_toy,
            iconColor: context.accentCobalt,
            title: 'צ\'אט AI חכם',
            subtitle: 'קבל תשובות מיידיות לשאלות נפוצות',
            badge: '24/7',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatbotPage()),
              );
            },
          ),
          const SizedBox(height: 12),

          _SupportOptionCard(
            icon: Icons.support_agent,
            iconColor: Colors.orange,
            title: 'פנייה לנציג',
            subtitle: 'צור קשר עם נציג שירות אנושי',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactSupportPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _SupportOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _SupportOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cobalt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? context.textPrimary;
    final iconColor = textColor ?? context.accentCobalt;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: context.hairline, width: 1),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.chevron_left, color: context.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

class _MenuItemWithBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final int badgeCount;
  final VoidCallback onTap;

  const _MenuItemWithBadge({
    required this.icon,
    required this.title,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.textPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: context.hairline, width: 1),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: context.accentCobalt),
            if (badgeCount > 0)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.chevron_left, color: context.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

class _MenuItemWithSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MenuItemWithSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.textPrimary;
    final accent = context.accentCobalt;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: context.hairline, width: 1),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
        leading: Icon(icon, color: accent),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: accent.withValues(alpha: 0.5),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accent;
            }
            return null;
          }),
        ),
      ),
    );
  }
}
