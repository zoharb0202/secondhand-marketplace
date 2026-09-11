'use strict';

const GUEST_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_GUESTS_PER_RUN = 100;
const admin = require('firebase-admin');

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

async function restockOrder(db, admin, orderId, order) {
  const items = Array.isArray(order.items) && order.items.length ?
    order.items.map((i) => String(i.productId)) : [String(order.productId)];
  for (const productId of items) {
    const ref = db.collection('products').doc(productId);
    const snap = await ref.get();
    if (!snap.exists) continue;
    const p = snap.data() || {};
    if (p.soldViaOrderId === orderId) {
      await ref.update({isSold: false, isActive: true, soldViaOrderId: admin.firestore.FieldValue.delete()});
    } else if (Array.isArray(p.stockClaimedOrderIds) && p.stockClaimedOrderIds.includes(orderId)) {
      const qty = Math.max(1, Math.trunc(Number((order.quantityByProductId || {})[productId]) || 1));
      await ref.update({
        stockRemaining: (Number(p.stockRemaining) || 0) + qty,
        isSold: false,
        isActive: true,
        stockClaimedOrderIds: admin.firestore.FieldValue.arrayRemove(orderId),
      });
    }
  }
}

async function purgeGuest(admin, uid) {
  const db = admin.firestore();
  const byField = (collection, field) => db.collection(collection).where(field, '==', uid);

  const guestOrders = await byField('orders', 'buyerId').get();
  for (const o of guestOrders.docs) {
    const order = o.data() || {};
    if (order.status !== 'cancelled') await restockOrder(db, admin, o.id, order);
  }

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

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';
function geohash(lat, lng, precision) {
  let latR = [-90, 90];
  let lngR = [-180, 180];
  let hash = '';
  let bit = 0;
  let ch = 0;
  let even = true;
  while (hash.length < precision) {
    const r = even ? lngR : latR;
    const v = even ? lng : lat;
    const mid = (r[0] + r[1]) / 2;
    if (v >= mid) {
      ch = (ch << 1) | 1;
      r[0] = mid;
    } else {
      ch = ch << 1;
      r[1] = mid;
    }
    even = !even;
    if (++bit === 5) {
      hash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

const BAD_TITLE = /\b(store|shop|shopping|mall|museum|exhibit|exhibition|expo|fair|festival|logo|icon|screenshot|map|diagram|chart|poster|advert|advertisement|sign|signage|woman|man|girl|boy|people|person|crowd|protest|construction|assembling|drawing|painting|illustration|statue|monument|building|street|station|factory|patent|coat of arms|flag|stamp|coin|banknote|album cover|cover art)\b/i;
const tokens = (q) => q.toLowerCase().replace(/[^a-z0-9äöüé ]/g, ' ').split(/\s+/).filter((w) => w.length > 2);
const stripHtml = (h) => String(h || '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim().slice(0, 120);

async function commonsSearch(q) {
  const url = 'https://commons.wikimedia.org/w/api.php?action=query&generator=search' +
    '&gsrsearch=' + encodeURIComponent(q + ' filetype:bitmap') +
    '&gsrnamespace=6&gsrlimit=15&prop=imageinfo&iiprop=url|mime|size|extmetadata&iiurlwidth=800' +
    '&iiextmetadatafilter=Artist|LicenseShortName&format=json';
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(url, {headers: {'User-Agent': 'SecondhandMarketplaceDemo/1.0 (portfolio demo seeding)'}});
      if (!res.ok) throw new Error(String(res.status));
      const json = await res.json();
      return Object.values((json.query || {}).pages || {}).sort((a, b) => a.index - b.index);
    } catch (e) {
      await new Promise((r) => setTimeout(r, 1500 * (attempt + 1)));
    }
  }
  return [];
}

function scorePage(page, q) {
  const ii = page.imageinfo && page.imageinfo[0];
  if (!ii || !/jpeg|png|webp/.test(ii.mime) || Math.min(ii.width, ii.height) < 450) return -1e9;
  const title = page.title.toLowerCase();
  let s = 0;
  for (const w of tokens(q)) if (title.includes(w)) s += 3;
  if (BAD_TITLE.test(page.title)) s -= 6;
  const ar = ii.width / ii.height;
  if (ar > 2.2 || ar < 0.45) s -= 3;
  return s - page.index * 0.1;
}

async function imageCandidates(db, query) {
  const key = require('crypto').createHash('sha1').update(query).digest('hex');
  const ref = db.collection('demo_image_cache').doc(key);
  const cached = await ref.get();
  if (cached.exists) return cached.data().cands || [];
  const words = query.split(/\s+/);
  const variants = [query];
  if (words.length > 2) variants.push(words.slice(1).join(' '), words.slice(-2).join(' '));
  if (words.length > 1) variants.push(words[words.length - 1]);
  let cands = [];
  for (const v of variants) {
    const pages = await commonsSearch(v);
    const good = pages.map((p) => ({p, s: scorePage(p, v)}))
        .filter((x) => x.s > (v === query ? 0 : -1))
        .sort((a, b) => b.s - a.s).slice(0, 4);
    if (good.length) {
      cands = good.map(({p}) => {
        const ii = p.imageinfo[0];
        const m = ii.extmetadata || {};
        return {
          url: ii.thumburl || ii.url,
          title: p.title.replace(/^File:/, ''),
          artist: stripHtml(m.Artist && m.Artist.value),
          license: (m.LicenseShortName || {}).value || '',
          page: ii.descriptionurl || '',
        };
      });
      break;
    }
  }
  await ref.set({query, cands, at: admin.firestore.FieldValue.serverTimestamp()});
  return cands;
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

  const seedDemoCatalog = functions
      .runWith({timeoutSeconds: 540, memory: '1GB'})
      .https.onCall(async (data, context) => {
        if (!context.auth) {
          throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
        }
        const db = admin.firestore();
        const me = await db.collection('users').doc(context.auth.uid).get();
        const isAdmin = context.auth.token.admin === true || (me.exists && (me.data() || {}).role === 'admin');
        if (!isAdmin) {
          throw new functions.https.HttpsError('permission-denied', 'Admins only.');
        }
        const started = Date.now();
        const catalog = require('../seed/demo_catalog.json');
        const now = Date.now();
        const ts = (minutesAgo) => admin.firestore.Timestamp.fromMillis(now - minutesAgo * 60000);

        const productRefs = catalog.products.map((p) => db.collection('products').doc(p.id));
        const existing = new Map();
        for (let i = 0; i < productRefs.length; i += 300) {
          const snaps = await db.getAll(...productRefs.slice(i, i + 300));
          snaps.forEach((snap) => existing.set(snap.id, snap.exists ? snap.data() : null));
        }

        const writes = [];
        for (const u of catalog.sellers) {
          writes.push([db.collection('users').doc(u.id), {...u.data, createdAt: ts(u.minutesAgo)}]);
        }
        for (const p of catalog.products) {
          const prev = existing.get(p.id);
          const created = ts(p.minutesAgo);
          const doc = {
            ...p.data,
            location: new admin.firestore.GeoPoint(p.lat, p.lng),
            geohash: geohash(p.lat, p.lng, 9),
            createdAt: prev && prev.createdAt ? prev.createdAt : created,
            updatedAt: created,
          };
          if (prev && Array.isArray(prev.imageUrls) && prev.imageUrls.length) {
            doc.imageUrls = prev.imageUrls;
            doc.imageCredit = prev.imageCredit || null;
          }
          if (prev) {
            doc.isSold = prev.isSold === true;
            doc.isActive = prev.isActive !== false;
            doc.likeCount = prev.likeCount || 0;
            doc.likedByUserIds = prev.likedByUserIds || [];
          }
          writes.push([db.collection('products').doc(p.id), doc]);
        }
        for (let i = 0; i < writes.length; i += 400) {
          const batch = db.batch();
          for (const [ref, doc] of writes.slice(i, i + 400)) batch.set(ref, doc);
          await batch.commit();
        }

        const pending = catalog.products.filter((p) => {
          const prev = existing.get(p.id);
          return !(prev && Array.isArray(prev.imageUrls) && prev.imageUrls.length);
        });
        let resolved = 0;
        let cursor = 0;
        async function worker() {
          while (cursor < pending.length && Date.now() - started < 470000) {
            const p = pending[cursor++];
            const cands = await imageCandidates(db, p.data.imageQuery);
            if (!cands.length) continue;
            const pick = cands[(p.data.imageRank || 0) % cands.length];
            await db.collection('products').doc(p.id).update({
              imageUrls: [pick.url],
              imageCredit: {artist: pick.artist, license: pick.license, page: pick.page, file: pick.title},
            });
            resolved++;
          }
        }
        await Promise.all(Array.from({length: 6}, worker));
        const remaining = pending.length - resolved;
        return {sellers: catalog.sellers.length, products: catalog.products.length, imagesAdded: resolved, remaining};
      });

  const isDemoSeller = async (db, uid) => {
    if (!uid || !String(uid).startsWith('demo_')) return false;
    const snap = await db.collection('users').doc(String(uid)).get();
    return snap.exists && (snap.data() || {}).isDemo === true;
  };

  const demoSellerAcceptsOrder = functions.firestore
      .document('orders/{orderId}')
      .onCreate(async (snap) => {
        const order = snap.data() || {};
        const db = admin.firestore();
        if (order.status !== 'pending' || order.paymentMethod !== 'pay_on_pickup') return null;
        if (!(await isDemoSeller(db, order.sellerId))) return null;
        await new Promise((r) => setTimeout(r, 4000));
        await snap.ref.update({
          status: 'readyForPickup',
          readyAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          statusHistory: admin.firestore.FieldValue.arrayUnion({
            status: 'readyForPickup',
            timestamp: admin.firestore.Timestamp.now(),
            note: 'מוכר הדמו אישר אוטומטית שהמוצר מוכן לאיסוף',
          }),
        });
        return null;
      });

  const demoSellerAutoReply = functions.firestore
      .document('messages/{messageId}')
      .onCreate(async (snap) => {
        const msg = snap.data() || {};
        const db = admin.firestore();
        const chatRef = db.collection('chats').doc(String(msg.chatId || ''));
        const chatSnap = await chatRef.get();
        if (!chatSnap.exists) return null;
        const chat = chatSnap.data() || {};
        if (msg.senderId === chat.sellerId || chat.demoAutoReplied === true) return null;
        if (!(await isDemoSeller(db, chat.sellerId))) return null;
        const sellerSnap = await db.collection('users').doc(chat.sellerId).get();
        const sellerName = (sellerSnap.data() || {}).displayName || 'מוכר';
        const content = 'היי, תודה על ההודעה! זה מוכר לדוגמה בגרסת הדמו, אז לא תקבלו ממני תשובה אמיתית. ' +
          'אפשר להמשיך ולנסות הזמנה: בדמו המוכר מאשר אותה אוטומטית.';
        const now = admin.firestore.Timestamp.now();
        await db.collection('messages').add({
          chatId: chatRef.id, senderId: chat.sellerId, senderName: sellerName, senderPhotoUrl: null,
          content, type: 'text', imageUrl: null, timestamp: now, isRead: false,
          readBy: [chat.sellerId], attachments: [],
        });
        await chatRef.update({
          lastMessage: content, lastMessageTime: now, lastMessageSenderId: chat.sellerId,
          updatedAt: now, buyerUnreadCount: admin.firestore.FieldValue.increment(1), demoAutoReplied: true,
        });
        return null;
      });

  return {resetDemoGuests, seedDemoCatalog, demoSellerAcceptsOrder, demoSellerAutoReply};
};
