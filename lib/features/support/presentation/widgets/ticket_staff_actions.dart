import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/support_ops_service.dart';
import '../../models/support_ticket_model.dart';
import '../../models/ticket_internal_models.dart';

const Color _internalAmber = Color(0xFFFFF3CD);
const Color _internalAmberBorder = Color(0xFFE8930C);

class TicketAssigneeChip extends StatelessWidget {
  final SupportTicket ticket;

  final String? currentUserId;

  const TicketAssigneeChip({
    super.key,
    required this.ticket,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isMine =
        ticket.assigneeId != null && ticket.assigneeId == currentUserId;
    final assigned = ticket.isAssigned;
    final color = !assigned
        ? AppColors.textTertiary
        : (isMine ? AppColors.primary : AppColors.textSecondary);
    final label = !assigned
        ? 'לא משויך'
        : (isMine ? 'בטיפולי' : ticket.assigneeName ?? 'משויך');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            assigned ? Icons.person_outline : Icons.person_off_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class TicketPriorityChip extends StatelessWidget {
  final TicketPriority priority;

  const TicketPriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    if (priority == TicketPriority.normal) return const SizedBox.shrink();
    final color = Color(int.parse(priority.colorHex.replaceFirst('#', '0xFF')));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            'עדיפות ${priority.displayName}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTicketActionsSheet({
  required BuildContext context,
  required SupportTicket ticket,
  required bool isAdmin,
  required String currentUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.build_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'תפעול הפנייה',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TicketAssigneeChip(
                  ticket: ticket,
                  currentUserId: currentUserId,
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.person_add_alt, color: AppColors.primary),
            title: const Text('שיוך לנציג'),
            subtitle: Text(
              ticket.isAssigned
                  ? 'כרגע: ${ticket.assigneeName ?? "משויך"}'
                  : 'הפנייה אינה משויכת',
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              showTicketAssignSheet(
                context: context,
                ticket: ticket,
                isAdmin: isAdmin,
                currentUserId: currentUserId,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppColors.warning),
            title: const Text('עדיפות'),
            subtitle: Text('כרגע: ${ticket.priorityLevel.displayName}'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showPriorityDialog(context, ticket);
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: AppColors.info),
            title: const Text('שינוי סטטוס'),
            subtitle: Text('כרגע: ${ticket.status.displayName}'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showStatusDialog(context, ticket);
            },
          ),
          ListTile(
            leading: const Icon(Icons.task_alt, color: AppColors.success),
            title: const Text('סגירת פנייה עם סיכום'),
            subtitle: const Text('סיכום הטיפול נשמר ביומן ולא ניתן למחיקה'),
            onTap: () {
              Navigator.pop(sheetContext);
              showTicketCloseDialog(context, ticket);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.textSecondary),
            title: const Text('יומן פעולות'),
            subtitle: const Text('מי עשה מה ומתי — לצפייה בלבד'),
            onTap: () {
              Navigator.pop(sheetContext);
              showTicketAuditSheet(context, ticket.id);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> showTicketAssignSheet({
  required BuildContext context,
  required SupportTicket ticket,
  required bool isAdmin,
  required String currentUserId,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final service = SupportOpsService();

  Future<void> apply(
    BuildContext sheetContext,
    String? agentId,
    String successText,
  ) async {
    Navigator.pop(sheetContext);
    final result = await service.assignTicket(
      ticketId: ticket.id,
      agentId: agentId,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? successText
              : (result.message ?? 'שגיאה בשיוך הפנייה'),
        ),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.person_add_alt,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'שיוך הפנייה לנציג',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!isAdmin)
              ListTile(
                leading: const Icon(
                  Icons.pan_tool_alt_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('קח לטיפולי'),
                subtitle: ticket.isAssigned
                    ? const Text('הפנייה כבר משויכת — פנה למנהל לשינוי')
                    : null,
                enabled: !ticket.isAssigned,
                onTap: ticket.isAssigned
                    ? null
                    : () => apply(
                        sheetContext,
                        currentUserId,
                        'הפנייה שויכה אליך',
                      ),
              )
            else
              Flexible(
                child: FutureBuilder<List<SupportAgentOption>>(
                  future: service.listSupportAgents(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final agents =
                        snapshot.data ?? const <SupportAgentOption>[];
                    if (agents.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'לא נמצאו נציגי שירות פעילים',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        ...agents.map((agent) {
                          final isCurrent = agent.id == ticket.assigneeId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: agent.isAdmin
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.surfaceVariant,
                              child: Text(agent.isAdmin ? '👑' : '🎧'),
                            ),
                            title: Text(agent.name),
                            subtitle: Text(
                              agent.isAdmin ? 'מנהל' : 'נציג שירות',
                            ),
                            trailing: isCurrent
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                  )
                                : null,
                            onTap: isCurrent
                                ? null
                                : () => apply(
                                    sheetContext,
                                    agent.id,
                                    'הפנייה שויכה ל${agent.name}',
                                  ),
                          );
                        }),
                        if (ticket.isAssigned) ...[
                          const Divider(),
                          ListTile(
                            leading: const Icon(
                              Icons.person_off_outlined,
                              color: AppColors.error,
                            ),
                            title: const Text(
                              'בטל שיוך',
                              style: TextStyle(color: AppColors.error),
                            ),
                            onTap: () =>
                                apply(sheetContext, null, 'שיוך הפנייה בוטל'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showStatusDialog(BuildContext context, SupportTicket ticket) {
  final messenger = ScaffoldMessenger.of(context);
  final service = SupportOpsService();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('שינוי סטטוס'),
      children: TicketStatus.values.map((status) {
        return SimpleDialogOption(
          onPressed: () async {
            Navigator.pop(dialogContext);
            if (status == TicketStatus.closed) {
              if (context.mounted) showTicketCloseDialog(context, ticket);
              return;
            }
            final result = await service.updateStatus(
              ticketId: ticket.id,
              status: status,
            );
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  result.success
                      ? 'הסטטוס עודכן ל${status.displayName}'
                      : (result.message ?? 'שגיאה בעדכון הסטטוס'),
                ),
                backgroundColor: result.success
                    ? AppColors.success
                    : AppColors.error,
              ),
            );
          },
          child: Row(
            children: [
              Icon(
                status == ticket.status
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Text(status.displayName),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

Future<void> _showPriorityDialog(BuildContext context, SupportTicket ticket) {
  final messenger = ScaffoldMessenger.of(context);
  final service = SupportOpsService();
  final current = ticket.priorityLevel;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('עדיפות הפנייה'),
      children: TicketPriority.values.map((priority) {
        final color = Color(
          int.parse(priority.colorHex.replaceFirst('#', '0xFF')),
        );
        return SimpleDialogOption(
          onPressed: () async {
            Navigator.pop(dialogContext);
            final result = await service.setPriority(
              ticketId: ticket.id,
              priority: priority,
            );
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  result.success
                      ? 'העדיפות עודכנה ל${priority.displayName}'
                      : (result.message ?? 'שגיאה בעדכון העדיפות'),
                ),
                backgroundColor: result.success
                    ? AppColors.success
                    : AppColors.error,
              ),
            );
          },
          child: Row(
            children: [
              Icon(
                priority == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 12),
              Text(priority.displayName),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

Future<void> showTicketCloseDialog(BuildContext context, SupportTicket ticket) {
  final messenger = ScaffoldMessenger.of(context);
  final service = SupportOpsService();
  final controller = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('סגירת פנייה'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'סיכום הטיפול יישמר ביומן הפעולות של הפנייה ולא ניתן יהיה לערוך או למחוק אותו.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'מה נעשה בפנייה?',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('ביטול'),
        ),
        ElevatedButton(
          onPressed: () async {
            final note = controller.text.trim();
            if (note.isEmpty) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('יש להזין סיכום טיפול'),
                  backgroundColor: AppColors.error,
                ),
              );
              return;
            }
            Navigator.pop(dialogContext);
            final result = await service.updateStatus(
              ticketId: ticket.id,
              status: TicketStatus.closed,
              note: note,
            );
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  result.success
                      ? 'הפנייה נסגרה'
                      : (result.message ?? 'שגיאה בסגירת הפנייה'),
                ),
                backgroundColor: result.success
                    ? AppColors.success
                    : AppColors.error,
              ),
            );
          },
          child: const Text('סגור פנייה'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<void> showTicketAuditSheet(BuildContext context, String ticketId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'יומן פעולות',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: StreamBuilder<List<TicketAuditEntry>>(
                stream: SupportOpsService().auditTrailStream(ticketId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('שגיאה בטעינת היומן'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final entries = snapshot.data!;
                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'עדיין לא בוצעו פעולות בפנייה',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        dense: true,
                        leading: Text(
                          entry.actorRole == 'admin' ? '👑' : '🎧',
                          style: const TextStyle(fontSize: 18),
                        ),
                        title: Text(
                          entry.displayText,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${entry.actorName} · ${formatTicketDateTime(entry.at)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TicketInternalThread extends StatefulWidget {
  final String ticketId;

  const TicketInternalThread({super.key, required this.ticketId});

  @override
  State<TicketInternalThread> createState() => _TicketInternalThreadState();
}

class _TicketInternalThreadState extends State<TicketInternalThread> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupportOpsService _service = SupportOpsService();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final result = await _service.addInternalNote(
      ticketId: widget.ticketId,
      text: text,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.success) {
      _controller.clear();
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'שגיאה בשליחת ההודעה הפנימית'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _internalAmber,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _internalAmberBorder.withValues(alpha: 0.18),
              border: const Border(
                bottom: BorderSide(color: _internalAmberBorder, width: 2),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'התכתבות פנימית — הלקוח אינו רואה אותה',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TicketInternalNote>>(
              stream: _service.internalNotesStream(widget.ticketId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('שגיאה בטעינת ההתכתבות הפנימית'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notes = snapshot.data!;
                if (notes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'אין עדיין התכתבות פנימית\nכאן מנהל ונציג מתייעצים בלי שהלקוח רואה',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  itemBuilder: (context, index) =>
                      _InternalNoteBubble(note: notes[index]),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: _internalAmberBorder, width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'הודעה פנימית לצוות...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _internalAmber,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_isSending,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _internalAmberBorder,
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
                        : const Icon(Icons.lock_outline, color: Colors.white),
                    onPressed: _isSending ? null : _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InternalNoteBubble extends StatelessWidget {
  final TicketInternalNote note;

  const _InternalNoteBubble({required this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _internalAmberBorder.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  note.isAdminAuthor ? '👑' : '🎧',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  note.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  note.isAdminAuthor ? 'מנהל' : 'נציג שירות',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(note.text, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              formatTicketDateTime(note.createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatTicketDateTime(DateTime? value) {
  if (value == null) return 'עכשיו';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} ${two(value.hour)}:${two(value.minute)}';
}
