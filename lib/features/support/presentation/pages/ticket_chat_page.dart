import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/attachment_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../../shared/models/message_attachment.dart';
import '../../../../shared/models/order_number.dart';
import '../../../../shared/widgets/attachment_composer_controls.dart';
import '../../../../shared/widgets/message_attachment_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/pages/order_tracking_page.dart';
import '../../data/services/order_dispute_service.dart';
import '../../data/services/support_ops_service.dart';
import '../../models/support_ticket_model.dart';
import '../../models/ticket_viewer.dart';
import '../widgets/ticket_staff_actions.dart';

const String kTicketAttachmentsStoragePrefix = 'ticket_attachments';

class TicketChatPage extends ConsumerStatefulWidget {
  final String ticketId;

  const TicketChatPage({super.key, required this.ticketId});

  @override
  ConsumerState<TicketChatPage> createState() => _TicketChatPageState();
}

class _TicketChatPageState extends ConsumerState<TicketChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupportOpsService _opsService = SupportOpsService();
  bool _isSending = false;

  late final TabController _tabs;

  final AttachmentUploadService _attachmentService = AttachmentUploadService();
  AttachmentUpload? _activeUpload;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  String _newTicketMessageId(String senderId) {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final who = senderId.isEmpty
        ? 'anon'
        : senderId.substring(0, senderId.length < 6 ? senderId.length : 6);
    return 'm_${stamp}_$who';
  }

  Future<bool> _sendMessage({
    List<MessageAttachment> attachments = const [],
    String? messageId,
  }) async {
    if (_messageController.text.trim().isEmpty && attachments.isEmpty) {
      return false;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;

    setState(() => _isSending = true);

    final isSupportReply = isStaffUser(user);

    try {
      final message = TicketMessage(
        id: messageId ?? _newTicketMessageId(user.id),
        senderId: user.id,
        senderName: user.displayName ?? (isSupportReply ? 'תמיכה' : 'משתמש'),
        isAdmin: isSupportReply,
        message: _messageController.text.trim(),
        timestamp: DateTime.now(),
        attachments: attachments,
      );

      final ticketDoc = await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId)
          .get();

      if (!ticketDoc.exists) {
        throw Exception('Ticket not found');
      }

      final ticket = SupportTicket.fromFirestore(ticketDoc);

      await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId)
          .update({
            'messages': FieldValue.arrayUnion([message.toMap()]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (isSupportReply && !ticket.isAssigned) {
        await _opsService.claimIfUnassigned(
          ticketId: widget.ticketId,
          agentId: user.id,
        );
      }

      _messageController.clear();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      return true;
    } catch (e) {
      _showError('שגיאה בשליחת הודעה: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _startAttachmentFlow() async {
    if (_isSending || _activeUpload != null) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

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

    final messageId = _newTicketMessageId(user.id);
    final upload = _attachmentService.startUpload(
      basePath:
          '$kTicketAttachmentsStoragePrefix/${widget.ticketId}/$messageId',
      picked: picked,
    );

    setState(() => _activeUpload = upload);

    MessageAttachment? attachment;
    try {
      attachment = await upload.done;
    } catch (e) {
      if (!isUploadCancellation(e)) {
        _showError('שגיאה בהעלאת הקובץ');
        debugPrint(
          '❌ ticket attachment upload failed '
          '(ticket=${widget.ticketId}): $e',
        );
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

    final sent = await _sendMessage(
      attachments: [attachment],
      messageId: messageId,
    );
    if (!sent) {
      await _attachmentService.deleteQuietly(attachment.storagePath);
    }
  }

  Future<void> _cancelActiveUpload() async {
    await _activeUpload?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('צ\'אט תמיכה'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isStaff = isStaffUser(user);
    final isAdmin = isAdminUser(user);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('צ\'אט תמיכה'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: !isStaff
            ? null
            : TabBar(
                controller: _tabs,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.person_outline, size: 18),
                    text: 'שיחה עם הלקוח',
                  ),
                  Tab(
                    icon: Icon(Icons.lock_outline, size: 18),
                    text: 'התכתבות פנימית',
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showTicketInfo(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_tickets')
            .doc(widget.ticketId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text('הפנייה לא נמצאה'));
          }

          final ticket = SupportTicket.fromFirestore(snapshot.data!);
          final hasMessages = ticket.messages.isNotEmpty;

          final customerThread = Column(
            children: [
              _buildTicketHeader(
                ticket,
                isStaff: isStaff,
                isAdmin: isAdmin,
                userId: user.id,
              ),

              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: 1 + (hasMessages ? ticket.messages.length : 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          if (ticket.orderId != null)
                            _OrderContextCard(ticket: ticket),
                        ],
                      );
                    }
                    if (!hasMessages) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'אין הודעות עדיין\nשלח הודעה כדי להתחיל שיחה',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }
                    final message = ticket.messages[index - 1];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        index == 1 ? 16 : 0,
                        16,
                        0,
                      ),
                      child: _MessageBubble(message: message),
                    );
                  },
                ),
              ),

              NavBarClearanceInset(child: _buildMessageInput(ticket)),
            ],
          );

          if (!isStaff) return customerThread;

          return TabBarView(
            controller: _tabs,
            children: [
              customerThread,
              TicketInternalThread(ticketId: widget.ticketId),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTicketHeader(
    SupportTicket ticket, {
    required bool isStaff,
    required bool isAdmin,
    String? userId,
  }) {
    Color statusColor;
    switch (ticket.status) {
      case TicketStatus.open:
        statusColor = Colors.orange;
        break;
      case TicketStatus.inProgress:
        statusColor = Colors.blue;
        break;
      case TicketStatus.resolved:
        statusColor = Colors.green;
        break;
      case TicketStatus.closed:
        statusColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ticket.category.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ticket.subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  ticket.status.displayName,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (ticket.assigneeName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'מטופל על ידי: ${ticket.assigneeName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (isStaff) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                TicketAssigneeChip(ticket: ticket, currentUserId: userId),
                const SizedBox(width: 6),
                TicketPriorityChip(priority: ticket.priorityLevel),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => showTicketActionsSheet(
                    context: context,
                    ticket: ticket,
                    isAdmin: isAdmin,
                    currentUserId: userId ?? '',
                  ),
                  icon: const Icon(Icons.build_outlined, size: 16),
                  label: const Text('תפעול'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(SupportTicket ticket) {
    final isClosed = ticket.status == TicketStatus.closed;

    if (isClosed) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey.shade200,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text(
              'הפנייה סגורה',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final upload = _activeUpload;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
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
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'הקלד הודעה...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => !_isSending ? _sendMessage() : null,
                  enabled: !_isSending,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTicketInfo() {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_tickets')
            .doc(widget.ticketId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const AlertDialog(content: Text('טוען...'));
          }

          final ticket = SupportTicket.fromFirestore(snapshot.data!);

          return AlertDialog(
            title: const Text('פרטי הפנייה'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _InfoRow(
                    label: 'קטגוריה',
                    value:
                        '${ticket.category.icon} ${ticket.category.displayName}',
                  ),
                  _InfoRow(label: 'סטטוס', value: ticket.status.displayName),
                  _InfoRow(
                    label: 'נוצר בתאריך',
                    value: _formatDateTime(ticket.createdAt),
                  ),
                  if (ticket.updatedAt != null)
                    _InfoRow(
                      label: 'עודכן לאחרונה',
                      value: _formatDateTime(ticket.updatedAt!),
                    ),
                  if (ticket.assigneeName != null)
                    _InfoRow(
                      label: 'מטופל על ידי',
                      value: ticket.assigneeName!,
                    ),
                  _InfoRow(
                    label: 'עדיפות',
                    value: ticket.priorityLevel.displayName,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'תיאור:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(ticket.description),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('סגור'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _MessageBubble extends StatelessWidget {
  final TicketMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.isAdmin;
    final hasText = message.message.trim().isNotEmpty;
    final attachmentWidth = (MediaQuery.of(context).size.width - 112).clamp(
      120.0,
      320.0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isAdmin
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAdmin) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.support_agent,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAdmin
                    ? Colors.grey.shade200
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAdmin ? 4 : 16),
                  bottomRight: Radius.circular(isAdmin ? 16 : 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isAdmin
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 4),
                        const Text(
                          '•',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'תמיכה',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (message.hasAttachments) ...[
                    MessageAttachmentView(
                      attachments: message.attachments,
                      isMe: false,
                      maxWidth: attachmentWidth,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (hasText) ...[
                    Text(message.message, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          if (!isAdmin) const SizedBox(width: 48),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'אתמול ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _OrderContextCard extends ConsumerWidget {
  final SupportTicket ticket;

  const _OrderContextCard({required this.ticket});

  static const Map<String, String> _issueLabels = {
    'arrived_broken': 'הגיע שבור/פגום',
    'not_as_described': 'לא תואם את התיאור',
    'never_arrived': 'לא הגיע',
    'wrong_item': 'התקבל מוצר אחר',
    'other': 'אחר',
  };

  static const Map<String, String> _resolutionLabels = {
    'refund': 'החזר כספי מלא',
    'replacement': 'החלפה',
    'partial_refund': 'החזר חלקי',
    'other': 'משהו אחר',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final viewer = TicketViewer.of(ticket, user);

    final issue = ticket.orderIssue;
    final orderId = ticket.orderId;
    if (orderId == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.report_problem_outlined,
                size: 18,
                color: AppColors.warning,
              ),
              SizedBox(width: 6),
              Text(
                'פנייה על הזמנה',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (issue?['orderNumber'] != null)
            _InfoRow(
              label: orderNumberLabelHe,
              value: orderNumberDisplay(issue!['orderNumber'].toString()) ?? '',
            ),
          if (issue?['productTitle'] != null)
            _InfoRow(label: 'מוצר', value: issue!['productTitle'].toString()),
          if (ticket.issueType != null)
            _InfoRow(
              label: 'סוג בעיה',
              value: _issueLabels[ticket.issueType] ?? ticket.issueType!,
            ),
          if (issue?['itemInPossession'] != null)
            _InfoRow(
              label: 'המוצר אצל הקונה',
              value: issue!['itemInPossession'] == true ? 'כן' : 'לא',
            ),
          if (issue?['preferredResolution'] != null)
            _InfoRow(
              label: 'פתרון מבוקש',
              value:
                  _resolutionLabels[issue!['preferredResolution']] ??
                  issue['preferredResolution'].toString(),
            ),
          if (issue?['totalAmount'] != null)
            _InfoRow(label: 'סכום ההזמנה', value: '₪${issue!['totalAmount']}'),
          const SizedBox(height: 8),
          if (viewer.isReporterBuyer)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingPage(orderId: orderId),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('פתח את ההזמנה'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          if (viewer.isStaff &&
              ticket.status != TicketStatus.resolved &&
              ticket.status != TicketStatus.closed) ...[
            const Divider(height: 24),
            const Text(
              'פתרון הפנייה',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _StaffResolutionBar(orderId: orderId),
          ],
        ],
      ),
    );
  }
}

class _StaffResolutionBar extends StatefulWidget {
  final String orderId;

  const _StaffResolutionBar({required this.orderId});

  @override
  State<_StaffResolutionBar> createState() => _StaffResolutionBarState();
}

class _StaffResolutionBarState extends State<_StaffResolutionBar> {
  bool _isSubmitting = false;

  Future<void> _resolve(
    String resolution,
    String confirmTitle,
    String confirmBody,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('אישור'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    final result = await OrderDisputeService().resolveOrderDispute(
      orderId: widget.orderId,
      resolution: resolution,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              (result.success ? 'הפנייה נפתרה' : 'שגיאה בפתרון הפנייה'),
        ),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton(
          onPressed: () => _resolve(
            'refund_buyer',
            'ביטול והחזר לקונה',
            'הפעולה תבטל את ההזמנה, תחזיר את המוצר למלאי ותחזיר תשלום בכרטיס אם בוצע. להמשיך?',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('ביטול והחזר לקונה'),
        ),
        ElevatedButton(
          onPressed: () => _resolve(
            'release_seller',
            'השלמת ההזמנה',
            'הפעולה תסגור את הפנייה לטובת המוכר ותסמן את ההזמנה כהושלמה. להמשיך?',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: const Text('השלמת ההזמנה'),
        ),
        OutlinedButton(
          onPressed: () => _resolve(
            'dismissed',
            'סגירה ללא פעולה',
            'הפנייה תיסגר וההזמנה תחזור למצבה הקודם. להמשיך?',
          ),
          child: const Text('סגירה ללא פעולה'),
        ),
      ],
    );
  }
}
