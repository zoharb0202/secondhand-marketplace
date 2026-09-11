const functions = require('firebase-functions');
const admin = require('firebase-admin');

const CONSENT_COLLECTION = 'consent_records';
const DOCUMENTS_COLLECTION = 'legal_documents';

const LEGAL_KINDS = ['terms', 'privacy'];

const CONSENT_CONTEXTS = [
  'signup',
  'reacceptance',
];

async function currentVersions(db) {
  const out = {};
  for (const kind of LEGAL_KINDS) {
    const snap = await db.collection(DOCUMENTS_COLLECTION)
        .where('kind', '==', kind)
        .where('isCurrent', '==', true)
        .limit(1)
        .get();
    out[kind] = snap.empty ? null : {id: snap.docs[0].id, ...snap.docs[0].data()};
  }
  return out;
}

function clientIpFrom(rawRequest) {
  if (!rawRequest) return null;
  const forwarded = rawRequest.headers && rawRequest.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    const first = forwarded.split(',')[0].trim();
    if (first) return first.slice(0, 64);
  }
  if (Array.isArray(forwarded) && forwarded.length > 0) {
    return String(forwarded[0]).trim().slice(0, 64);
  }
  return rawRequest.ip ? String(rawRequest.ip).slice(0, 64) : null;
}

async function consentStatus(db, uid) {
  const current = await currentVersions(db);
  const snap = await db.collection(CONSENT_COLLECTION)
      .where('userId', '==', uid)
      .orderBy('acceptedAt', 'desc')
      .limit(1)
      .get();

  const accepted = snap.empty ? null : snap.docs[0].data();

  const anyPublished = LEGAL_KINDS.some((k) => current[k] != null);
  if (!anyPublished) {
    return {upToDate: true, current, accepted, reason: 'no_published_documents'};
  }

  if (!accepted) {
    return {upToDate: false, current, accepted: null, reason: 'never_accepted'};
  }

  for (const kind of LEGAL_KINDS) {
    const doc = current[kind];
    if (!doc) continue;
    if (accepted[`${kind}Version`] !== doc.version) {
      return {upToDate: false, current, accepted, reason: `${kind}_outdated`};
    }
  }
  return {upToDate: true, current, accepted, reason: 'current'};
}

async function recordConsent(db, {uid, consentContext, device, rawRequest}) {
  const current = await currentVersions(db);

  if (!LEGAL_KINDS.some((k) => current[k] != null)) {
    throw new functions.https.HttpsError('failed-precondition',
        'טרם פורסמו מסמכים משפטיים לאישור.');
  }

  const record = {
    userId: uid,
    consentContext,
    acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    ip: clientIpFrom(rawRequest),
    userAgent: rawRequest && rawRequest.headers ?
      String(rawRequest.headers['user-agent'] || '').slice(0, 512) : null,
    selfReportedDevice: device || null,
  };

  for (const kind of LEGAL_KINDS) {
    const doc = current[kind];
    record[`${kind}Version`] = doc ? doc.version : null;
    record[`${kind}DocumentId`] = doc ? doc.id : null;
    record[`${kind}ContentHash`] = doc ? (doc.contentHash || null) : null;
  }

  const ref = await db.collection(CONSENT_COLLECTION).add(record);

  await db.collection('users').doc(uid).set({
    termsAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    termsVersion: record.termsVersion,
    privacyVersion: record.privacyVersion,
    lastConsentRecordId: ref.id,
  }, {merge: true});

  return {
    recordId: ref.id,
    termsVersion: record.termsVersion,
    privacyVersion: record.privacyVersion,
  };
}

module.exports = {
  CONSENT_COLLECTION,
  DOCUMENTS_COLLECTION,
  LEGAL_KINDS,
  CONSENT_CONTEXTS,
  currentVersions,
  clientIpFrom,
  consentStatus,
  recordConsent,
};
