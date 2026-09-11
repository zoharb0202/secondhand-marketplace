'use strict';

const GUEST_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_GUESTS_PER_RUN = 100;

async function deleteQuery(db, query) {
  let removed = 0;
  for (;;) {
    const snap = await query.limit(300).get();
    if (snap.empty) return removed;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    removed += snap.size;
    if (snap.size < 300) return removed;
  }
}

async function purgeGuest(admin, uid) {
  const db = admin.firestore();
  const byField = (collection, field) => db.collection(collection).where(field, '==', uid);

  const chats = await Promise.all([
    byField('chats', 'buyerId').get(),
    byField('chats', 'sellerId').get(),
  ]);
  for (const snap of chats) {
    for (const chat of snap.docs) {
      await deleteQuery(db, db.collection('messages').where('chatId', '==', chat.id));
      await db.recursiveDelete(chat.ref);
    }
  }

  const collections = [
    ['products', 'sellerId'], ['orders', 'buyerId'], ['orders', 'sellerId'],
    ['price_offers', 'buyerId'], ['price_offers', 'sellerId'], ['notifications', 'userId'],
    ['addresses', 'userId'], ['saved_searches', 'userId'], ['alerts', 'userId'],
    ['alert_matches', 'userId'], ['stories', 'sellerId'], ['user_interactions', 'userId'],
    ['support_tickets', 'userId'], ['seller_reviews', 'buyerId'], ['payment_intents', 'userId'],
  ];
  for (const [collection, field] of collections) {
    await deleteQuery(db, byField(collection, field));
  }

  await Promise.all([
    db.recursiveDelete(db.collection('carts').doc(uid)),
    db.collection('notification_preferences').doc(uid).delete(),
    db.collection('user_activities').doc(uid).delete(),
    db.recursiveDelete(db.collection('users').doc(uid)),
  ]);
  try {
    await admin.storage().bucket().deleteFiles({prefix: `product_images/${uid}/`});
  } catch (_) {}
  await admin.auth().deleteUser(uid);
}

module.exports = function demoReset({functions, admin}) {
  const resetDemoGuests = functions
      .runWith({timeoutSeconds: 540, memory: '512MB'})
      .pubsub.schedule('every day 04:00')
      .timeZone('Asia/Jerusalem')
      .onRun(async () => {
        const cutoff = Date.now() - GUEST_TTL_MS;
        const stale = [];
        let pageToken;
        do {
          const page = await admin.auth().listUsers(1000, pageToken);
          for (const user of page.users) {
            const isGuest = user.providerData.length === 0;
            const created = Date.parse(user.metadata.creationTime);
            if (isGuest && created < cutoff) stale.push(user.uid);
          }
          pageToken = page.pageToken;
        } while (pageToken && stale.length < MAX_GUESTS_PER_RUN);

        let purged = 0;
        for (const uid of stale.slice(0, MAX_GUESTS_PER_RUN)) {
          try {
            await purgeGuest(admin, uid);
            purged++;
          } catch (e) {
            console.error('resetDemoGuests: failed for', uid, e);
          }
        }
        console.log(`resetDemoGuests: purged ${purged} guest account(s)`);
        return null;
      });

  return {resetDemoGuests};
};
