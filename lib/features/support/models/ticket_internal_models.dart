import 'package:cloud_firestore/cloud_firestore.dart';

class TicketInternalNote {
  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime? createdAt;

  TicketInternalNote({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    this.createdAt,
  });

  factory TicketInternalNote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TicketInternalNote(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'צוות',
      authorRole: data['authorRole'] ?? 'supportAgent',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isAdminAuthor => authorRole == 'admin';
}

class TicketAuditEntry {
  final String id;
  final String action;
  final String actorId;
  final String actorName;
  final String actorRole;
  final Map<String, dynamic> details;
  final DateTime? at;

  TicketAuditEntry({
    required this.id,
    required this.action,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    this.details = const {},
    this.at,
  });

  factory TicketAuditEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TicketAuditEntry(
      id: doc.id,
      action: data['action'] ?? '',
      actorId: data['actorId'] ?? '',
      actorName: data['actorName'] ?? 'צוות',
      actorRole: data['actorRole'] ?? 'supportAgent',
      details: data['details'] != null
          ? Map<String, dynamic>.from(data['details'] as Map)
          : const {},
      at: (data['at'] as Timestamp?)?.toDate(),
    );
  }

  String get displayText {
    switch (action) {
      case 'assigned':
        final to = details['toAgentName'];
        return to != null ? 'שייך/ה את הפנייה ל$to' : 'שייך/ה את הפנייה';
      case 'unassigned':
        return 'ביטל/ה את שיוך הפנייה';
      case 'status_changed':
        return 'שינה/תה סטטוס: ${_statusLabel(details['from'])} ← ${_statusLabel(details['to'])}';
      case 'priority_changed':
        return 'שינה/תה עדיפות: ${_priorityLabel(details['from'])} ← ${_priorityLabel(details['to'])}';
      case 'internal_note':
        return 'הוסיף/ה הודעה פנימית';
      default:
        return action;
    }
  }

  static String _statusLabel(dynamic wire) {
    switch (wire) {
      case 'open':
        return 'פתוחה';
      case 'inProgress':
        return 'בטיפול';
      case 'resolved':
        return 'נפתרה';
      case 'closed':
        return 'סגורה';
      default:
        return wire?.toString() ?? '—';
    }
  }

  static String _priorityLabel(dynamic wire) {
    switch (wire) {
      case 'low':
        return 'נמוכה';
      case 'normal':
        return 'רגילה';
      case 'high':
        return 'גבוהה';
      case 'urgent':
        return 'דחופה';
      default:
        return wire?.toString() ?? '—';
    }
  }
}
