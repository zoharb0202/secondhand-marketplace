import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/attachment_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/message_attachment.dart';
import '../../../../shared/models/message_model.dart';
import '../../../../shared/widgets/attachment_composer_controls.dart';
import '../../../../shared/widgets/message_attachment_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/chat_repository.dart';
import '../../utils/off_platform_payment_detector.dart';
import '../providers/chat_provider.dart';

const String _kOutgoingOffPlatformWarning =
    '⚠️ שים לב: אל תעבירו כסף מראש מחוץ לאפליקציה. '
    'שלמו רק דרך האפליקציה או במעמד האיסוף, אחרי שראיתם את המוצר.';

const String _kIncomingOffPlatformWarning =
    '⚠️ הצד השני הזכיר תשלום מחוץ לאפליקציה — אל תעבירו כסף מראש. '
    'שלמו רק דרך האפליקציה או במעמד האיסוף, אחרי שראיתם את המוצר.';

enum _SendOutcome { sent, failed, busy }

class ChatPage extends ConsumerStatefulWidget {
  final String chatId;

  const ChatPage({super.key, required this.chatId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  String? _lastMarkedReadMessageId;
  String? _newestMessageId;
  String? _viewerId;

  String? _offPlatformWarning;
  final Set<String> _warnedIncomingMessageIds = {};

  final AttachmentUploadService _attachmentService = AttachmentUploadService();
  AttachmentUpload? _activeUpload;

  Future<void>? _inFlightSend;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markReadIfViewing();
  }

  void _markReadIfViewing() {
    if (!mounted) return;
    final messageId = _newestMessageId;
    final userId = _viewerId;
    if (messageId == null || userId == null) return;

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    if (_lastMarkedReadMessageId == messageId) return;
    _lastMarkedReadMessageId = messageId;

    ref
        .read(chatControllerProvider.notifier)
        .markMessagesAsRead(widget.chatId, userId);
  }

  Future<void> _sendMessage() =>
      _send(_messageController.text, clearComposer: true);

  Future<_SendOutcome> _send(
    String rawText, {
    bool clearComposer = false,
    List<MessageAttachment> attachments = const [],
    String? messageId,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty && attachments.isEmpty) return _SendOutcome.failed;
    if (_isSending) return _SendOutcome.busy;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return _SendOutcome.failed;

    final mentionsOffPlatformPayment =
        containsOffPlatformPaymentMention(text) ||
        attachments.any((a) => containsOffPlatformPaymentMention(a.fileName));

    final completer = Completer<void>();
    _inFlightSend = completer.future;

    try {
      _isSending = true;
      if (mentionsOffPlatformPayment) {
        _offPlatformWarning = _kOutgoingOffPlatformWarning;
      }
      if (mounted) {
        setState(() {});
      }

      final sent = await ref
          .read(chatControllerProvider.notifier)
          .sendMessage(
            chatId: widget.chatId,
            senderId: currentUser.id,
            senderName: currentUser.displayName ?? 'משתמש',
            senderPhotoUrl: currentUser.photoUrl,
            content: text,
            messageId: messageId,
            attachments: attachments,
          );
      if (sent == null) {
        _showError('שגיאה בשליחת ההודעה');
        return _SendOutcome.failed;
      }
      if (clearComposer) _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      return _SendOutcome.sent;
    } catch (e) {
      _showError('שגיאה בשליחת ההודעה: $e');
      return _SendOutcome.failed;
    } finally {
      _isSending = false;
      _inFlightSend = null;
      completer.complete();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _sendAttachmentMessage({
    required List<MessageAttachment> attachments,
    required String messageId,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await _inFlightSend;
      final outcome = await _send(
        _messageController.text,
        clearComposer: true,
        attachments: attachments,
        messageId: messageId,
      );
      if (outcome != _SendOutcome.busy) return outcome == _SendOutcome.sent;
    }
    return false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _startAttachmentFlow() async {
    if (_isSending || _activeUpload != null) return;

    final source = await showAttachmentSourceSheet(context);
    if (source == null || !mounted) return;

    PickedAttachment? picked;
    try {
      picked = switch (source) {
        AttachmentSource.camera => await _attachmentService.pickFromCamera(),
        AttachmentSource.gallery => await _attachmentService.pickFromGallery(),
        AttachmentSource.file => await _attachmentService.pickFile(),
      };
    } catch (e) {
      _showError('שגיאה בבחירת הקובץ: $e');
      return;
    }
    if (picked == null || !mounted) return;

    final error = picked.validationError;
    if (error != null) {
      _showError(error);
      return;
    }

    final messageId = ref.read(chatRepositoryProvider).reserveMessageId();
    final upload = _attachmentService.startUpload(
      basePath: ChatRepository.attachmentBasePath(
        chatId: widget.chatId,
        messageId: messageId,
      ),
      picked: picked,
    );

    setState(() => _activeUpload = upload);

    MessageAttachment? attachment;
    try {
      attachment = await upload.done;
    } catch (e) {
      if (!isUploadCancellation(e)) {
        _showError('שגיאה בהעלאת הקובץ');
        debugPrint('❌ attachment upload failed (chat=${widget.chatId}): $e');
      }
      await _attachmentService.deleteQuietly(upload.storagePath);
    } finally {
      if (mounted) {
        setState(() => _activeUpload = null);
      }
    }

    if (attachment == null) return;

    if (!mounted) {
      await _attachmentService.deleteQuietly(attachment.storagePath);
      return;
    }

    final sent = await _sendAttachmentMessage(
      attachments: [attachment],
      messageId: messageId,
    );
    if (!sent) {
      await _attachmentService.deleteQuietly(attachment.storagePath);
    }
  }

  Future<void> _cancelActiveUpload() async {
    final upload = _activeUpload;
    if (upload == null) return;
    await upload.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final chatAsync = ref.watch(chatProvider(widget.chatId));
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('יש להתחבר כדי לצפות בהודעות')),
      );
    }

    return Scaffold(
      backgroundColor: context.pageBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: context.cardSurface,
        elevation: 0,
        title: chatAsync.when(
          data: (chat) {
            if (chat == null) {
              return const Text('צ\'אט', style: TextStyle());
            }
            final otherUserName = currentUser.id == chat.buyerId
                ? chat.sellerName
                : chat.buyerName;
            return Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: context.accentCobalt.withValues(alpha: 0.1),
                  child: Text(
                    otherUserName.isNotEmpty
                        ? otherUserName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.accentCobalt,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherUserName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        chat.productTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                          color: context.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Text('טוען...', style: TextStyle()),
          error: (_, __) => const Text('צ\'אט', style: TextStyle()),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  context.accentCobalt.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: AppColors.luxuryGradient3,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_outlined,
                                size: 32,
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
                        const SizedBox(height: 16),
                        Text(
                          'אין הודעות עדיין\nשלח הודעה כדי להתחיל שיחה',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textSecondary),
                        ).animate().fadeIn(delay: 200.ms),
                      ],
                    ),
                  );
                }

                _newestMessageId = messages.first.id;
                _viewerId = currentUser.id;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _markReadIfViewing(),
                );

                final latestMessage = messages.first;
                if (latestMessage.senderId != currentUser.id &&
                    !_warnedIncomingMessageIds.contains(latestMessage.id) &&
                    (containsOffPlatformPaymentMention(latestMessage.content) ||
                        latestMessage.attachments.any(
                          (a) => containsOffPlatformPaymentMention(a.fileName),
                        ))) {
                  _warnedIncomingMessageIds.add(latestMessage.id);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _offPlatformWarning = _kIncomingOffPlatformWarning;
                      });
                    }
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser.id;

                    final showDateSeparator =
                        index == messages.length - 1 ||
                        !_isSameDay(
                          message.timestamp,
                          messages[index + 1].timestamp,
                        );

                    return Column(
                      children: [
                        if (showDateSeparator)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.altSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDate(message.timestamp),
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        _MessageBubble(message: message, isMe: isMe),
                      ],
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.accentCobalt,
                  strokeWidth: 2.5,
                ),
              ),
              error: (error, _) => StreamErrorView(
                error: error,
                title: 'לא הצלחנו לטעון את ההודעות',
                onRetry: () => ref.invalidate(messagesProvider(widget.chatId)),
              ),
            ),
          ),

          if (_offPlatformWarning != null)
            _OffPlatformWarningBanner(
              message: _offPlatformWarning!,
              onDismiss: () => setState(() => _offPlatformWarning = null),
            ),

          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final upload = _activeUpload;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.cardSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (upload != null)
              AttachmentUploadStrip(
                upload: upload,
                onCancel: _cancelActiveUpload,
              ),
            Row(
              children: [
                AttachmentButton(
                  onTap: _isSending || upload != null
                      ? null
                      : _startAttachmentFlow,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.altSurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'כתוב הודעה...',
                        hintTextDirection: TextDirection.rtl,
                        hintStyle: TextStyle(
                          color: context.textTertiary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isSending,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  enabled: !_isSending,
                  label: 'שליחת הודעה',
                  child: GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _isSending ? null : AppColors.luxuryGradient1,
                        color: _isSending ? context.altSurface : null,
                        shape: BoxShape.circle,
                        boxShadow: _isSending
                            ? null
                            : [
                                BoxShadow(
                                  color: context.accentCobalt.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Center(
                        child: _isSending
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.textTertiary,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (_isSameDay(date, now)) {
      return 'היום';
    } else if (difference.inDays == 1) {
      return 'אתמול';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bubbleMaxWidth = MediaQuery.of(context).size.width * 0.75;
    final hasText = message.content.trim().isNotEmpty;
    final attachmentWidth = bubbleMaxWidth - 32;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        decoration: BoxDecoration(
          gradient: isMe ? AppColors.luxuryGradient1 : null,
          color: isMe ? null : context.cardSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: isMe
                  ? context.accentCobalt.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isMe ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.hasAttachments) ...[
              MessageAttachmentView(
                attachments: message.attachments,
                isMe: isMe,
                maxWidth: attachmentWidth,
              ),
              if (hasText) const SizedBox(height: 6),
            ],
            if (hasText)
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : context.textPrimary,
                  fontSize: 14,
                ),
                textDirection: TextDirection.rtl,
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : context.textTertiary,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? Colors.lightBlueAccent
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _OffPlatformWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _OffPlatformWarningBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: context.cardSurface,
              borderRadius: AppRadius.cardR,
              border: Border.all(color: AppColors.ink, width: 1),
              boxShadow: AppColors.offsetShadow(color: AppColors.coral),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.10),
                            borderRadius: AppRadius.chipR,
                            border: Border.all(color: context.hairline),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.coral,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        InkResponse(
                          onTap: onDismiss,
                          radius: 18,
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: context.textTertiary,
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
      ),
    );
  }
}
