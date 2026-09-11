const admin = require('firebase-admin');
const functions = require('firebase-functions');

const TICKETS = 'support_tickets';
const INTERNAL_NOTES = 'internal_notes';
const AUDIT_LOG = 'audit_log';

const TICKET_STATUSES = ['open', 'inProgress', 'resolved', 'closed'];
const TICKET_PRIORITIES = ['low', 'normal', 'high', 'urgent'];

const ASSIGNABLE_ROLES = ['supportAgent', 'admin'];

const NOTIFY_ASSIGNED = 'ticket_assigned';
const NOTIFY_INTERNAL_NOTE = 'ticket_internal_note';

const MAX_NOTE_LENGTH = 2000;
const MAX_RESOLUTION_LENGTH = 1000;
const AUDIT_PREVIEW_LENGTH = 140;
const MAX_AGENTS_RETURNED = 200;

async function resolveActor(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'נדרשת התחברות.');
  }
  const uid = context.auth.uid;
  const hasAdminClaim = !!(context.auth.token && context.auth.token.admin === true);

  let role = null;
  let name = null;
  try {
    const snap = await admin.firestore().collection('users').doc(uid).get();
    if (snap.exists) {
      const user = snap.data() || {};
      role = user.role || null;
      name = user.displayName || user.name || user.email || null;
    }
  } catch (e) {
    console.error('⚠️ supportOps.resolveActor role lookup failed:', e);
  }

  const isAdmin = hasAdminClaim || role === 'admin';
  const isAgent = role === 'supportAgent';
  if (!isAdmin && !isAgent) {
    throw new functions.https.HttpsError('permission-denied', 'לפעולה זו נדרשות הרשאות צוות.');
  }

  return {
    uid,
    isAdmin,
    name: name || (isAdmin ? 'מנהל' : 'נציג שירות'),
    role: isAdmin ? 'admin' : 'supportAgent',
  };
}

function currentAssignee(ticket) {
  return (ticket && (ticket.assignedAgentId || ticket.assignedAdminId)) || null;
}

function assertCanOperate(actor, ticket) {
  if (actor.isAdmin) return;
  const assignee = currentAssignee(ticket);
  if (!assignee || assignee === actor.uid) return;
  throw new functions.https.HttpsError(
      'permission-denied', 'הפנייה משויכת לנציג אחר — רק מנהל יכול לשנות אותה.');
}

function auditEntry(actor, action, details) {
  return {
    action,
    actorId: actor.uid,
    actorName: actor.name,
    actorRole: actor.role,
    details: details || {},
    at: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function notifyStaff(userId, type, title, body, data) {
  if (!userId) return;
  const db = admin.firestore();
  try {
    await db.collection('notifications').add({
      userId,
      type,
      title,
      body,
      data: data || {},
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('fcm_queue').add({
      userId,
      notification: {title, body},
      data: Object.assign({type}, data || {}),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
    });
  } catch (e) {
    console.error('⚠️ supportOps.notifyStaff failed:', e);
  }
}

function requireTicketId(data) {
  const ticketId = data && data.ticketId;
  if (!ticketId || typeof ticketId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'ticketId is required.');
  }
  return ticketId;
}

function cleanText(raw, max) {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, max);
}

const listSupportAgents = functions.https.onCall(async (data, context) => {
  const actor = await resolveActor(context);
  if (!actor.isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'רק מנהל יכול לשייך פניות.');
  }

  const db = admin.firestore();
  const results = await Promise.all(ASSIGNABLE_ROLES.map((role) =>
    db.collection('users').where('role', '==', role).limit(MAX_AGENTS_RETURNED).get(),
  ));

  const agents = [];
  for (const snap of results) {
    for (const doc of snap.docs) {
      const user = doc.data() || {};
      if (user.isActive === false) continue;
      agents.push({
        id: doc.id,
        name: user.displayName || user.name || user.email || 'נציג שירות',
        role: user.role,
      });
    }
  }
  agents.sort((a, b) => a.name.localeCompare(b.name, 'he'));

  return {agents};
});

const assignSupportTicket = functions.https.onCall(async (data, context) => {
  const actor = await resolveActor(context);
  const ticketId = requireTicketId(data);
  const agentId = cleanText(data && data.agentId, 128);

  if (!actor.isAdmin) {
    if (!agentId) {
      throw new functions.https.HttpsError(
          'permission-denied', 'רק מנהל יכול לבטל שיוך של פנייה.');
    }
    if (agentId !== actor.uid) {
      throw new functions.https.HttpsError(
          'permission-denied', 'רק מנהל יכול לשייך פנייה לנציג אחר.');
    }
  }

  const db = admin.firestore();
  const ticketRef = db.collection(TICKETS).doc(ticketId);

  let agent = null;
  if (agentId) {
    const userSnap = await db.collection('users').doc(agentId).get();
    if (!userSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'המשתמש לא נמצא.');
    }
    const user = userSnap.data() || {};
    if (!ASSIGNABLE_ROLES.includes(user.role)) {
      throw new functions.https.HttpsError(
          'failed-precondition', 'ניתן לשייך פנייה רק לנציג שירות או למנהל.');
    }
    agent = {
      id: agentId,
      name: user.displayName || user.name || user.email || 'נציג שירות',
    };
  }

  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ticketRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'הפנייה לא נמצאה.');
    }
    const ticket = snap.data() || {};
    const previous = currentAssignee(ticket);

    if (!actor.isAdmin && previous && previous !== actor.uid) {
      throw new functions.https.HttpsError(
          'permission-denied', 'הפנייה כבר משויכת לנציג אחר.');
    }
    if (previous === agentId) {
      return {changed: false, previous, subject: ticket.subject || ''};
    }

    const update = {updatedAt: admin.firestore.FieldValue.serverTimestamp()};
    if (agentId) {
      update.assignedAgentId = agentId;
      update.assignedAgentName = agent.name;
      update.assignedAt = admin.firestore.FieldValue.serverTimestamp();
      update.assignedBy = actor.uid;
      update.assignedAdminId = agentId;
      update.assignedAdminName = agent.name;
      if ((ticket.status || 'open') === 'open') {
        update.status = 'inProgress';
      }
    } else {
      update.assignedAgentId = null;
      update.assignedAgentName = null;
      update.assignedAt = null;
      update.assignedBy = actor.uid;
      update.assignedAdminId = null;
      update.assignedAdminName = null;
    }

    tx.update(ticketRef, update);
    tx.create(ticketRef.collection(AUDIT_LOG).doc(),
        auditEntry(actor, agentId ? 'assigned' : 'unassigned', {
          fromAgentId: previous || null,
          toAgentId: agentId || null,
          toAgentName: agent ? agent.name : null,
        }));

    return {changed: true, previous, subject: ticket.subject || ''};
  });

  if (outcome.changed && agentId && agentId !== actor.uid) {
    await notifyStaff(agentId, NOTIFY_ASSIGNED,
        'פנייה חדשה שויכה אליך',
        outcome.subject ? `${actor.name} שייך/ה אליך את הפנייה: ${outcome.subject}` :
          `${actor.name} שייך/ה אליך פנייה חדשה`,
        {ticketId});
  }

  console.log(`🎧 [SUPPORT] ticket ${ticketId} assignment → ${agentId || 'none'} by ${actor.uid}`);
  return {
    success: true,
    changed: outcome.changed,
    assignedAgentId: agentId,
    assignedAgentName: agent ? agent.name : null,
  };
});

const updateSupportTicketStatus = functions.https.onCall(async (data, context) => {
  const actor = await resolveActor(context);
  const ticketId = requireTicketId(data);
  const status = data && data.status;
  const note = cleanText(data && data.note, MAX_RESOLUTION_LENGTH);

  if (!TICKET_STATUSES.includes(status)) {
    throw new functions.https.HttpsError('invalid-argument', 'status is invalid.');
  }
  if (status === 'closed' && !note) {
    throw new functions.https.HttpsError(
        'invalid-argument', 'סגירת פנייה מחייבת סיכום טיפול.');
  }

  const db = admin.firestore();
  const ticketRef = db.collection(TICKETS).doc(ticketId);

  const previousStatus = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ticketRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'הפנייה לא נמצאה.');
    }
    const ticket = snap.data() || {};
    assertCanOperate(actor, ticket);

    const before = ticket.status || 'open';
    const update = {
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (status === 'resolved') {
      update.resolvedAt = admin.firestore.FieldValue.serverTimestamp();
    }
    if (status === 'closed') {
      update.closedAt = admin.firestore.FieldValue.serverTimestamp();
    }
    if (note) {
      update.resolutionNote = note;
      update.adminNotes = note;
    }

    tx.update(ticketRef, update);
    tx.create(ticketRef.collection(AUDIT_LOG).doc(),
        auditEntry(actor, 'status_changed', {
          from: before,
          to: status,
          note: note || null,
        }));
    return before;
  });

  console.log(`🎧 [SUPPORT] ticket ${ticketId} status ${previousStatus} → ${status} by ${actor.uid}`);
  return {success: true, status, message: 'הסטטוס עודכן'};
});

const setSupportTicketPriority = functions.https.onCall(async (data, context) => {
  const actor = await resolveActor(context);
  const ticketId = requireTicketId(data);
  const priority = data && data.priority;

  if (!TICKET_PRIORITIES.includes(priority)) {
    throw new functions.https.HttpsError('invalid-argument', 'priority is invalid.');
  }

  const db = admin.firestore();
  const ticketRef = db.collection(TICKETS).doc(ticketId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ticketRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'הפנייה לא נמצאה.');
    }
    const ticket = snap.data() || {};
    assertCanOperate(actor, ticket);

    tx.update(ticketRef, {
      priority,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.create(ticketRef.collection(AUDIT_LOG).doc(),
        auditEntry(actor, 'priority_changed', {
          from: ticket.priority || 'normal',
          to: priority,
        }));
  });

  console.log(`🎧 [SUPPORT] ticket ${ticketId} priority → ${priority} by ${actor.uid}`);
  return {success: true, priority, message: 'העדיפות עודכנה'};
});

const addSupportInternalNote = functions.https.onCall(async (data, context) => {
  const actor = await resolveActor(context);
  const ticketId = requireTicketId(data);
  const text = cleanText(data && data.text, MAX_NOTE_LENGTH);
  if (!text) {
    throw new functions.https.HttpsError('invalid-argument', 'לא ניתן לשלוח הודעה ריקה.');
  }

  const db = admin.firestore();
  const ticketRef = db.collection(TICKETS).doc(ticketId);
  const noteRef = ticketRef.collection(INTERNAL_NOTES).doc();

  const assignee = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ticketRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'הפנייה לא נמצאה.');
    }
    const ticket = snap.data() || {};
    assertCanOperate(actor, ticket);

    tx.create(noteRef, {
      authorId: actor.uid,
      authorName: actor.name,
      authorRole: actor.role,
      text,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(ticketRef, {
      internalNotesCount: admin.firestore.FieldValue.increment(1),
      lastInternalNoteAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.create(ticketRef.collection(AUDIT_LOG).doc(),
        auditEntry(actor, 'internal_note', {
          preview: text.slice(0, AUDIT_PREVIEW_LENGTH),
        }));

    return currentAssignee(ticket);
  });

  if (assignee && assignee !== actor.uid) {
    await notifyStaff(assignee, NOTIFY_INTERNAL_NOTE,
        'הודעה פנימית בפנייה',
        `${actor.name}: ${text.slice(0, 80)}`,
        {ticketId});
  }

  return {success: true, noteId: noteRef.id};
});

module.exports = {
  listSupportAgents,
  assignSupportTicket,
  updateSupportTicketStatus,
  setSupportTicketPriority,
  addSupportInternalNote,
  TICKET_STATUSES,
  TICKET_PRIORITIES,
  INTERNAL_NOTES,
  AUDIT_LOG,
  NOTIFY_ASSIGNED,
  NOTIFY_INTERNAL_NOTE,
};
