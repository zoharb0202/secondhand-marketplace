import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_model.dart';

class AlertService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AlertModel> createAlert(String query) async {
    try {
      final callable = _functions.httpsCallable('createSmartAlert');
      final result = await callable.call({'query': query});

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true) {
        throw Exception('Failed to create alert');
      }

      final alertId = data['alertId'] as String;

      final doc = await _firestore.collection('alerts').doc(alertId).get();

      if (!doc.exists) {
        throw Exception('Alert created but not found');
      }

      return AlertModel.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error creating alert: $e');
      }
      throw Exception('Failed to create alert: $e');
    }
  }

  Stream<List<AlertModel>> getUserAlertsStream(String userId) {
    return _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AlertModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<List<AlertMatch>> getAlertMatches({
    required String alertId,
    int? minScore,
    int? limit,
  }) async {
    try {
      final callable = _functions.httpsCallable('getAlertMatches');
      final result = await callable.call({
        'alertId': alertId,
        if (minScore != null) 'minScore': minScore,
        if (limit != null) 'limit': limit,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true) {
        throw Exception('Failed to get matches');
      }

      final matchesData = data['matches'] as List<dynamic>;
      return matchesData
          .map((m) => AlertMatch.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting alert matches: $e');
      }
      throw Exception('Failed to get matches: $e');
    }
  }

  Stream<List<AlertMatch>> getAlertMatchesStream({
    required String alertId,
    required String userId,
    int? minScore,
  }) {
    var query = _firestore
        .collection('alert_matches')
        .where('alertId', isEqualTo: alertId)
        .where('userId', isEqualTo: userId)
        .orderBy('matchScore', descending: true);

    if (minScore != null) {
      query = query.where('matchScore', isGreaterThanOrEqualTo: minScore);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AlertMatch.fromFirestore(doc)).toList();
    });
  }

  Stream<List<AlertMatch>> getUnreadMatchesStream(String userId) {
    return _firestore
        .collection('alert_matches')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AlertMatch.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> updateAlertStatus({
    required String alertId,
    required String action,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateAlertStatus');
      final result = await callable.call({
        'alertId': alertId,
        'action': action,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true) {
        throw Exception('Failed to update alert');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating alert status: $e');
      }
      throw Exception('Failed to update alert: $e');
    }
  }

  Future<void> markMatchAsRead(String matchId) async {
    try {
      await _firestore.collection('alert_matches').doc(matchId).update({
        'isRead': true,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error marking match as read: $e');
      }
    }
  }

  Future<void> markAllMatchesAsRead(String alertId, String userId) async {
    try {
      final matches = await _firestore
          .collection('alert_matches')
          .where('alertId', isEqualTo: alertId)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in matches.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error marking all matches as read: $e');
      }
    }
  }

  Future<void> deleteAlert(String alertId) async {
    await updateAlertStatus(alertId: alertId, action: 'delete');
  }

  Future<void> activateAlert(String alertId) async {
    await updateAlertStatus(alertId: alertId, action: 'activate');
  }

  Future<void> deactivateAlert(String alertId) async {
    await updateAlertStatus(alertId: alertId, action: 'deactivate');
  }

  Stream<int> getUnreadMatchesCountStream(String userId) {
    return _firestore
        .collection('alert_matches')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
