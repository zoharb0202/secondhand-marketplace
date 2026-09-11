import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class LegalDocument {
  final String id;
  final String kind;
  final String version;
  final String title;
  final String body;
  final DateTime? publishedAt;

  const LegalDocument({
    required this.id,
    required this.kind,
    required this.version,
    required this.title,
    required this.body,
    this.publishedAt,
  });

  factory LegalDocument.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return LegalDocument(
      id: doc.id,
      kind: (data['kind'] as String?) ?? '',
      version: (data['version'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ConsentStatus {
  final bool upToDate;

  final String reason;
  final String? currentTermsVersion;
  final String? currentPrivacyVersion;
  final String? acceptedTermsVersion;
  final String? acceptedPrivacyVersion;

  const ConsentStatus({
    required this.upToDate,
    required this.reason,
    this.currentTermsVersion,
    this.currentPrivacyVersion,
    this.acceptedTermsVersion,
    this.acceptedPrivacyVersion,
  });

  bool get isReacceptance =>
      !upToDate &&
      reason != 'never_accepted' &&
      reason != 'no_published_documents';
}

class LegalConsentService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  LegalConsentService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  static const String documentsCollection = 'legal_documents';

  Future<LegalDocument?> currentDocument(String kind) async {
    final snap = await _firestore
        .collection(documentsCollection)
        .where('kind', isEqualTo: kind)
        .where('isCurrent', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return LegalDocument.fromFirestore(snap.docs.first);
  }

  Future<ConsentStatus> status() async {
    final res = await _functions
        .httpsCallable('getLegalConsentStatus')
        .call<dynamic>();
    final data = Map<String, dynamic>.from(res.data as Map);
    final current = Map<String, dynamic>.from(data['current'] as Map? ?? {});
    final accepted = data['accepted'] == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(data['accepted'] as Map);
    return ConsentStatus(
      upToDate: data['upToDate'] == true,
      reason: (data['reason'] as String?) ?? 'unknown',
      currentTermsVersion: current['termsVersion'] as String?,
      currentPrivacyVersion: current['privacyVersion'] as String?,
      acceptedTermsVersion: accepted['termsVersion'] as String?,
      acceptedPrivacyVersion: accepted['privacyVersion'] as String?,
    );
  }

  Future<void> record({String consentContext = 'signup'}) async {
    await _functions.httpsCallable('recordLegalConsent').call<dynamic>({
      'consentContext': consentContext,
      'device': await _describeDevice(),
    });
  }

  Future<Map<String, String>> _describeDevice() async {
    return {
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'osVersion': kIsWeb ? '' : Platform.operatingSystemVersion,
      'model': '',
      'appVersion': '',
    };
  }
}
