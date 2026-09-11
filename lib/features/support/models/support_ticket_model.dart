import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/message_attachment.dart';

enum TicketStatus { open, inProgress, resolved, closed }

enum TicketCategory { technical, payment, account, product, other }

enum TicketPriority { low, normal, high, urgent }

class SupportTicket {
  final String id;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userPhone;

  final TicketCategory category;
  final String subject;
  final String description;
  final List<String> attachmentUrls;

  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  final String? assignedAdminId;
  final String? assignedAdminName;
  final String? adminNotes;

  final String? assignedAgentId;
  final String? assignedAgentName;
  final DateTime? assignedAt;

  final int internalNotesCount;

  final String? resolutionNote;

  final List<TicketMessage> messages;

  final String? orderId;
  final String? sellerId;
  final String? issueType;
  final String? priority;
  final Map<String, dynamic>? orderIssue;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userPhone,
    required this.category,
    required this.subject,
    required this.description,
    this.attachmentUrls = const [],
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.assignedAdminId,
    this.assignedAdminName,
    this.adminNotes,
    this.assignedAgentId,
    this.assignedAgentName,
    this.assignedAt,
    this.internalNotesCount = 0,
    this.resolutionNote,
    this.messages = const [],
    this.orderId,
    this.sellerId,
    this.issueType,
    this.priority,
    this.orderIssue,
  });

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportTicket(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'],
      userPhone: data['userPhone'],
      category: TicketCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => TicketCategory.other,
      ),
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      status: TicketStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TicketStatus.open,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      assignedAdminId: data['assignedAdminId'],
      assignedAdminName: data['assignedAdminName'],
      adminNotes: data['adminNotes'],
      assignedAgentId: data['assignedAgentId'],
      assignedAgentName: data['assignedAgentName'],
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      internalNotesCount: (data['internalNotesCount'] as num?)?.toInt() ?? 0,
      resolutionNote: data['resolutionNote'],
      messages:
          (data['messages'] as List?)
              ?.map((m) => TicketMessage.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      orderId: data['orderId'],
      sellerId: data['sellerId'],
      issueType: data['issueType'],
      priority: data['priority'],
      orderIssue: data['orderIssue'] != null
          ? Map<String, dynamic>.from(data['orderIssue'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'category': category.name,
      'subject': subject,
      'description': description,
      'attachmentUrls': attachmentUrls,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (assignedAdminId != null) 'assignedAdminId': assignedAdminId,
      if (assignedAdminName != null) 'assignedAdminName': assignedAdminName,
      if (adminNotes != null) 'adminNotes': adminNotes,
      'messages': messages.map((m) => m.toMap()).toList(),
      if (orderId != null) 'orderId': orderId,
      if (sellerId != null) 'sellerId': sellerId,
      if (issueType != null) 'issueType': issueType,
      if (priority != null) 'priority': priority,
      if (orderIssue != null) 'orderIssue': orderIssue,
    };
  }

  String? get assigneeId => assignedAgentId ?? assignedAdminId;

  String? get assigneeName => assignedAgentName ?? assignedAdminName;

  bool get isAssigned => assigneeId != null && assigneeId!.isNotEmpty;

  TicketPriority get priorityLevel => TicketPriority.values.firstWhere(
    (p) => p.name == priority,
    orElse: () => TicketPriority.normal,
  );
}

class TicketMessage {
  final String id;

  final String senderId;
  final String senderName;
  final bool isAdmin;
  final String message;
  final DateTime timestamp;

  final List<MessageAttachment> attachments;

  TicketMessage({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.isAdmin,
    required this.message,
    required this.timestamp,
    this.attachments = const [],
  });

  factory TicketMessage.fromMap(Map<String, dynamic> map) {
    return TicketMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachments: MessageAttachment.listFromData(map['attachments']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'isAdmin': isAdmin,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'attachments': MessageAttachment.listToMaps(attachments),
    };
  }

  bool get hasAttachments => attachments.isNotEmpty;

  String get previewText {
    final text = message.trim();
    if (text.isNotEmpty) return text;
    final label = MessageAttachment.previewLabel(attachments);
    return label.isNotEmpty ? label : 'הודעה חדשה';
  }
}

extension TicketStatusExtension on TicketStatus {
  String get displayName {
    switch (this) {
      case TicketStatus.open:
        return 'פתוחה';
      case TicketStatus.inProgress:
        return 'בטיפול';
      case TicketStatus.resolved:
        return 'נפתרה';
      case TicketStatus.closed:
        return 'סגורה';
    }
  }

  String get colorHex {
    switch (this) {
      case TicketStatus.open:
        return '#FFA726';
      case TicketStatus.inProgress:
        return '#42A5F5';
      case TicketStatus.resolved:
        return '#66BB6A';
      case TicketStatus.closed:
        return '#78909C';
    }
  }
}

extension TicketPriorityExtension on TicketPriority {
  String get displayName {
    switch (this) {
      case TicketPriority.low:
        return 'נמוכה';
      case TicketPriority.normal:
        return 'רגילה';
      case TicketPriority.high:
        return 'גבוהה';
      case TicketPriority.urgent:
        return 'דחופה';
    }
  }

  String get colorHex {
    switch (this) {
      case TicketPriority.low:
        return '#78909C';
      case TicketPriority.normal:
        return '#66BB6A';
      case TicketPriority.high:
        return '#FFA726';
      case TicketPriority.urgent:
        return '#EF5350';
    }
  }
}

extension TicketCategoryExtension on TicketCategory {
  String get displayName {
    switch (this) {
      case TicketCategory.technical:
        return 'בעיה טכנית';
      case TicketCategory.payment:
        return 'בעיית תשלום';
      case TicketCategory.account:
        return 'חשבון משתמש';
      case TicketCategory.product:
        return 'שאלה על מוצר';
      case TicketCategory.other:
        return 'אחר';
    }
  }

  String get icon {
    switch (this) {
      case TicketCategory.technical:
        return '🔧';
      case TicketCategory.payment:
        return '💳';
      case TicketCategory.account:
        return '👤';
      case TicketCategory.product:
        return '🛍️';
      case TicketCategory.other:
        return '💬';
    }
  }
}
