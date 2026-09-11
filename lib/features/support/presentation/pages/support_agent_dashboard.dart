import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../models/support_ticket_model.dart';
import 'ticket_chat_page.dart';

class SupportAgentDashboard extends ConsumerStatefulWidget {
  const SupportAgentDashboard({super.key});

  @override
  ConsumerState<SupportAgentDashboard> createState() =>
      _SupportAgentDashboardState();
}

class _SupportAgentDashboardState extends ConsumerState<SupportAgentDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.headset_mic, size: 24),
            const SizedBox(width: 8),
            const Text('דשבורד שירות לקוחות'),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'פתוחות'),
            Tab(text: 'בטיפול'),
            Tab(text: 'נפתרו'),
            Tab(text: 'הכל'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => _showStatistics(),
          ),
        ],
      ),
      body: NavBarClearanceInset(
        child: TabBarView(
          controller: _tabController,
          children: [
            _TicketsList(status: TicketStatus.open),
            _TicketsList(status: TicketStatus.inProgress),
            _TicketsList(status: TicketStatus.resolved),
            _TicketsList(status: null),
          ],
        ),
      ),
    );
  }

  void _showStatistics() {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_tickets')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(content: CircularProgressIndicator());
          }

          final tickets = snapshot.data!.docs
              .map((doc) => SupportTicket.fromFirestore(doc))
              .toList();

          final openCount = tickets
              .where((t) => t.status == TicketStatus.open)
              .length;
          final inProgressCount = tickets
              .where((t) => t.status == TicketStatus.inProgress)
              .length;
          final resolvedCount = tickets
              .where((t) => t.status == TicketStatus.resolved)
              .length;
          final closedCount = tickets
              .where((t) => t.status == TicketStatus.closed)
              .length;
          final totalCount = tickets.length;

          final respondedTickets = tickets
              .where((t) => t.updatedAt != null)
              .toList();
          final avgResponseMinutes = respondedTickets.isNotEmpty
              ? respondedTickets
                        .map(
                          (t) => t.updatedAt!.difference(t.createdAt).inMinutes,
                        )
                        .fold(0, (a, b) => a + b) ~/
                    respondedTickets.length
              : 0;

          return AlertDialog(
            title: const Text('סטטיסטיקות'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(
                    label: 'סה"כ פניות',
                    value: totalCount.toString(),
                    color: AppColors.primary,
                  ),
                  const Divider(),
                  _StatRow(
                    label: 'פתוחות',
                    value: openCount.toString(),
                    color: Colors.orange,
                  ),
                  _StatRow(
                    label: 'בטיפול',
                    value: inProgressCount.toString(),
                    color: Colors.blue,
                  ),
                  _StatRow(
                    label: 'נפתרו',
                    value: resolvedCount.toString(),
                    color: Colors.green,
                  ),
                  _StatRow(
                    label: 'סגורות',
                    value: closedCount.toString(),
                    color: Colors.grey,
                  ),
                  const Divider(),
                  _StatRow(
                    label: 'זמן תגובה ממוצע',
                    value: avgResponseMinutes > 0
                        ? '$avgResponseMinutes דקות'
                        : 'לא זמין',
                    color: AppColors.textPrimary,
                  ),
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
}

class _TicketsList extends ConsumerWidget {
  final TicketStatus? status;

  const _TicketsList({this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'support_tickets',
    );

    if (status != null) {
      query = query.where('status', isEqualTo: status!.name);
    }

    query = query.orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text('שגיאה: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tickets = snapshot.data!.docs
            .map((doc) => SupportTicket.fromFirestore(doc))
            .toList();

        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  status == null
                      ? 'אין פניות'
                      : 'אין פניות ${status!.displayName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return _SupportTicketCard(
              ticket: ticket,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TicketChatPage(ticketId: ticket.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SupportTicketCard extends ConsumerWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const _SupportTicketCard({required this.ticket, required this.onTap});

  static const Map<String, String> _issueTypeLabels = {
    'arrived_broken': 'הגיע שבור/פגום',
    'not_as_described': 'לא תואם את התיאור',
    'never_arrived': 'לא הגיע',
    'wrong_item': 'התקבל מוצר אחר',
    'other': 'אחר',
  };

  String _issueTypeLabel(String issueType) =>
      _issueTypeLabels[issueType] ?? issueType;

  Color _getStatusColor() {
    switch (ticket.status) {
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

  Color _getPriorityColor() {
    final now = DateTime.now();
    final age = now.difference(ticket.createdAt);

    if (age.inHours >= 24 && ticket.status == TicketStatus.open) {
      return Colors.red;
    }
    if (age.inHours >= 12 && ticket.status == TicketStatus.open) {
      return Colors.orange;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isAssignedToMe = ticket.assignedAdminId == user?.id;
    final hasUnreadMessages = ticket.messages.any(
      (m) =>
          !m.isAdmin &&
          m.timestamp.isAfter(
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isAssignedToMe ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isAssignedToMe
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    ticket.category.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ticket.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.category.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
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
                      color: _getStatusColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor()),
                    ),
                    child: Text(
                      ticket.status.displayName,
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (ticket.orderId != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.report_problem_outlined,
                        size: 14,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'בעיה בהזמנה'
                        '${ticket.issueType != null ? ' · ${_issueTypeLabel(ticket.issueType!)}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              Text(
                ticket.subject,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(ticket.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.message, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    ticket.messages.length.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (hasUnreadMessages) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'חדש',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isAssignedToMe)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'בטיפולי',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'לפני ${diff.inMinutes} דקות';
      }
      return 'לפני ${diff.inHours} שעות';
    } else if (diff.inDays == 1) {
      return 'אתמול';
    } else if (diff.inDays < 7) {
      return 'לפני ${diff.inDays} ימים';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
