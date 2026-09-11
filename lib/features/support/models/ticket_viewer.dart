import '../../../core/constants/user_roles.dart';
import '../../../shared/models/user_model.dart';
import 'support_ticket_model.dart';

enum TicketViewerRole { reporterBuyer, staff, other }

bool isStaffUser(UserModel? user) =>
    user != null &&
    (user.isAdmin ||
        user.role == UserRole.admin ||
        user.role == UserRole.supportAgent);

bool isAdminUser(UserModel? user) =>
    user != null && (user.isAdmin || user.role == UserRole.admin);

class TicketViewer {
  final TicketViewerRole role;
  final bool isAdmin;

  const TicketViewer({required this.role, required this.isAdmin});

  bool get isStaff => role == TicketViewerRole.staff;
  bool get isReporterBuyer => role == TicketViewerRole.reporterBuyer;

  factory TicketViewer.of(SupportTicket ticket, UserModel? user) {
    final TicketViewerRole role;
    if (isStaffUser(user)) {
      role = TicketViewerRole.staff;
    } else if (user != null && ticket.userId == user.id) {
      role = TicketViewerRole.reporterBuyer;
    } else {
      role = TicketViewerRole.other;
    }
    return TicketViewer(role: role, isAdmin: isAdminUser(user));
  }
}
