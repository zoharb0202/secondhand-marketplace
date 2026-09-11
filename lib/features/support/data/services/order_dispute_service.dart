import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class OrderDisputeResult {
  final bool success;
  final String? ticketId;
  final String? status;
  final bool alreadyOpen;
  final String? message;

  OrderDisputeResult({
    required this.success,
    this.ticketId,
    this.status,
    this.alreadyOpen = false,
    this.message,
  });
}

class OrderDisputeService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<OrderDisputeResult> reportOrderProblem({
    required String orderId,
    required String issueType,
    required String description,
    bool? itemInPossession,
    required String preferredResolution,
    String? contactPhone,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '⚠️ [DISPUTE] Reporting a problem for order: $orderId ($issueType)',
        );
      }

      final callable = _functions.httpsCallable('reportOrderProblem');
      final response = await callable.call<Map<String, dynamic>>({
        'orderId': orderId,
        'issueType': issueType,
        'description': description,
        if (itemInPossession != null) 'itemInPossession': itemInPossession,
        'preferredResolution': preferredResolution,
        if (contactPhone != null && contactPhone.trim().isNotEmpty)
          'contactPhone': contactPhone.trim(),
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final result = OrderDisputeResult(
        success: data['success'] == true,
        ticketId: data['ticketId'] as String?,
        alreadyOpen: data['alreadyOpen'] == true,
        message: data['message'] as String?,
      );

      if (kDebugMode) {
        print(
          '✅ [DISPUTE] reportOrderProblem result: ticket=${result.ticketId} alreadyOpen=${result.alreadyOpen}',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('❌ [DISPUTE] Error reporting problem: ${e.code} ${e.message}');
      }
      return OrderDisputeResult(
        success: false,
        message: e.message ?? 'שגיאה בפתיחת הפנייה, נסה שוב',
      );
    } catch (e) {
      if (kDebugMode) print('❌ [DISPUTE] Error reporting problem: $e');
      return OrderDisputeResult(
        success: false,
        message: 'שגיאה בפתיחת הפנייה, נסה שוב',
      );
    }
  }

  Future<OrderDisputeResult> resolveOrderDispute({
    required String orderId,
    required String resolution,
    String? note,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🧑‍⚖️ [DISPUTE] Resolving dispute for order: $orderId -> $resolution',
        );
      }

      final callable = _functions.httpsCallable('resolveOrderDispute');
      final response = await callable.call<Map<String, dynamic>>({
        'orderId': orderId,
        'resolution': resolution,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final result = OrderDisputeResult(
        success: data['success'] == true,
        status: data['status'] as String?,
        message: data['message'] as String?,
      );

      if (kDebugMode) {
        print('✅ [DISPUTE] resolveOrderDispute result: ${result.status}');
      }
      return result;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('❌ [DISPUTE] Error resolving dispute: ${e.code} ${e.message}');
      }
      return OrderDisputeResult(
        success: false,
        message: e.message ?? 'שגיאה בפתרון הפנייה',
      );
    } catch (e) {
      if (kDebugMode) print('❌ [DISPUTE] Error resolving dispute: $e');
      return OrderDisputeResult(success: false, message: 'שגיאה בפתרון הפנייה');
    }
  }
}
