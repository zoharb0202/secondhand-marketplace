import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../models/support_ticket_model.dart';
import '../widgets/ticket_staff_actions.dart';
import 'ticket_chat_page.dart';

enum _AssignmentScope { all, mine, unassigned }

class AdminSupportPanel extends ConsumerStatefulWidget {
  const AdminSupportPanel({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AdminSupportPanel> createState() => _AdminSupportPanelState();
}

class _AdminSupportPanelState extends ConsumerState<AdminSupportPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TicketStatus? _filterStatus;
  _AssignmentScope _scope = _AssignmentScope.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _filterStatus = null;
            break;
          case 1:
            _filterStatus = TicketStatus.open;
            break;
          case 2:
            _filterStatus = TicketStatus.inProgress;
            break;
          case 3:
            _filterStatus = TicketStatus.resolved;
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isAdmin =
        user != null && (user.isAdmin || user.role == UserRole.admin);

    final filterTabs = TabBar(
      controller: _tabController,
      labelColor: widget.embedded ? AppColors.primary : Colors.white,
      unselectedLabelColor: widget.embedded
          ? AppColors.textSecondary
          : Colors.white70,
      indicatorColor: widget.embedded ? AppColors.primary : Colors.white,
      tabs: const [
        Tab(text: 'הכל'),
        Tab(text: 'פתוחות'),
        Tab(text: 'בטיפול'),
        Tab(text: 'נפתרו'),
      ],
    );

    final ticketList = StreamBuilder<QuerySnapshot>(
      stream: _getTicketsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('שגיאה: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'אין פניות',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final tickets = snapshot.data!.docs
            .map((doc) => SupportTicket.fromFirestore(doc))
            .where((t) => _matchesScope(t, user?.id))
            .toList();

        if (tickets.isEmpty) {
          return const Center(
            child: Text(
              'אין פניות בסינון הזה',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          );
        }

        tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            return _buildTicketCard(
              tickets[index],
              isAdmin: isAdmin,
              currentUserId: user?.id,
            );
          },
        );
      },
    );

    final scopeChips = Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _scopeChip(_AssignmentScope.all, 'הכל'),
          const SizedBox(width: 8),
          _scopeChip(_AssignmentScope.mine, 'שלי'),
          const SizedBox(width: 8),
          _scopeChip(_AssignmentScope.unassigned, 'לא משויך'),
        ],
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Material(color: AppColors.surface, child: filterTabs),
          scopeChips,
          Expanded(child: ticketList),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('פאנל שירות לקוחות'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: filterTabs,
      ),
      body: Column(
        children: [
          scopeChips,
          Expanded(child: ticketList),
        ],
      ),
    );
  }

  Widget _scopeChip(_AssignmentScope scope, String label) {
    final selected = _scope == scope;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _scope = scope),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  bool _matchesScope(SupportTicket ticket, String? userId) {
    switch (_scope) {
      case _AssignmentScope.all:
        return true;
      case _AssignmentScope.mine:
        return userId != null && ticket.assigneeId == userId;
      case _AssignmentScope.unassigned:
        return !ticket.isAssigned;
    }
  }

  Stream<QuerySnapshot> _getTicketsStream() {
    Query query = FirebaseFirestore.instance.collection('support_tickets');

    if (_filterStatus != null) {
      query = query.where('status', isEqualTo: _filterStatus!.name);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildTicketCard(
    SupportTicket ticket, {
    required bool isAdmin,
    String? currentUserId,
  }) {
    final statusColor = _getStatusColor(ticket.status);
    final timeSinceCreated = _getTimeSinceCreated(ticket.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => _openTicketDetails(ticket),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket.category.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.subject,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              ticket.category.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              ticket.userName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      ticket.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                ticket.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    timeSinceCreated,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (ticket.messages.length > 1) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.message_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${ticket.messages.length} הודעות',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  if (ticket.internalNotesCount > 0) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.lock_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${ticket.internalNotesCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  TicketAssigneeChip(
                    ticket: ticket,
                    currentUserId: currentUserId,
                  ),
                  const SizedBox(width: 6),
                  TicketPriorityChip(priority: ticket.priorityLevel),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => showTicketAssignSheet(
                      context: context,
                      ticket: ticket,
                      isAdmin: isAdmin,
                      currentUserId: currentUserId ?? '',
                    ),
                    icon: const Icon(Icons.person_add_alt, size: 16),
                    label: Text(ticket.isAssigned ? 'שנה שיוך' : 'שייך'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return Colors.orange;
      case TicketStatus.inProgress:
        return Colors.blue;
      case TicketStatus.resolved:
        return Colors.green;
      case TicketStatus.closed:
        return Colors.grey;
    }
  }

  String _getTimeSinceCreated(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'עכשיו';
    } else if (difference.inMinutes < 60) {
      return 'לפני ${difference.inMinutes} דקות';
    } else if (difference.inHours < 24) {
      return 'לפני ${difference.inHours} שעות';
    } else if (difference.inDays < 7) {
      return 'לפני ${difference.inDays} ימים';
    } else {
      return 'לפני ${(difference.inDays / 7).floor()} שבועות';
    }
  }

  void _openTicketDetails(SupportTicket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketChatPage(ticketId: ticket.id),
      ),
    );
  }
}
