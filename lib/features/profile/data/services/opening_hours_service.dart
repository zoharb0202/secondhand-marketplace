import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../shared/models/availability_window.dart';

class OpeningHoursService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  OpeningHoursService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const int _kMirrorPageSize = 300;

  static List<AvailabilityWindow> parse(Object? raw) =>
      AvailabilityWindow.parseList(raw);

  Future<List<AvailabilityWindow>> loadFor(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return parse(snap.data()?['availabilityWindows']);
  }

  Future<void> saveMine(List<AvailabilityWindow> windows) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    await _firestore.collection('users').doc(uid).update({
      'availabilityWindows': windows.map((w) => w.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await mirrorToMyProducts(uid, windows);
    } catch (e) {
      throw SellerHoursMirrorException(e);
    }
  }

  Future<void> mirrorToMyProducts(
    String uid,
    List<AvailabilityWindow> windows,
  ) async {
    final mirrored = windows.map((w) => w.toMap()).toList();

    final base = _firestore
        .collection('products')
        .where('sellerId', isEqualTo: uid)
        .orderBy(FieldPath.documentId)
        .limit(_kMirrorPageSize);

    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      final page =
          await (cursor == null ? base : base.startAfterDocument(cursor)).get();
      if (page.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in page.docs) {
        batch.update(doc.reference, {kProductSellerHoursField: mirrored});
      }
      await batch.commit();

      if (page.docs.length < _kMirrorPageSize) return;
      cursor = page.docs.last;
    }
  }
}

class SellerHoursMirrorException implements Exception {
  final Object cause;
  const SellerHoursMirrorException(this.cause);

  @override
  String toString() => 'SellerHoursMirrorException: $cause';
}

String hebrewDayName(int storedDayOfWeek) {
  switch (storedDayOfWeek) {
    case 1:
      return 'ראשון';
    case 2:
      return 'שני';
    case 3:
      return 'שלישי';
    case 4:
      return 'רביעי';
    case 5:
      return 'חמישי';
    case 6:
      return 'שישי';
    case 7:
      return 'שבת';
    default:
      return '';
  }
}

const List<int> kWeekDayNumbers = [1, 2, 3, 4, 5, 6, 7];
