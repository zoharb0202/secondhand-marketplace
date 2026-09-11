import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/animated_gradient.dart';
import '../../../../core/widgets/gradient_border_card.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_page.dart';

class ChatsListPage extends ConsumerWidget {
  const ChatsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: context.pageBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.luxuryGradient1,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.login_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'יש להתחבר כדי לצפות בהודעות',
                style: TextStyle(color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final chatsAsync = ref.watch(userChatsProvider(currentUser.id));

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: AppBar(
        title: GradientText(
          'הודעות',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: chatsAsync.when(
        data: (chats) {
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.luxuryGradient3,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      )
                      .animate()
                      .scale(
                        begin: const Offset(0, 0),
                        end: const Offset(1, 1),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 300.ms),
                  const SizedBox(height: 20),
                  Text(
                    'אין הודעות',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    'התחל שיחה עם מוכר כדי לראות הודעות כאן',
                    style: TextStyle(color: context.textTertiary),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: NavBarClearance.pad(
              context,
              base: const EdgeInsets.all(16),
            ),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListItem(
                chat: chat,
                currentUserId: currentUser.id,
                index: index,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(chatId: chat.id),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'שגיאה בטעינת ההודעות',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _isPermissionError(error)
                      ? 'החיבור לשרת נותק. נסו שוב.'
                      : 'לא הצלחנו לטעון את השיחות. בדקו את החיבור לאינטרנט ונסו שוב.',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(userChatsProvider(currentUser.id)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('נסו שוב'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final ChatModel chat;
  final String currentUserId;
  final int index;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.chat,
    required this.currentUserId,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUserName = currentUserId == chat.buyerId
        ? chat.sellerName
        : chat.buyerName;

    final unreadCount = currentUserId == chat.buyerId
        ? chat.buyerUnreadCount
        : chat.sellerUnreadCount;

    return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GradientBorderCard(
            borderRadius: 16,
            borderWidth: unreadCount > 0 ? 1.5 : 0,
            animationDuration: const Duration(seconds: 4),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(unreadCount > 0 ? 2.5 : 0),
                      decoration: unreadCount > 0
                          ? BoxDecoration(
                              gradient: AppColors.luxuryGradient1,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: unreadCount > 0
                            ? context.cardSurface
                            : context.altSurface,
                        child: CircleAvatar(
                          radius: unreadCount > 0 ? 23 : 26,
                          backgroundColor: context.accentCobalt.withValues(
                            alpha: 0.08,
                          ),
                          child: Text(
                            otherUserName.isNotEmpty
                                ? otherUserName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.accentCobalt,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  otherUserName,
                                  style: TextStyle(
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 15,
                                    color: context.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatTime(lastMessageAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: unreadCount > 0
                                      ? context.accentCobalt
                                      : context.textTertiary,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            chat.productTitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  previewLine,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: unreadCount > 0
                                        ? context.textPrimary
                                        : context.textSecondary,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.luxuryGradient1,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: 400.ms)
        .moveX(begin: 20, end: 0, delay: (60 * index).ms, duration: 400.ms);
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'אתמול';
    } else if (difference.inDays < 7) {
      const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
      return days[dateTime.weekday % 7];
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  DateTime get lastMessageAt => chat.lastMessageTime ?? chat.createdAt;

  String get previewLine {
    final preview = chat.lastMessage?.trim() ?? '';
    return preview.isEmpty ? 'התחל שיחה' : preview;
  }
}

bool _isPermissionError(Object error) =>
    error.toString().contains('permission-denied');
