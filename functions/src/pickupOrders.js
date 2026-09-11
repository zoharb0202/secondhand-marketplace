'use strict';

const PAY_ON_PICKUP = 'pay_on_pickup';
const UNPAID_ORDER_TTL_MS = 30 * 60 * 1000;
const ORDER_ISSUE_TYPES = ['arrived_broken', 'not_as_described', 'never_arrived', 'wrong_item', 'other'];
const ORDER_RESOLUTIONS = ['refund', 'replacement', 'partial_refund', 'other'];
const STAFF_RESOLUTIONS = ['refund_buyer', 'release_seller', 'dismissed'];

function qtyOf(order, productId) {
  const raw = (order.quantityByProductId || {})[productId];
  return Math.max(1, Math.trunc(Number(raw) || 1));
}

function lineItems(order) {
  if (Array.isArray(order.items) && order.items.length > 0) {
    return order.items.map((i) => ({productId: String(i.productId), price: Number(i.price) || 0}));
  }
  return [{productId: String(order.productId), price: Number(order.productPrice) || 0}];
}

function historyEntry(admin, status, note) {
  return admin.firestore.FieldValue.arrayUnion({
    status,
    timestamp: admin.firestore.Timestamp.now(),
    note,
  });
}

module.exports = function pickupOrders({functions, admin, stripe, notifyUser, assertStaff, webhookSecret}) {
  const db = () => admin.firestore();

  async function allowedUnitPrices(order, item, productSnap) {
    const listPrice = Number((productSnap.data() || {}).price) || 0;
    if (!order.offerId || item.productId !== String(order.productId)) return [listPrice];
    const offerSnap = await db().collection('price_offers').doc(String(order.offerId)).get();
    const offer = offerSnap.exists ? offerSnap.data() || {} : null;
    const valid = offer &&
      offer.buyerId === order.buyerId &&
      String(offer.productId) === item.productId &&
      ['accepted', 'completed'].includes(offer.status);
    return valid ? [listPrice, Number(offer.offeredPrice) || listPrice] : [listPrice];
  }

  async function verifiedOrderAmount(orderId, order, buyerId) {
    if (order.buyerId !== buyerId) throw new Error(`Caller does not own order ${orderId}`);
    if (order.status !== 'pending') throw new Error(`Order ${orderId} is not awaiting payment`);
    if (order.paymentMethod === PAY_ON_PICKUP) throw new Error(`Order ${orderId} is paid on pickup`);
    let expected = 0;
    for (const item of lineItems(order)) {
      const snap = await db().collection('products').doc(item.productId).get();
      if (!snap.exists) throw new Error(`Product ${item.productId} no longer exists`);
      const product = snap.data() || {};
      const claimed = product.soldViaOrderId === orderId ||
        (Array.isArray(product.stockClaimedOrderIds) && product.stockClaimedOrderIds.includes(orderId));
      if (!claimed) throw new Error(`Product ${item.productId} was not reserved for order ${orderId}`);
      const allowed = await allowedUnitPrices(order, item, snap);
      if (!allowed.some((p) => Math.abs(p - item.price) < 0.005)) {
        throw new Error(`Price mismatch on ${item.productId} in order ${orderId}`);
      }
      expected += item.price * qtyOf(order, item.productId);
    }
    if (Math.abs(expected - (Number(order.totalAmount) || 0)) > 0.005) {
      throw new Error(`Total mismatch on order ${orderId}`);
    }
    return Math.round(expected * 100);
  }

  async function restockOrder(orderId, order) {
    const items = lineItems(order);
    await db().runTransaction(async (tx) => {
      const refs = items.map((i) => db().collection('products').doc(i.productId));
      const snaps = await Promise.all(refs.map((r) => tx.get(r)));
      snaps.forEach((snap, idx) => {
        if (!snap.exists) return;
        const p = snap.data() || {};
        if (p.stockTotal == null) {
          if (p.soldViaOrderId !== orderId) return;
          tx.update(snap.ref, {
            isSold: false,
            isActive: true,
            soldViaOrderId: admin.firestore.FieldValue.delete(),
          });
          return;
        }
        const claimed = Array.isArray(p.stockClaimedOrderIds) && p.stockClaimedOrderIds.includes(orderId);
        if (!claimed) return;
        const next = (Number(p.stockRemaining) || 0) + qtyOf(order, items[idx].productId);
        tx.update(snap.ref, {
          stockRemaining: next,
          isSold: false,
          isActive: true,
          stockClaimedOrderIds: admin.firestore.FieldValue.arrayRemove(orderId),
        });
      });
    });
  }

  async function revealPickupDetails(orderId, order) {
    if (order.pickupRevealedAt) return;
    const productSnap = await db().collection('products').doc(String(order.productId)).get();
    const addressId = productSnap.exists ? (productSnap.data() || {}).pickupAddressId : null;
    const update = {pickupRevealedAt: admin.firestore.FieldValue.serverTimestamp()};
    if (addressId) {
      const addressSnap = await db().collection('addresses').doc(String(addressId)).get();
      const address = addressSnap.exists ? addressSnap.data() || {} : null;
      if (address && address.userId === order.sellerId) {
        const extras = [address.floor && `קומה ${address.floor}`, address.apartmentNumber && `דירה ${address.apartmentNumber}`]
            .filter(Boolean).join(', ');
        update.pickupAddress = [address.fullAddress, extras].filter(Boolean).join(' · ');
        if (address.location) update.pickupLocation = address.location;
      }
    }
    const contactSnap = await db().doc(`users/${order.sellerId}/private/contact`).get();
    const phone = contactSnap.exists ? (contactSnap.data() || {}).phoneNumber : null;
    if (phone) update.pickupPhone = phone;
    await db().collection('orders').doc(orderId).update(update);
  }

  async function refundIfCharged(orderId, order) {
    if (!order.stripePaymentIntentId || order.refundId) return null;
    const refund = await stripe.refunds.create({
      payment_intent: order.stripePaymentIntentId,
      amount: Math.round((Number(order.totalAmount) || 0) * 100),
      metadata: {orderId},
    }, {idempotencyKey: `refund_${orderId}`});
    await db().collection('orders').doc(orderId).update({
      refundId: refund.id,
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return refund.id;
  }

  const createPaymentIntent = functions.firestore
      .document('payment_intents/{intentId}')
      .onCreate(async (snap, context) => {
        const intent = snap.data() || {};
        const intentId = context.params.intentId;
        try {
          const orderIds = [...new Set((intent.orderIds || []).map(String).filter(Boolean))];
          if (!intent.userId || orderIds.length === 0) throw new Error('Malformed payment request');

          let amount = 0;
          await db().runTransaction(async (tx) => {
            const refs = orderIds.map((id) => db().collection('orders').doc(id));
            const snaps = await Promise.all(refs.map((r) => tx.get(r)));
            snaps.forEach((s, i) => {
              if (!s.exists) throw new Error(`Order not found: ${orderIds[i]}`);
              const pending = (s.data() || {}).pendingChargeIntentId;
              if (pending && pending !== intentId) throw new Error(`Order ${orderIds[i]} is already being charged`);
            });
            snaps.forEach((s) => tx.update(s.ref, {pendingChargeIntentId: intentId}));
          });
          for (const id of orderIds) {
            const orderSnap = await db().collection('orders').doc(id).get();
            amount += await verifiedOrderAmount(id, orderSnap.data() || {}, intent.userId);
          }

          const paymentIntent = await stripe.paymentIntents.create({
            amount,
            currency: intent.currency || 'ils',
            automatic_payment_methods: {enabled: true},
            metadata: {intentDocId: intentId, orderIds: orderIds.join(','), buyerId: intent.userId},
          }, {idempotencyKey: `pi_${intentId}`});

          await snap.ref.update({
            clientSecret: paymentIntent.client_secret,
            paymentIntentId: paymentIntent.id,
            amount,
            status: 'created',
          });
        } catch (e) {
          console.error('createPaymentIntent failed', intentId, e);
          await snap.ref.update({error: String(e.message || e), status: 'failed'});
          const ids = (intent.orderIds || []).map(String).filter(Boolean);
          await Promise.all(ids.map(async (id) => {
            const ref = db().collection('orders').doc(id);
            const s = await ref.get();
            if (s.exists && (s.data() || {}).pendingChargeIntentId === intentId) {
              await ref.update({pendingChargeIntentId: admin.firestore.FieldValue.delete()});
            }
          }));
        }
        return null;
      });

  const stripeWebhook = functions.https.onRequest(async (req, res) => {
    let event;
    try {
      event = stripe.webhooks.constructEvent(req.rawBody, req.headers['stripe-signature'], webhookSecret);
    } catch (e) {
      console.error('Webhook signature verification failed', e.message);
      res.status(400).send(`Webhook Error: ${e.message}`);
      return;
    }

    const pi = event.data.object;
    const orderIds = String((pi.metadata || {}).orderIds || '').split(',').filter(Boolean);
    const intentDocId = (pi.metadata || {}).intentDocId;

    try {
      if (event.type === 'payment_intent.succeeded') {
        for (const orderId of orderIds) {
          const ref = db().collection('orders').doc(orderId);
          const outcome = await db().runTransaction(async (tx) => {
            const snap = await tx.get(ref);
            if (!snap.exists) return 'missing';
            const order = snap.data() || {};
            if (order.stripePaymentIntentId === pi.id) return 'duplicate';
            if (order.status !== 'pending') {
              tx.update(ref, {stripePaymentIntentId: pi.id, pendingChargeIntentId: admin.firestore.FieldValue.delete()});
              return 'refund';
            }
            tx.update(ref, {
              status: 'paid',
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              stripePaymentIntentId: pi.id,
              paymentId: pi.id,
              pendingChargeIntentId: admin.firestore.FieldValue.delete(),
              statusHistory: historyEntry(admin, 'paid', 'התשלום אושר'),
            });
            return 'paid';
          });
          if (outcome === 'refund') {
            const snap = await ref.get();
            await refundIfCharged(orderId, snap.data() || {});
          }
        }
        if (intentDocId) {
          await db().collection('payment_intents').doc(intentDocId).update({status: 'succeeded'});
        }
      } else if (event.type === 'payment_intent.payment_failed' || event.type === 'payment_intent.canceled') {
        const batch = db().batch();
        for (const orderId of orderIds) {
          batch.update(db().collection('orders').doc(orderId), {
            pendingChargeIntentId: admin.firestore.FieldValue.delete(),
          });
        }
        if (intentDocId) {
          batch.update(db().collection('payment_intents').doc(intentDocId), {status: 'failed'});
        }
        await batch.commit();
      }
      res.json({received: true});
    } catch (e) {
      console.error('Webhook handling failed', event.type, e);
      res.status(500).send('Webhook handler error');
    }
  });

  const onOrderStatusChanged = functions.firestore
      .document('orders/{orderId}')
      .onUpdate(async (change, context) => {
        const before = change.before.data() || {};
        const after = change.after.data() || {};
        if (before.status === after.status) return null;
        const orderId = context.params.orderId;
        const title = after.productTitle || 'המוצר';

        switch (after.status) {
          case 'paid':
            await revealPickupDetails(orderId, after);
            break;
          case 'readyForPickup':
            await revealPickupDetails(orderId, after);
            await notifyUser(after.buyerId, 'order_update', '📦 המוצר מוכן לאיסוף',
                `${title} מחכה לך. כתובת האיסוף מופיעה בדף ההזמנה.`, {orderId});
            break;
          case 'completed': {
            if (before.status === 'disputed') break;
            const inc = admin.firestore.FieldValue.increment;
            await Promise.all([
              db().collection('users').doc(after.sellerId).set({totalSales: inc(1)}, {merge: true}),
              db().collection('users').doc(after.buyerId).set({totalPurchases: inc(1)}, {merge: true}),
              notifyUser(after.sellerId, 'order_update', '✅ ההזמנה הושלמה',
                  `הקונה אישר את איסוף ${title}.`, {orderId}),
            ]);
            break;
          }
          case 'cancelled':
            if (!(before.status === 'disputed' && after.statusBeforeDispute === 'completed')) {
              await restockOrder(orderId, after);
            }
            try {
              await refundIfCharged(orderId, after);
            } catch (e) {
              console.error('Refund failed for cancelled order', orderId, e);
            }
            await Promise.all([after.buyerId, after.sellerId].map((uid) =>
              notifyUser(uid, 'order_update', 'ההזמנה בוטלה', `ההזמנה על ${title} בוטלה.`, {orderId})));
            break;
          default:
            break;
        }
        return null;
      });

  const expirePendingUnpaidOrders = functions.pubsub
      .schedule('every 15 minutes')
      .onRun(async () => {
        const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - UNPAID_ORDER_TTL_MS);
        const snap = await db().collection('orders')
            .where('status', '==', 'pending')
            .where('createdAt', '<', cutoff)
            .limit(200)
            .get();
        let expired = 0;
        for (const doc of snap.docs) {
          const order = doc.data() || {};
          if (order.paymentMethod === PAY_ON_PICKUP) continue;
          if (order.pendingChargeIntentId) {
            const intentSnap = await db().collection('payment_intents').doc(String(order.pendingChargeIntentId)).get();
            const piId = intentSnap.exists ? (intentSnap.data() || {}).paymentIntentId : null;
            if (piId) {
              try {
                await stripe.paymentIntents.cancel(piId);
              } catch (e) {
                console.log(`expirePendingUnpaidOrders: keeping ${doc.id}, intent ${piId} not cancellable`);
                continue;
              }
            }
          }
          await doc.ref.update({
            status: 'cancelled',
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            statusHistory: historyEntry(admin, 'cancelled', 'התשלום לא הושלם בזמן'),
          });
          expired++;
        }
        console.log(`expirePendingUnpaidOrders: ${expired} expired`);
        return null;
      });

  const reportOrderProblem = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    const uid = context.auth.uid;
    const orderId = data && data.orderId;
    if (typeof orderId !== 'string' || !orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'orderId is required.');
    }
    const orderRef = db().collection('orders').doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) throw new functions.https.HttpsError('not-found', 'Order not found.');
    const order = orderSnap.data() || {};
    if (order.buyerId !== uid && context.auth.token.admin !== true) {
      throw new functions.https.HttpsError('permission-denied', 'Only the buyer can report a problem.');
    }
    if (order.status === 'cancelled' || order.status === 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'אין מה לברר עבור הזמנה זו.');
    }
    if (order.disputeTicketId && order.disputeStatus === 'open') {
      return {success: true, ticketId: order.disputeTicketId, alreadyOpen: true,
        message: 'כבר קיימת פנייה פתוחה עבור הזמנה זו.'};
    }

    const issueType = data.issueType;
    const preferredResolution = data.preferredResolution;
    const description = typeof data.description === 'string' ? data.description.trim() : '';
    if (!ORDER_ISSUE_TYPES.includes(issueType)) {
      throw new functions.https.HttpsError('invalid-argument', 'issueType is invalid.');
    }
    if (!ORDER_RESOLUTIONS.includes(preferredResolution)) {
      throw new functions.https.HttpsError('invalid-argument', 'preferredResolution is invalid.');
    }
    if (description.length < 10 || description.length > 1000) {
      throw new functions.https.HttpsError('invalid-argument', 'התיאור חייב להכיל בין 10 ל-1000 תווים.');
    }

    const userSnap = await db().collection('users').doc(uid).get();
    const user = userSnap.exists ? userSnap.data() || {} : {};
    const userName = user.displayName || 'משתמש';
    const ticketRef = db().collection('support_tickets').doc();

    await ticketRef.set({
      userId: uid,
      userName,
      userEmail: user.email || null,
      userPhone: typeof data.contactPhone === 'string' ? data.contactPhone.slice(0, 32) : null,
      category: 'product',
      subject: `בעיה בהזמנה: ${order.productTitle || orderId}`,
      description,
      attachmentUrls: [],
      status: 'open',
      priority: 'high',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: null,
      resolvedAt: null,
      assignedAdminId: null,
      assignedAdminName: null,
      adminNotes: null,
      messages: [{
        senderId: uid,
        senderName: userName,
        isAdmin: false,
        message: description,
        timestamp: admin.firestore.Timestamp.now(),
      }],
      orderId,
      sellerId: order.sellerId || null,
      issueType,
      orderIssue: {
        issueType,
        description,
        itemInPossession: data.itemInPossession === true,
        preferredResolution,
        productTitle: order.productTitle || null,
        totalAmount: order.totalAmount != null ? order.totalAmount : null,
      },
    });

    await orderRef.update({
      status: 'disputed',
      disputeStatus: 'open',
      disputeTicketId: ticketRef.id,
      disputeOpenedAt: admin.firestore.FieldValue.serverTimestamp(),
      disputeIssueType: issueType,
      statusBeforeDispute: order.status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      statusHistory: historyEntry(admin, 'disputed', 'הקונה דיווח על בעיה בהזמנה'),
    });

    await Promise.all([
      notifyUser(order.sellerId, 'order_update', '⚠️ הקונה דיווח על בעיה בהזמנה',
          'שירות הלקוחות בודק את הפנייה.', {orderId, ticketId: ticketRef.id}),
      notifyUser(uid, 'order_update', '📩 הפנייה נקלטה',
          'נציג שירות יחזור אליך. אפשר להוסיף פרטים בצ׳אט הפנייה.', {orderId, ticketId: ticketRef.id}),
    ]);

    return {success: true, ticketId: ticketRef.id, alreadyOpen: false,
      message: 'הפנייה נפתחה. נציג שירות יחזור אליך.'};
  });

  const resolveOrderDispute = functions.https.onCall(async (data, context) => {
    await assertStaff(context);
    const orderId = data && data.orderId;
    const resolution = data && data.resolution;
    const note = typeof (data && data.note) === 'string' ? data.note.slice(0, 1000) : null;
    if (typeof orderId !== 'string' || !orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'orderId is required.');
    }
    if (!STAFF_RESOLUTIONS.includes(resolution)) {
      throw new functions.https.HttpsError('invalid-argument', 'resolution is invalid.');
    }
    const orderRef = db().collection('orders').doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) throw new functions.https.HttpsError('not-found', 'Order not found.');
    const order = orderSnap.data() || {};
    if (order.disputeStatus !== 'open') {
      throw new functions.https.HttpsError('failed-precondition', 'אין פנייה פתוחה עבור הזמנה זו.');
    }

    let nextStatus;
    let message;
    if (resolution === 'refund_buyer') {
      nextStatus = 'cancelled';
      message = 'הפנייה נסגרה — ההזמנה בוטלה והתשלום יוחזר.';
    } else if (resolution === 'release_seller') {
      nextStatus = 'completed';
      message = 'הפנייה נסגרה — ההזמנה סומנה כהושלמה.';
    } else {
      nextStatus = order.statusBeforeDispute || 'readyForPickup';
      message = 'הפנייה נסגרה ללא שינוי בהזמנה.';
    }

    await orderRef.update({
      status: nextStatus,
      ...(nextStatus === 'cancelled' ? {cancelledAt: admin.firestore.FieldValue.serverTimestamp()} : {}),
      ...(nextStatus === 'completed' ? {completedAt: admin.firestore.FieldValue.serverTimestamp()} : {}),
      disputeStatus: 'resolved',
      disputeResolution: resolution,
      disputeResolvedBy: context.auth.uid,
      disputeResolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      statusHistory: historyEntry(admin, nextStatus, note || message),
    });

    if (order.disputeTicketId) {
      await db().collection('support_tickets').doc(order.disputeTicketId).update({
        status: 'resolved',
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        adminNotes: note,
        messages: admin.firestore.FieldValue.arrayUnion({
          senderId: context.auth.uid,
          senderName: 'שירות לקוחות',
          isAdmin: true,
          message,
          timestamp: admin.firestore.Timestamp.now(),
        }),
      }).catch((e) => console.error('resolveOrderDispute: ticket update failed', e));
    }

    await Promise.all([order.buyerId, order.sellerId].map((uid) =>
      notifyUser(uid, 'order_update', 'עדכון בפנייה לשירות הלקוחות', message, {orderId})));

    return {success: true, status: 'resolved', message};
  });

  return {
    createPaymentIntent,
    stripeWebhook,
    onOrderStatusChanged,
    expirePendingUnpaidOrders,
    reportOrderProblem,
    resolveOrderDispute,
  };
};

module.exports.PAY_ON_PICKUP = PAY_ON_PICKUP;
module.exports.lineItems = lineItems;
module.exports.qtyOf = qtyOf;
