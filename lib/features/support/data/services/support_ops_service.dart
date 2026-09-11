import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../models/support_ticket_model.dart';
import '../../models/ticket_internal_models.dart';

class SupportOpsResult {
  final bool success;
  final String? message;

  SupportOpsResult({required this.success, this.message});
}

class SupportAgentOption {
  final String id;
  final String name;
  final String role;

  SupportAgentOption({
    required this.id,
    required this.name,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
}

class SupportOpsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _ticketsCollection = 'support_tickets';
  static const String _internalNotes = 'internal_notes';
  static const String _auditLog = 'audit_log';

  Stream<List<TicketInternalNote>> internalNotesStream(String ticketId) {
    return _firestore
        .collection(_ticketsCollection)
        .doc(ticketId)
        .collection(_internalNotes)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs.map(TicketInternalNote.fromFirestore).toList(),
        );
  }

  Stream<List<TicketAuditEntry>> auditTrailStream(String ticketId) {
    return _firestore
        .collection(_ticketsCollection)
        .doc(ticketId)
        .collection(_auditLog)
        .orderBy('at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TicketAuditEntry.fromFirestore).toList());
  }

  Future<List<SupportAgentOption>> listSupportAgents() async {
    try {
      final callable = _functions.httpsCallable('listSupportAgents');
      final response = await callable.call<Map<String, dynamic>>();
      final data = Map<String, dynamic>.from(response.data as Map);
      final agents = (data['agents'] as List?) ?? const [];
      return agents
          .map((a) => Map<String, dynamic>.from(a as Map))
          .map(
            (a) => SupportAgentOption(
              id: a['id'] as String,
              name: (a['name'] as String?) ?? 'נציג שירות',
              role: (a['role'] as String?) ?? 'supportAgent',
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) print('❌ [SUPPORT] listSupportAgents failed: $e');
      return const [];
    }
  }

  Future<SupportOpsResult> assignTicket({
    required String ticketId,
    String? agentId,
  }) {
    return _call('assignSupportTicket', {
      'ticketId': ticketId,
      if (agentId != null) 'agentId': agentId,
    }, fallbackError: 'שגיאה בשיוך הפנייה');
  }

  Future<SupportOpsResult> updateStatus({
    required String ticketId,
    required TicketStatus status,
    String? note,
  }) {
    return _call('updateSupportTicketStatus', {
      'ticketId': ticketId,
      'status': status.name,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }, fallbackError: 'שגיאה בעדכון הסטטוס');
  }

  Future<SupportOpsResult> setPriority({
    required String ticketId,
    required TicketPriority priority,
  }) {
    return _call('setSupportTicketPriority', {
      'ticketId': ticketId,
      'priority': priority.name,
    }, fallbackError: 'שגיאה בעדכון העדיפות');
  }

  Future<SupportOpsResult> addInternalNote({
    required String ticketId,
    required String text,
  }) {
    return _call('addSupportInternalNote', {
      'ticketId': ticketId,
      'text': text.trim(),
    }, fallbackError: 'שגיאה בשליחת ההודעה הפנימית');
  }

  Future<void> claimIfUnassigned({
    required String ticketId,
    required String agentId,
  }) async {
    final result = await assignTicket(ticketId: ticketId, agentId: agentId);
    if (!result.success) {
      if (kDebugMode) {
        print(
          'ℹ️ [SUPPORT] self-claim skipped for $ticketId: ${result.message}',
        );
      }
    }
  }

  Future<SupportOpsResult> _call(
    String name,
    Map<String, dynamic> payload, {
    required String fallbackError,
  }) async {
    try {
      final callable = _functions.httpsCallable(name);
      final response = await callable.call<Map<String, dynamic>>(payload);
      final data = Map<String, dynamic>.from(response.data as Map);
      return SupportOpsResult(
        success: data['success'] == true,
        message: data['message'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) print('❌ [SUPPORT] $name failed: ${e.code} ${e.message}');
      return SupportOpsResult(
        success: false,
        message: e.message ?? fallbackError,
      );
    } catch (e) {
      if (kDebugMode) print('❌ [SUPPORT] $name failed: $e');
      return SupportOpsResult(success: false, message: fallbackError);
    }
  }
}
