import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/user_model.dart';
import '../widgets/seller_trust_badges.dart';
import '../widgets/seller_level_card.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../../../products/presentation/pages/product_detail_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reviews/presentation/pages/seller_reviews_page.dart';
import '../../../storefront/presentation/providers/storefront_provider.dart';
import '../../../storefront/presentation/widgets/custom_storefront_header.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/pages/chat_page.dart';

final sellerUserProvider = StreamProvider.family<UserModel?, String>((
  ref,
  sellerId,
) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(sellerId)
      .snapshots()
      .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
});

final _sellerProfileShowSoldProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

class SellerProfilePage extends ConsumerWidget {
  final String sellerId;
  final String? sellerName;

  const SellerProfilePage({super.key, required this.sellerId, this.sellerName});

  List<dynamic> _visibleProducts(List<dynamic> products) {
    return products.where((p) => p.isActive || p.isSold).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsBySellerProvider(sellerId));
    final sellerUserAsync = ref.watch(sellerUserProvider(sellerId));
    final currentUser = ref.watch(currentUserProvider).value;
    final storefrontAsync = ref.watch(sellerStorefrontProvider(sellerId));

    final customization = storefrontAsync.value;
    final sellerUser = sellerUserAsync.value;
    final hasCustomStorefront = customization != null && customization.isActive;
    final isOwnProfile = currentUser != null && currentUser.id == sellerId;
    final showSold = ref.watch(_sellerProfileShowSoldProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(sellerName ?? 'פרופיל מוכר'),
        actions: [
          if (!isOwnProfile)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                _showOptionsMenu(context);
              },
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (hasCustomStorefront && sellerUser != null)
            SliverToBoxAdapter(
              child: CustomStorefrontHeader(
                customization: customization,
                seller: sellerUser,
                showStatsRow: false,
                showVerifiedBadge: false,
                showBottomDivider: false,
              ),
            ),

          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (!hasCustomStorefront) ...[
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (sellerName ?? 'מ').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      sellerName ?? 'מוכר',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                  ],

                  sellerUserAsync.when(
                    data: (sellerUser) => sellerUser != null
                        ? Text(
                            'חבר מאז ${sellerUser.createdAt.year}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.textSecondary),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),

                  sellerUserAsync.when(
                    data: (sellerUser) => sellerUser == null
                        ? const SizedBox.shrink()
                        : SellerTrustBadges(seller: sellerUser),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),

                  sellerUserAsync.when(
                    data: (sellerUser) => sellerUser != null
                        ? SellerLevelCard(seller: sellerUser)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  productsAsync.when(
                    data: (allProducts) {
                      final products = _visibleProducts(allProducts);
                      return sellerUserAsync.when(
                        data: (sellerUser) {
                          final rating = sellerUser?.sellerRating ?? 0.0;
                          final reviewCount = sellerUser?.totalReviews ?? 0;

                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _StatItem(
                                    value: products.length.toString(),
                                    label: 'מוצרים',
                                  ),
                                  _StatItem(
                                    value: products
                                        .where((p) => p.isSold)
                                        .length
                                        .toString(),
                                    label: 'נמכרו',
                                  ),
                                  _StatItem(
                                    value: rating > 0
                                        ? rating.toStringAsFixed(1)
                                        : 'חדש',
                                    label: 'דירוג',
                                  ),
                                ],
                              ),
                              if (rating > 0) ...[
                                const SizedBox(height: 12),
                                _buildRatingDisplay(
                                  context,
                                  rating,
                                  reviewCount,
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SellerReviewsPage(
                                          sellerId: sellerId,
                                          sellerName: sellerName ?? 'מוכר',
                                          averageRating: rating,
                                          totalReviews: reviewCount,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.rate_review_outlined),
                                  label: const Text('צפה בכל הביקורות'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                        loading: () => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(
                              value: products.length.toString(),
                              label: 'מוצרים',
                            ),
                            _StatItem(
                              value: products
                                  .where((p) => p.isSold)
                                  .length
                                  .toString(),
                              label: 'נמכרו',
                            ),
                            const _StatItem(value: '-', label: 'דירוג'),
                          ],
                        ),
                        error: (_, __) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(
                              value: products.length.toString(),
                              label: 'מוצרים',
                            ),
                            _StatItem(
                              value: products
                                  .where((p) => p.isSold)
                                  .length
                                  .toString(),
                              label: 'נמכרו',
                            ),
                            const _StatItem(value: '-', label: 'דירוג'),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  if (currentUser != null && currentUser.id != sellerId) ...[
                    SizedBox(
                      width: double.infinity,
                      child: _FollowButton(
                        currentUser: currentUser,
                        sellerId: sellerId,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final chat = await ref
                              .read(chatControllerProvider.notifier)
                              .getOrCreateChat(
                                productId: '',
                                productTitle: 'שיחה כללית',
                                productImageUrl: '',
                                sellerId: sellerId,
                                sellerName:
                                    sellerName ??
                                    sellerUserAsync.value?.displayName ??
                                    'מוכר',
                                buyerId: currentUser.id,
                                buyerName: currentUser.displayName ?? 'קונה',
                                buyerPhotoUrl: currentUser.photoUrl,
                              );

                          if (!context.mounted) return;

                          if (chat == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'לא ניתן לפתוח את הצ׳אט כרגע, נסה שוב',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(chatId: chat.id),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('שלח הודעה'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: Divider(height: 1)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'המוצרים של המוכר',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _AvailableSoldToggle(
                    showSold: showSold,
                    onChanged: (value) =>
                        ref
                                .read(_sellerProfileShowSoldProvider.notifier)
                                .state =
                            value,
                  ),
                ],
              ),
            ),
          ),

          productsAsync.when(
            data: (allProducts) {
              final visible = _visibleProducts(allProducts);
              final products = visible
                  .where((p) => showSold ? p.isSold : !p.isSold)
                  .toList();
              if (products.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: context.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          showSold
                              ? 'אין מוצרים שנמכרו עדיין'
                              : 'אין מוצרים זמינים כרגע',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = products[index];
                    final isLiked =
                        currentUser != null &&
                        product.likedByUserIds.contains(currentUser.id);

                    final card = ProductCard(
                      product: product,
                      isLiked: isLiked,
                      onLike: currentUser != null
                          ? () {
                              ref
                                  .read(productControllerProvider.notifier)
                                  .toggleLike(product.id, currentUser.id);
                            }
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductDetailPage(productId: product.id),
                          ),
                        );
                      },
                    );

                    if (!product.isSold) return card;

                    return Stack(
                      children: [
                        card,
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.palm,
                              borderRadius: AppRadius.chipR,
                            ),
                            child: const Text(
                              'נמכר',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }, childCount: products.length),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: StreamErrorView(
                error: error,
                title: 'לא הצלחנו לטעון את המוצרים',
                onRetry: () =>
                    ref.invalidate(productsBySellerProvider(sellerId)),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildRatingDisplay(
    BuildContext context,
    double rating,
    int reviewCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  starValue <= rating.round()
                      ? Icons.star
                      : starValue - 0.5 <= rating
                      ? Icons.star_half
                      : Icons.star_border,
                  color: Colors.amber,
                  size: 28,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'מבוסס על $reviewCount ביקורות',
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('דווח על משתמש'),
            onTap: () {
              Navigator.pop(context);
              _showReportDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('דווח על משתמש'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('בחר סיבה לדיווח:'),
            const SizedBox(height: 16),
            ...[
              'התנהגות לא הולמת',
              'הונאה או מרמה',
              'תוכן פוגעני',
              'ספאם',
              'אחר',
            ].map(
              (reason) => ListTile(
                title: Text(reason),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  try {
                    final reporter = FirebaseAuth.instance.currentUser;
                    await FirebaseFirestore.instance.collection('reports').add({
                      'reporterId': reporter?.uid,
                      'reporterEmail': reporter?.email,
                      'reportedUserId': sellerId,
                      'targetId': sellerId,
                      'targetType': 'user',
                      'targetName': sellerName ?? 'מוכר',
                      'reason': reason,
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('הדיווח נשלח בהצלחה'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('שגיאה בשליחת הדיווח: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatefulWidget {
  final UserModel currentUser;
  final String sellerId;

  const _FollowButton({required this.currentUser, required this.sellerId});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isFollowing = widget.currentUser.followingSellerIds.contains(
      widget.sellerId,
    );

    if (isFollowing) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : () => _toggle(true),
        icon: const Icon(Icons.check),
        label: const Text('עוקב'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: _busy ? null : () => _toggle(false),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('עקוב'),
    );
  }

  Future<void> _toggle(bool isFollowing) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.id)
          .update({
            'followingSellerIds': isFollowing
                ? FieldValue.arrayRemove([widget.sellerId])
                : FieldValue.arrayUnion([widget.sellerId]),
          });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('שגיאה: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}

class _AvailableSoldToggle extends StatelessWidget {
  final bool showSold;
  final ValueChanged<bool> onChanged;

  const _AvailableSoldToggle({required this.showSold, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.altSurface,
        borderRadius: AppRadius.chipR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'זמינים',
            selected: !showSold,
            onTap: () => onChanged(false),
          ),
          _ToggleChip(
            label: 'נמכרו',
            selected: showSold,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.cobalt : Colors.transparent,
          borderRadius: AppRadius.chipR,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
