const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');

async function raiseOpsAlert({type, entityId, message, severity = 'CRITICAL', context = {}}) {
  try {
    logger.write({
      severity,
      message: `[OPS_ALERT] ${type}: ${message}`,
      opsAlertType: type,
      opsAlertEntityId: entityId || null,
      ...context,
    });

    const docId = entityId ? `${type}__${entityId}` : `${type}__${Date.now()}`;
    await admin.firestore().collection('ops_alerts').doc(docId).set({
      type,
      severity,
      message,
      entityId: entityId || null,
      resolved: false,
      occurrences: admin.firestore.FieldValue.increment(1),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      context,
    }, {merge: true});
  } catch (e) {
    console.error('⚠️ raiseOpsAlert itself failed:', e);
  }
}

module.exports = {raiseOpsAlert};
