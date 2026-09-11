try {
  require('dotenv').config({path: require('path').join(__dirname, '.env')});
} catch (_) {  }

const functions = require('firebase-functions');
const admin = require('firebase-admin');

let _legacyStripeCfg;
try { _legacyStripeCfg = functions.config().stripe; } catch (_) { _legacyStripeCfg = undefined; }
const stripeSecretKey = process.env.STRIPE_SECRET_KEY || _legacyStripeCfg?.secret_key;
const stripeConfigured = !!stripeSecretKey && !/^sk_test_(dummy|your_key_here)$/.test(stripeSecretKey);
if (!stripeConfigured) {
  console.warn('Stripe is not configured: card payments are disabled, pay-on-pickup still works.');
}
const stripe = require('stripe')(stripeSecretKey || 'sk_test_dummy');
const aiSearch = require('./src/aiSearch');
const sampleProducts = require('./src/addSampleProducts');
const tasteProfile = require('./src/tasteProfile');
const retailPrice = require('./src/retailPrice');
const brandCatalog = require('./src/brandCatalog');
const signals = require('./src/signals');
const {raiseOpsAlert} = require('./src/opsAlerts');

const aiTelemetry = require('./src/aiTelemetry');
const chatAttachments = require('./src/chatAttachments');
const reviews = require('./src/reviews');
const supportOps = require('./src/supportOps');
const legalConsent = require('./src/legalConsent');
const expectedPrice = require('./src/expectedPrice');
const imageVariants = require('./src/imageVariants');
const trendingScore = require('./src/trendingScore');

admin.initializeApp();

function deviceDoc(uid) {
  return admin.firestore()
      .collection('users').doc(uid)
      .collection('private').doc('device');
}

async function fetchFcmToken(uid) {
  if (!uid) return null;
  try {
    const snap = await deviceDoc(uid).get();
    return snap.exists ? (snap.data().fcmToken || null) : null;
  } catch (e) {
    console.error('⚠️ fetchFcmToken failed:', e);
    return null;
  }
}

const TYPE_TO_CHANNEL = {
  new_order: 'orders',
  order_update: 'orders',
  new_message: 'messages',
  price_offer: 'orders',
  review: 'orders',
  promo: 'marketing',
  alert_match: 'alerts',
  saved_search_match: 'alerts',
  followed_seller_new_product: 'alerts',
  price_drop: 'alerts',
};

const CHANNEL_PRIORITY = {
  orders: 'high',
  messages: 'high',
  marketing: 'normal',
  alerts: 'high',
};

const TYPE_TO_PREF = {
  new_order: 'notifyOrderStatus',
  order_update: 'notifyOrderStatus',
  new_message: 'notifyChatMessages',
  price_offer: 'notifyOfferReceived',
  review: 'notifyNewReviews',
  promo: 'notifyPromotions',
  alert_match: 'notifyNewProducts',
  saved_search_match: 'notifyNewProducts',
  followed_seller_new_product: 'notifyNewProducts',
  price_drop: 'notifyPriceReductions',
};

const KNOWN_NOTIFICATION_TYPES = new Set(Object.keys(TYPE_TO_CHANNEL));

async function evaluateNotificationPreferences(userId, type) {
  const result = { send: true, silent: false };
  if (!userId) return result;

  try {
    const prefSnap = await admin.firestore()
        .collection('notification_preferences')
        .doc(userId)
        .get();
    if (!prefSnap.exists) return result;

    const prefs = prefSnap.data() || {};

    if (prefs.enableNotifications === false) {
      result.send = false;
      return result;
    }

    const prefKey = TYPE_TO_PREF[type];
    if (prefKey && prefs[prefKey] === false) {
      result.send = false;
      return result;
    }

    const qs = prefs.quietHoursStart;
    const qe = prefs.quietHoursEnd;
    if (qs != null && qe != null) {
      const hourStr = new Intl.DateTimeFormat('en-US', {
        hour: 'numeric', hour12: false, timeZone: 'Asia/Jerusalem',
      }).format(new Date());
      const hour = parseInt(hourStr, 10) % 24;
      const inQuiet = qs > qe
        ? (hour >= qs || hour < qe)
        : (hour >= qs && hour < qe);
      if (inQuiet) {
        result.silent = true;
      }
    }
  } catch (e) {
    console.error('⚠️ Could not evaluate notification preferences:', e);
  }
  return result;
}

async function getUnreadBadgeCount(userId) {
  if (!userId) return 0;
  try {
    const snap = await admin.firestore()
        .collection('notifications')
        .where('userId', '==', userId)
        .where('isRead', '==', false)
        .count()
        .get();
    return snap.data().count || 0;
  } catch (e) {
    console.error('⚠️ Could not count unread notifications:', e);
    return 0;
  }
}

exports.sendFCMNotification = functions.firestore
    .document('fcm_queue/{queueId}')
    .onCreate(async (snap, context) => {
      const data = snap.data();

      if (data.processed) {
        console.log('⚠️ Notification already processed, skipping');
        return null;
      }

      console.log('📤 Processing FCM notification for user:', data.userId);

      const targetToken = data.token || await fetchFcmToken(data.userId);
      if (!targetToken) {
        console.error('❌ No FCM token for user', data.userId);
        await snap.ref.update({
          processed: true,
          error: 'Missing FCM token',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return null;
      }

      if (!data.notification || !data.notification.title || !data.notification.body) {
        console.error('❌ Missing notification title or body');
        await snap.ref.update({
          processed: true,
          error: 'Missing notification title or body',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return null;
      }

      const payloadData = data.data || {};
      const type = payloadData.type || data.type || 'order_update';
      const channelId = TYPE_TO_CHANNEL[type] || 'orders';
      const androidPriority = CHANNEL_PRIORITY[channelId] === 'normal' ? 'default' : 'high';

      const pref = await evaluateNotificationPreferences(data.userId, type);
      if (!pref.send) {
        console.log(`🔕 Notification suppressed by user preferences (type=${type})`);
        await snap.ref.update({
          processed: true,
          suppressed: true,
          suppressedReason: 'user_preferences',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return null;
      }

      const silent = pref.silent === true;

      const chatCollapseId = type === 'new_message' && payloadData.chatId ?
          `chat_${payloadData.chatId}` : null;
      const tag = payloadData.tag || chatCollapseId ||
          payloadData.orderId || type;

      const imageUrl = data.imageUrl || payloadData.imageUrl || null;

      const badge = await getUnreadBadgeCount(data.userId);

      const outData = { type };
      for (const [k, v] of Object.entries(payloadData)) {
        if (v == null) continue;
        outData[k] = typeof v === 'string' ? v : String(v);
      }

      const androidNotification = {
        channelId,
        priority: silent ? 'default' : androidPriority,
        tag: String(tag),
      };
      if (!silent) androidNotification.sound = 'default';
      if (imageUrl) androidNotification.imageUrl = imageUrl;

      const apnsAps = {
        badge,
        'thread-id': String(tag),
      };
      if (!silent) apnsAps.sound = 'default';

      const apns = {
        headers: {
          'apns-collapse-id': String(tag).substring(0, 63),
        },
        payload: { aps: apnsAps },
      };
      if (imageUrl) {
        apns.fcm_options = { image: imageUrl };
      }

      const message = {
        data: outData,
        token: targetToken,
        android: {
          priority: silent ? 'normal' : 'high',
          collapseKey: String(tag).substring(0, 63),
        },
        apns,
      };
      message.notification = {
        title: data.notification.title,
        body: data.notification.body,
      };
      message.android.notification = androidNotification;

      try {
        const response = await admin.messaging().send(message);
        console.log('✅ Successfully sent FCM notification:', response);

        await snap.ref.update({
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          messageId: response,
        });

        return response;
      } catch (error) {
        console.error('❌ Error sending FCM notification:', error);

        await snap.ref.update({
          processed: true,
          error: error.message,
          errorCode: error.code,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          console.log('🗑️ Removing invalid FCM token from user');
          try {
            await deviceDoc(data.userId).set({
              fcmToken: admin.firestore.FieldValue.delete(),
            }, {merge: true});
          } catch (updateError) {
            console.error('❌ Error removing invalid token:', updateError);
          }
        }

        return null;
      }
    });

exports.cleanupFCMQueue = functions.pubsub
    .schedule('0 0 * * *')
    .timeZone('Asia/Jerusalem')
    .onRun(async (context) => {
      console.log('🧹 Starting FCM queue cleanup');

      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - 7);

      const snapshot = await admin.firestore()
          .collection('fcm_queue')
          .where('processedAt', '<', cutoffDate)
          .limit(400)
          .get();

      const toDelete = snapshot.docs.filter((doc) => doc.data().processed === true);
      console.log(`Found ${toDelete.length} old processed notifications to delete (of ${snapshot.size} scanned)`);

      if (toDelete.length > 0) {
        const batch = admin.firestore().batch();
        toDelete.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
      }
      if (snapshot.size === 400) {
        console.log('[FCM_QUEUE] page saturated (400) — remainder will be picked up on the next run');
      }
      console.log('✅ FCM queue cleanup completed');

      return null;
    });

const PUBLIC_USER_PII_KEYS = ['email', 'phoneNumber', 'address', 'location'];

exports.stripPublicUserPii = functions.firestore
    .document('users/{userId}')
    .onWrite(async (change, context) => {
      const after = change.after.exists ? (change.after.data() || {}) : null;
      if (!after) return null;

      const present = PUBLIC_USER_PII_KEYS.filter(
          (k) => after[k] !== undefined && after[k] !== null);
      const hasStrayToken = after.fcmToken !== undefined && after.fcmToken !== null;
      if (present.length === 0 && !hasStrayToken) return null;

      const userId = context.params.userId;
      const db = admin.firestore();
      try {
        if (present.length > 0) {
          const contact = {updatedAt: admin.firestore.FieldValue.serverTimestamp()};
          for (const k of present) contact[k] = after[k];
          await db.doc(`users/${userId}/private/contact`).set(contact, {merge: true});
        }
        if (hasStrayToken) {
          await db.doc(`users/${userId}/private/device`)
              .set({fcmToken: after.fcmToken}, {merge: true});
        }

        const strip = {};
        for (const k of present) strip[k] = admin.firestore.FieldValue.delete();
        if (hasStrayToken) strip.fcmToken = admin.firestore.FieldValue.delete();
        await change.after.ref.update(strip);

        console.log('🔒 relocated public-doc PII', {userId, keys: present, fcmToken: hasStrayToken});
      } catch (e) {
        console.error('⚠️ stripPublicUserPii failed:', userId, e);
      }
      return null;
    });

async function notifyUser(userId, type, title, body, extraData, options) {
  if (!userId) return;
  if (!KNOWN_NOTIFICATION_TYPES.has(type)) {
    console.error('⚠️ notifyUser: unknown notification type', type,
        '— add it to TYPE_TO_CHANNEL/TYPE_TO_PREF and to lib/core/constants/notification_types.dart');
  }
  const db = admin.firestore();
  try {
    if (!options || options.skipInApp !== true) {
      await db.collection('notifications').add({
        userId,
        type,
        title,
        body,
        data: extraData || {},
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const token = await fetchFcmToken(userId);
    if (!token) return;
    await db.collection('fcm_queue').add({
      token,
      notification: {title, body},
      data: Object.assign({type}, extraData || {}),
      userId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
    });
  } catch (e) {
    console.error('⚠️ notifyUser failed:', e);
  }
}

async function assertStaff(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  if (context.auth.token.admin === true) return;
  try {
    const snap = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const role = snap.exists ? (snap.data() || {}).role : null;
    if (role === 'admin' || role === 'supportAgent') return;
  } catch (e) {
    console.error('⚠️ assertStaff role lookup failed:', e);
  }
  throw new functions.https.HttpsError('permission-denied', 'לפעולה זו נדרשות הרשאות צוות.');
}

const KNOWN_CATEGORIES = new Set([
  'vehicles', 'realestate', 'electronics', 'fashion', 'homegarden', 'sports',
  'babykids', 'animalssupplies', 'officesupplies', 'services', 'jobs', 'other',
]);
const SAVED_SEARCH_COOLDOWN_MS = 6 * 60 * 60 * 1000;

exports.onProductCreatedNotifySavedSearches = functions.firestore
    .document('products/{productId}')
    .onCreate(async (snap, context) => {
      const product = snap.data();
      if (!product) return null;
      if (product.isActive === false || product.isSold === true) return null;

      const productId = context.params.productId;
      const db = admin.firestore();
      const title = (product.title || '').toString();
      const haystack =
          `${title} ${(product.description || '')}`.toLowerCase();
      const category = (product.category || '').toString().toLowerCase();
      const price = Number(product.price) || 0;
      const sellerId = product.sellerId;

      const searchesSnap = await db.collection('saved_searches')
          .where('notifyOnNew', '==', true)
          .get();
      if (searchesSnap.empty) return null;

      let matched = 0;
      for (const doc of searchesSnap.docs) {
        try {
          const s = doc.data();
          const uid = s.userId;
          if (!uid || uid === sellerId) continue;

          const query = (s.query || '').toString().toLowerCase().trim();
          if (!query) continue;
          const tokens = query.split(/\s+/).filter(Boolean);
          if (!tokens.every((t) => haystack.includes(t))) continue;

          if (s.maxPrice != null) {
            const mp = Number(s.maxPrice);
            if (!isNaN(mp) && price > mp) continue;
          }

          if (s.category) {
            const sc = s.category.toString().toLowerCase();
            if (KNOWN_CATEGORIES.has(sc) && sc !== category) continue;
          }

          const lastNotified = s.lastNotified;
          if (lastNotified && typeof lastNotified.toMillis === 'function') {
            if (Date.now() - lastNotified.toMillis() < SAVED_SEARCH_COOLDOWN_MS) {
              continue;
            }
          }

          await notifyUser(uid, 'saved_search_match',
              '🔎 מוצר חדש שמתאים לחיפוש שלך',
              `"${title}" תואם לחיפוש "${s.query}"`,
              {productId, savedSearchId: doc.id});
          await doc.ref.update({
            lastNotified: admin.firestore.FieldValue.serverTimestamp(),
          });
          matched++;
        } catch (e) {
          console.error('⚠️ saved-search match failed for', doc.id, e);
        }
      }
      console.log(
          `[SAVED_SEARCH] product ${productId} alerted ${matched} search(es)`);
      return null;
    });

exports.notifyFollowersOnNewProduct = functions.firestore
    .document('products/{productId}')
    .onCreate(async (snap, context) => {
      const product = snap.data();
      if (!product) return null;
      if (product.isActive === false || product.isSold === true) return null;

      const sellerId = product.sellerId;
      if (!sellerId) return null;
      const productId = context.params.productId;
      const db = admin.firestore();

      let sellerName = 'מוכר שאתה עוקב אחריו';
      try {
        const sellerDoc = await db.collection('users').doc(sellerId).get();
        const sd = sellerDoc.data();
        if (sd) sellerName = sd.displayName || sd.name || sellerName;
      } catch (e) {
        console.error('⚠️ follow-alert seller lookup failed:', e);
      }

      const followersSnap = await db.collection('users')
          .where('followingSellerIds', 'array-contains', sellerId)
          .get();
      if (followersSnap.empty) return null;

      const title = (product.title || '').toString();
      let count = 0;
      for (const doc of followersSnap.docs) {
        const uid = doc.id;
        if (uid === sellerId) continue;
        try {
          await notifyUser(uid, 'followed_seller_new_product',
              `🆕 ${sellerName} העלה מוצר חדש`,
              title,
              {productId, sellerId});
          count++;
        } catch (e) {
          console.error('⚠️ follower notify failed for', uid, e);
        }
      }
      console.log(`[FOLLOW] product ${productId} notified ${count} follower(s)`);
      return null;
    });

const PRICE_DROP_MIN_PCT = 0.05;
const PRICE_DROP_COOLDOWN_MS = 12 * 60 * 60 * 1000;

exports.notifyFavoritesOnPriceDrop = functions.firestore
    .document('products/{productId}')
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();
      if (!before || !after) return null;

      const oldPrice = Number(before.price);
      const newPrice = Number(after.price);
      if (isNaN(oldPrice) || isNaN(newPrice) || oldPrice <= 0) return null;
      if (newPrice >= oldPrice) return null;
      if (after.isActive === false || after.isSold === true) return null;
      if ((oldPrice - newPrice) / oldPrice < PRICE_DROP_MIN_PCT) return null;

      const last = after.lastPriceDropNotified;
      if (last && typeof last.toMillis === 'function') {
        if (Date.now() - last.toMillis() < PRICE_DROP_COOLDOWN_MS) return null;
      }

      const likers =
          Array.isArray(after.likedByUserIds) ? after.likedByUserIds : [];
      if (likers.length === 0) return null;

      const productId = context.params.productId;
      const title = (after.title || '').toString();
      let count = 0;
      for (const uid of likers) {
        if (!uid || uid === after.sellerId) continue;
        try {
          await notifyUser(uid, 'price_drop',
              '💸 ירידת מחיר על מוצר ששמרת',
              `"${title}" עכשיו ₪${Math.round(newPrice)} (היה ₪${Math.round(oldPrice)})`,
              {productId});
          count++;
        } catch (e) {
          console.error('⚠️ price-drop notify failed for', uid, e);
        }
      }

      try {
        await change.after.ref.update({
          lastPriceDropNotified: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (e) {
        console.error('⚠️ price-drop cooldown stamp failed:', e);
      }

      console.log(
          `[PRICE_DROP] product ${productId} alerted ${count} favoriter(s)`);
      return null;
    });

exports.cleanupExpiredStories = functions.pubsub
    .schedule('every 1 hours')
    .timeZone('Asia/Jerusalem')
    .onRun(async () => {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      const snap = await db.collection('stories')
          .where('expiresAt', '<', now)
          .limit(400)
          .get();
      if (snap.empty) return null;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      console.log(`[STORIES] pruned ${snap.size} expired story doc(s)`);
      return null;
    });

exports.cleanupExpiredCaches = functions.pubsub
    .schedule('30 3 * * *')
    .timeZone('Asia/Jerusalem')
    .onRun(async () => {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      let removed = 0;
      for (const coll of ['ai_cache', 'rate_limits']) {
        const snap = await db.collection(coll)
            .where('expiresAt', '<', now)
            .limit(1000)
            .get();
        if (snap.empty) continue;
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        removed += snap.size;
      }
      console.log(`[CACHE] pruned ${removed} expired cache/rate-limit doc(s)`);
      return null;
    });

const localDateKey = trendingScore.localDateKey;

const DAILY_STATS_PAGE = 400;
const DAILY_STATS_MAX = 20000;

exports.rollupDailyProductStats = functions.pubsub
    .schedule('5 0 * * *')
    .timeZone('Asia/Jerusalem')
    .onRun(async () => {
      const db = admin.firestore();
      const dateKey = localDateKey(new Date(), 0);
      console.log(`📊 [ROLLUP] Aggregating daily product stats for ${dateKey}`);

      let processed = 0;
      let written = 0;
      let lastDoc = null;

      while (processed < DAILY_STATS_MAX) {
        let q = db.collection('products')
            .orderBy(admin.firestore.FieldPath.documentId())
            .limit(DAILY_STATS_PAGE);
        if (lastDoc) q = q.startAfter(lastDoc);

        const snap = await q.get();
        if (snap.empty) break;

        const active = snap.docs.filter((d) => {
          const p = d.data() || {};
          return p.isActive === true && p.isSold !== true;
        });

        if (active.length > 0) {
          const statsRefs = active.map(
              (d) => db.collection('product_daily_stats').doc(d.id));
          const statsSnaps = await db.getAll(...statsRefs);
          const batch = db.batch();

          active.forEach((pDoc, i) => {
            const p = pDoc.data() || {};
            const views = Number(p.viewCount) || 0;
            const likes = Number(p.likeCount) || 0;
            const st = statsSnaps[i].exists ? (statsSnaps[i].data() || {}) : {};
            const lastViews = Number(st.lastViewCount) || 0;
            const lastLikes = Number(st.lastLikeCount) || 0;

            const dViews = Math.max(views - lastViews, 0);
            const dLikes = Math.max(likes - lastLikes, 0);

            batch.set(statsRefs[i], {
              productId: pDoc.id,
              sellerId: p.sellerId || null,
              title: p.title || '',
              lastViewCount: views,
              lastLikeCount: likes,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              days: {[dateKey]: {views: dViews, likes: dLikes}},
            }, {merge: true});
          });

          await batch.commit();
          written += active.length;
        }

        processed += snap.docs.length;
        lastDoc = snap.docs[snap.docs.length - 1];
        if (snap.docs.length < DAILY_STATS_PAGE) break;
      }

      console.log(`✅ [ROLLUP] ${dateKey}: scanned ${processed} product(s), recorded deltas for ${written}`);
      return null;
    });

const TRENDING_TOP_N = 100;

exports.computeTrendingScores = functions
    .runWith({timeoutSeconds: 540, memory: '512MB'})
    .pubsub
    .schedule('every 4 hours')
    .timeZone('Asia/Jerusalem')
    .onRun(async () => {
      const db = admin.firestore();
      console.log('🔥 [TRENDING] Recomputing trend scores');

      const now = Date.now();

      try {
        const rolled = await trendingScore.runRollupInteractionSignals(db, {nowMs: now});
        console.log(`📥 [TRENDING] Rolled ${rolled.scanned} interaction(s) into ` +
          `${rolled.productsTouched} product(s) / ${rolled.sellersTouched} seller(s)`);
      } catch (e) {
        console.error('❌ [TRENDING] Interaction rollup failed; scoring on existing signal:', e);
      }

      const sellers = trendingScore.makeSellerCache(db, {nowMs: now});
      const scored = [];
      let processed = 0;
      let lastDoc = null;

      while (processed < DAILY_STATS_MAX) {
        let q = db.collection('products')
            .orderBy(admin.firestore.FieldPath.documentId())
            .limit(DAILY_STATS_PAGE);
        if (lastDoc) q = q.startAfter(lastDoc);

        const snap = await q.get();
        if (snap.empty) break;

        const live = snap.docs.filter((d) => {
          const p = d.data() || {};
          return p.isActive === true && p.isSold !== true;
        });

        if (live.length > 0) {
          const statsRefs = live.map(
              (d) => db.collection('product_daily_stats').doc(d.id));
          const [statsSnaps] = await Promise.all([
            db.getAll(...statsRefs),
            sellers.load(live.map((d) => (d.data() || {}).sellerId)),
          ]);
          const batch = db.batch();

          live.forEach((pDoc, i) => {
            const p = pDoc.data() || {};
            const st = statsSnaps[i].exists ? (statsSnaps[i].data() || {}) : {};
            const sellerInfo = sellers.get(p.sellerId);

            const {score} = trendingScore.trendScoreFor({
              product: p,
              dailyStats: st,
              seller: sellerInfo.seller,
              recentSellerSales: sellerInfo.recentSales,
              nowMs: now,
            });

            batch.update(pDoc.ref, {trendScore: score});
            scored.push({id: pDoc.id, score});
          });

          await batch.commit();
        }

        processed += snap.docs.length;
        lastDoc = snap.docs[snap.docs.length - 1];
        if (snap.docs.length < DAILY_STATS_PAGE) break;
      }

      scored.sort((a, b) => b.score - a.score);
      const top = scored.slice(0, TRENDING_TOP_N);
      const scores = {};
      for (const s of top) scores[s.id] = s.score;

      await db.collection('trending').doc('global').set({
        scores,
        topProductIds: top.map((s) => s.id),
        count: scored.length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ [TRENDING] Scored ${processed} product(s); top ${top.length} written to trending/global`);
      return null;
    });

exports.updateTasteProfiles = functions.pubsub
    .schedule('every 6 hours')
    .timeZone('Asia/Jerusalem')
    .onRun(async () => {
      const db = admin.firestore();
      try {
        const result = await tasteProfile.runUpdateTasteProfiles(db);
        console.log(`✅ [TASTE] Updated ${result.usersUpdated} profile(s) from ${result.scanned} interaction(s)`);
      } catch (e) {
        console.error('❌ [TASTE] Error updating taste profiles:', e);
      }
      return null;
    });

exports.aiProductSearch = aiSearch.aiProductSearch;
exports.analyzeProductImage = aiSearch.analyzeProductImage;
exports.enhanceDescription = aiSearch.enhanceDescription;
exports.moderateImage = aiSearch.moderateImage;
exports.chatbot = aiSearch.chatbot;
exports.getPersonalizedRecommendations = aiSearch.getPersonalizedRecommendations;
exports.analyzePhotoQuality = aiSearch.analyzePhotoQuality;

exports.suggestBrand = brandCatalog.suggestBrand;
exports.brandSuggestionAiCheck = brandCatalog.brandSuggestionAiCheck;
exports.reviewBrandSuggestion = brandCatalog.reviewBrandSuggestion;

exports.createSmartAlert = aiSearch.createSmartAlert;
exports.matchProductToAlerts = aiSearch.matchProductToAlerts;
exports.getAlertMatches = aiSearch.getAlertMatches;
exports.getUserAlerts = aiSearch.getUserAlerts;
exports.updateAlertStatus = aiSearch.updateAlertStatus;

exports.addSampleProducts = sampleProducts.addSampleProducts;

exports.onProductImageResized = imageVariants.onProductImageResized;

exports.rollupAiUsage = aiTelemetry.rollupAiUsage;
exports.recomputeAiUsage = aiTelemetry.recomputeAiUsage;

exports.onProductWriteRetailBargain = retailPrice.onProductWriteRetailBargain;
exports.onRetailEstimateWriteRestampProducts = retailPrice.onRetailEstimateWriteRestampProducts;
exports.backfillRetailEstimates = retailPrice.backfillRetailEstimates;

exports.recordSaleSignal = signals.recordSaleSignal;
exports.logSearchClick = signals.logSearchClick;
exports.logListingOutcome = signals.logListingOutcome;
exports.rollupSignals = signals.rollupSignals;

exports.cleanupChatAttachmentsOnMessageDelete =
    chatAttachments.cleanupChatAttachmentsOnMessageDelete;
exports.cleanupChatAttachmentsOnChatDelete =
    chatAttachments.cleanupChatAttachmentsOnChatDelete;
exports.cleanupTicketAttachmentsOnTicketDelete =
    chatAttachments.cleanupTicketAttachmentsOnTicketDelete;

exports.submitSellerReview = reviews.submitSellerReview;
exports.replyToSellerReview = reviews.replyToSellerReview;
exports.markSellerReviewHelpful = reviews.markSellerReviewHelpful;
exports.flagSellerReview = reviews.flagSellerReview;
exports.aggregateSellerRating = reviews.aggregateSellerRating;

exports.listSupportAgents = supportOps.listSupportAgents;
exports.assignSupportTicket = supportOps.assignSupportTicket;
exports.updateSupportTicketStatus = supportOps.updateSupportTicketStatus;
exports.setSupportTicketPriority = supportOps.setSupportTicketPriority;
exports.addSupportInternalNote = supportOps.addSupportInternalNote;

const PRICE_OFFER_ACCEPTANCE_WINDOW_MS = 24 * 60 * 60 * 1000;

exports.getExpectedPrice = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const db = admin.firestore();

  let source = data && data.product ? data.product : null;
  if (!source && data && typeof data.productId === 'string') {
    const snap = await db.collection('products').doc(data.productId).get();
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'המוצר לא נמצא.');
    }
    source = snap.data() || {};
  }
  if (!source) {
    throw new functions.https.HttpsError(
        'invalid-argument', 'productId or product is required.');
  }

  const parts = signals._signals.priceKeyPartsFor(source);
  if (!parts) {
    return {known: false, reason: 'not_identifiable'};
  }

  const keyHash = signals.retailEstimateKey(parts);
  const condition = (data && typeof data.condition === 'string') ?
    data.condition : (source.condition || null);

  const result = await expectedPrice.expectedPriceFor(db, keyHash, condition);
  if (!result) {
    return {known: false, reason: 'no_comparable_sales', keyHash};
  }
  return {known: true, ...result};
});

exports.recordLegalConsent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const consentContext = (data && data.consentContext) || 'signup';
  if (!legalConsent.CONSENT_CONTEXTS.includes(consentContext)) {
    throw new functions.https.HttpsError('invalid-argument', 'consentContext is invalid.');
  }

  const rawDevice = (data && data.device) || null;
  const device = rawDevice && typeof rawDevice === 'object' ? {
    platform: String(rawDevice.platform || '').slice(0, 64),
    osVersion: String(rawDevice.osVersion || '').slice(0, 64),
    model: String(rawDevice.model || '').slice(0, 128),
    appVersion: String(rawDevice.appVersion || '').slice(0, 32),
  } : null;

  const db = admin.firestore();
  const result = await legalConsent.recordConsent(db, {
    uid: context.auth.uid,
    consentContext,
    device,
    rawRequest: context.rawRequest,
  });

  console.log(`✅ consent recorded for ${context.auth.uid} (${consentContext})`);
  return {success: true, ...result};
});

exports.getLegalConsentStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const db = admin.firestore();
  const status = await legalConsent.consentStatus(db, context.auth.uid);
  return {
    upToDate: status.upToDate,
    reason: status.reason,
    current: {
      termsVersion: status.current.terms ? status.current.terms.version : null,
      privacyVersion: status.current.privacy ? status.current.privacy.version : null,
    },
    accepted: status.accepted ? {
      termsVersion: status.accepted.termsVersion || null,
      privacyVersion: status.accepted.privacyVersion || null,
    } : null,
  };
});

exports.expireOfferReservations = functions.pubsub
    .schedule('every 15 minutes')
    .timeZone('Asia/Jerusalem')
    .onRun(async () => {
      const db = admin.firestore();
      const nowMs = Date.now();

      const snap = await db.collection('products')
          .where('isReserved', '==', true)
          .limit(500)
          .get();
      if (snap.empty) return null;

      let cleared = 0;
      for (const doc of snap.docs) {
        const p = doc.data() || {};
        const until = p.reservedUntil;
        const untilMs = until && typeof until.toMillis === 'function'
          ? until.toMillis() : 0;
        if (untilMs > nowMs) continue;

        try {
          await doc.ref.update({
            isReserved: false,
            reservedForOfferId: null,
            reservedUntil: null,
          });
          cleared++;

          const offerId = p.reservedForOfferId;
          if (offerId) {
            const offerRef = db.collection('price_offers').doc(offerId);
            const offerSnap = await offerRef.get();
            if (offerSnap.exists && (offerSnap.data() || {}).status === 'accepted') {
              await offerRef.update({status: 'expired'});
            }
          }
        } catch (e) {
          console.error(`⚠️ expireOfferReservations ${doc.id} failed:`, e);
        }
      }

      if (cleared > 0) {
        console.log(`🏷️ cleared ${cleared} lapsed offer reservation(s)`);
      }

      const staleAccepted = await db.collection('price_offers')
          .where('status', '==', 'accepted')
          .limit(500)
          .get();
      let expiredOffers = 0;
      for (const doc of staleAccepted.docs) {
        const o = doc.data() || {};
        const exp = o.offerExpiresAt;
        const expMs = exp && typeof exp.toMillis === 'function' ? exp.toMillis() : 0;
        if (!expMs || expMs > nowMs) continue;
        try {
          await doc.ref.update({status: 'expired'});
          expiredOffers++;
        } catch (e) {
          console.error(`⚠️ expireOfferReservations offer ${doc.id} failed:`, e);
        }
      }
      if (expiredOffers > 0) {
        console.log(`🏷️ expired ${expiredOffers} lapsed accepted offer(s) with no product hold`);
      }
      return null;
    });

exports.acceptCounterOffer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const uid = context.auth.uid;
  const offerId = data && data.offerId;
  if (!offerId || typeof offerId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'offerId is required.');
  }
  const db = admin.firestore();
  const offerRef = db.collection('price_offers').doc(offerId);
  const expiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + PRICE_OFFER_ACCEPTANCE_WINDOW_MS);

  const result = await db.runTransaction(async (t) => {
    const offerSnap = await t.get(offerRef);
    if (!offerSnap.exists) throw new functions.https.HttpsError('not-found', 'Offer not found.');
    const o = offerSnap.data() || {};
    if (o.buyerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only the buyer may accept a counter-offer.');
    }
    if (o.status !== 'countered') {
      throw new functions.https.HttpsError('failed-precondition', `Offer is not countered (status: ${o.status}).`);
    }
    const counterPrice = Number(o.counterPrice);
    if (!Number.isFinite(counterPrice) || counterPrice <= 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Offer has no valid counterPrice.');
    }
    const productId = o.productId;
    if (!productId || typeof productId !== 'string') {
      throw new functions.https.HttpsError('failed-precondition', 'Offer has no productId.');
    }
    const productRef = db.collection('products').doc(productId);
    const productSnap = await t.get(productRef);
    if (!productSnap.exists) throw new functions.https.HttpsError('not-found', 'Product not found.');
    const p = productSnap.data() || {};
    if (p.isSold === true) throw new functions.https.HttpsError('failed-precondition', 'Product already sold.');

    const heldFor = p.reservedForOfferId;
    const until = p.reservedUntil;
    const untilMs = until && typeof until.toMillis === 'function' ? until.toMillis() : 0;
    if (p.isReserved === true && heldFor && heldFor !== offerId && untilMs > Date.now()) {
      throw new functions.https.HttpsError('failed-precondition', 'Product is reserved for another buyer.');
    }

    t.update(offerRef, {
      status: 'accepted',
      offeredPrice: counterPrice,
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      offerExpiresAt: expiresAt,
    });
    t.update(productRef, {
      isReserved: true,
      reservedForOfferId: offerId,
      reservedUntil: expiresAt,
    });
    return {sellerId: o.sellerId || null, productId, counterPrice};
  });

  await notifyUser(result.sellerId, 'price_offer',
      '✅ הקונה קיבל את ההצעה הנגדית שלך',
      `הקונה אישר מחיר של ₪${Math.round(result.counterPrice)}. יש לו 24 שעות להשלים את התשלום.`,
      {productId: result.productId, offerId,
        offeredPrice: String(result.counterPrice)});

  console.log(`✅ Counter-offer ${offerId} accepted by buyer ${uid} at ₪${result.counterPrice}`);
  return {success: true, offerId, offeredPrice: result.counterPrice,
    offerExpiresAtMillis: expiresAt.toMillis()};
});

const PRICE_OFFER_NOTIFY_GRACE_MS = 20 * 1000;

function queuedPushCoversOffer(queued, offer) {
  if (queued.userId !== offer.sellerId) return false;
  const data = queued.data || {};
  if (data.type !== 'price_offer' && data.type !== 'priceOffer') return false;
  if (data.offerId) return data.offerId === offer.offerId;
  if (!offer.productId || data.productId !== offer.productId) return false;
  if (Number(data.offeredPrice) !== offer.amount) return false;
  if (!offer.buyerName) return false;
  const body = (queued.notification && queued.notification.body) || '';
  return body.includes(offer.buyerName);
}

const PRICE_OFFER_QUEUE_SCAN_LIMIT = 200;

exports.notifySellerOnPriceOffer = functions
    .runWith({timeoutSeconds: 120})
    .firestore
    .document('price_offers/{offerId}')
    .onCreate(async (snap, context) => {
      const offerId = context.params.offerId;
      const offer = snap.data() || {};
      const sellerId = offer.sellerId;
      const buyerId = offer.buyerId;
      const productId = offer.productId;
      const amount = Number(offer.offeredPrice);

      if (!sellerId) {
        console.error(`⚠️ price offer ${offerId} has no sellerId — nobody to notify`);
        return null;
      }
      if (sellerId === buyerId) return null;
      if (!Number.isFinite(amount) || amount <= 0) {
        console.error(`⚠️ price offer ${offerId} has no usable offeredPrice (${offer.offeredPrice})`);
        return null;
      }

      const db = admin.firestore();

      const offerCreatedAt = snap.createTime || admin.firestore.Timestamp.now();
      const offerCreatedMs = offerCreatedAt.toMillis();

      await new Promise((resolve) => setTimeout(resolve, PRICE_OFFER_NOTIFY_GRACE_MS));

      try {
        const fresh = await snap.ref.get();
        if (!fresh.exists) return null;
        const current = fresh.data() || {};
        if (current.sellerNotifiedAt) {
          console.log(`ℹ️ price offer ${offerId}: seller already notified (${current.sellerNotifiedVia || 'unknown'}) — skipping`);
          return null;
        }
        if (current.status && current.status !== 'pending') {
          console.log(`ℹ️ price offer ${offerId}: already ${current.status} — the seller has clearly seen it`);
          return null;
        }

        const queued = await db.collection('fcm_queue')
            .where('createdAt', '>=', offerCreatedAt)
            .limit(PRICE_OFFER_QUEUE_SCAN_LIMIT)
            .get();
        const pushAlreadyQueued = queued.docs.some((d) =>
          queuedPushCoversOffer(d.data() || {}, {
            offerId, sellerId, productId, amount, buyerName: offer.buyerName,
          }));

        if (pushAlreadyQueued) {
          console.log(`ℹ️ price offer ${offerId}: buyer's client already queued the push to seller ${sellerId} — not duplicating`);
          await snap.ref.update({
            sellerNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            sellerNotifiedVia: 'client',
          });
          return null;
        }

        const recent = await db.collection('notifications')
            .where('userId', '==', sellerId)
            .orderBy('createdAt', 'desc')
            .limit(20)
            .get();
        const inAppRowExists = recent.docs.some((d) => {
          const n = d.data() || {};
          if (n.type !== 'price_offer' && n.type !== 'priceOffer') return false;
          const createdMs = n.createdAt && typeof n.createdAt.toMillis === 'function' ?
              n.createdAt.toMillis() : 0;
          if (createdMs < offerCreatedMs) return false;
          const nd = n.data || {};
          if (nd.offerId) return nd.offerId === offerId;
          return !!productId && nd.productId === productId &&
              Number(nd.offeredPrice) === amount;
        });

        let buyerName = offer.buyerName;
        if (!buyerName && buyerId) {
          const u = await db.collection('users').doc(buyerId).get();
          const ud = u.exists ? u.data() : null;
          if (ud) buyerName = ud.displayName || ud.name;
        }
        buyerName = buyerName || 'משתמש';

        let productTitle = offer.productTitle;
        if (!productTitle && productId) {
          const p = await db.collection('products').doc(productId).get();
          if (p.exists) productTitle = (p.data() || {}).title;
        }
        productTitle = String(productTitle || 'המוצר שלך');
        if (productTitle.length > 40) productTitle = `${productTitle.slice(0, 39)}…`;

        await notifyUser(sellerId, 'price_offer',
            '💰 הצעת מחיר חדשה',
            `${buyerName} הציע ₪${Math.round(amount)} על ${productTitle}`,
            {productId: productId || '', offerId, offeredPrice: String(amount),
              tag: `price_offer_${offerId}`},
            {skipInApp: inAppRowExists});

        await snap.ref.update({
          sellerNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          sellerNotifiedVia: inAppRowExists ? 'server_push' : 'server',
        });
        console.log(`✅ price offer ${offerId}: seller ${sellerId} notified server-side (₪${amount}${inAppRowExists ? ', push only — client had already written the in-app row' : ''})`);
      } catch (e) {
        console.error(`⚠️ notifySellerOnPriceOffer failed for ${offerId}:`, e);
      }
      return null;
    });

exports.notifyBuyerOnCounterOffer = functions.firestore
    .document('price_offers/{offerId}')
    .onUpdate(async (change, context) => {
      const offerId = context.params.offerId;
      const before = change.before.data() || {};
      const after = change.after.data() || {};

      const counterAmountOf = (o) => {
        const n = Number(o.counterPrice);
        return Number.isFinite(n) ? n : null;
      };
      const enteringCountered = before.status !== 'countered';
      const counterAmountChanged =
          counterAmountOf(before) !== counterAmountOf(after);
      if (after.status !== 'countered' ||
          !(enteringCountered || counterAmountChanged)) {
        return null;
      }

      const buyerId = after.buyerId;
      if (!buyerId) {
        console.error(`⚠️ price offer ${offerId} countered but has no buyerId — nobody to notify`);
        return null;
      }
      if (buyerId === after.sellerId) return null;

      const amount = Number(after.counterPrice);
      if (!Number.isFinite(amount) || amount <= 0) {
        console.error(`⚠️ price offer ${offerId} countered with no usable counterPrice (${after.counterPrice})`);
        return null;
      }

      const counteredAtMs = change.after.updateTime ?
          change.after.updateTime.toMillis() : Date.now();

      const db = admin.firestore();
      try {
        const fresh = await change.after.ref.get();
        if (!fresh.exists) return null;
        const current = fresh.data() || {};
        if (current.status !== 'countered') {
          console.log(`ℹ️ counter on offer ${offerId}: already ${current.status} — skipping notification`);
          return null;
        }
        const marker = current.buyerCounterNotifiedAt;
        if (marker && typeof marker.toMillis === 'function' &&
            marker.toMillis() >= counteredAtMs) {
          console.log(`ℹ️ counter on offer ${offerId}: buyer already notified — skipping (retry)`);
          return null;
        }

        let sellerName;
        if (after.sellerId) {
          const u = await db.collection('users').doc(after.sellerId).get();
          const ud = u.exists ? u.data() : null;
          if (ud) sellerName = ud.displayName || ud.name;
        }
        sellerName = sellerName || 'המוכר';

        let productTitle = after.productTitle;
        if (!productTitle && after.productId) {
          const p = await db.collection('products').doc(after.productId).get();
          if (p.exists) productTitle = (p.data() || {}).title;
        }
        productTitle = String(productTitle || 'המוצר');
        if (productTitle.length > 40) productTitle = `${productTitle.slice(0, 39)}…`;

        await notifyUser(buyerId, 'price_offer',
            '💰 הצעה נגדית מהמוכר',
            `${sellerName} מציע ₪${Math.round(amount)} על ${productTitle}`,
            {productId: after.productId || '', offerId,
              counterPrice: String(amount),
              tag: `price_offer_counter_${offerId}`});

        await change.after.ref.update({
          buyerCounterNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ counter on offer ${offerId}: buyer ${buyerId} notified (₪${amount})`);
      } catch (e) {
        console.error(`⚠️ notifyBuyerOnCounterOffer failed for ${offerId}:`, e);
      }
      return null;
    });

const CHAT_MESSAGE_NOTIFY_GRACE_MS = 8 * 1000;

const CHAT_QUEUE_SCAN_LIMIT = 200;

const CHAT_PREVIEW_MAX_CHARS = 60;

function chatPushAlreadyQueuedBy(queued, chatId, recipientId) {
  if (queued.userId !== recipientId) return null;
  const data = queued.data || {};
  if (data.type !== 'new_message' && data.type !== 'newMessage') return null;
  if (!chatId || data.chatId !== chatId) return null;
  return data.messageId && data.tag === `chat_${chatId}` ? 'server' : 'client';
}

function chatNotificationDocId(chatId, recipientId) {
  return `chat_${chatId}__${recipientId}`;
}

exports.notifyChatRecipientOnMessage = functions
    .runWith({timeoutSeconds: 60})
    .firestore
    .document('messages/{messageId}')
    .onCreate(async (snap, context) => {
      const messageId = context.params.messageId;
      const message = snap.data() || {};
      const chatId = message.chatId;
      const senderId = message.senderId;

      if (!chatId || !senderId) {
        console.error(`⚠️ message ${messageId} has no chatId/senderId — nobody to resolve a recipient from`);
        return null;
      }

      const db = admin.firestore();

      const messageCreatedAt = snap.createTime || admin.firestore.Timestamp.now();

      await new Promise((resolve) => setTimeout(resolve, CHAT_MESSAGE_NOTIFY_GRACE_MS));

      try {
        const fresh = await snap.ref.get();
        if (!fresh.exists) return null;
        const current = fresh.data() || {};
        if (current.chatNotifiedAt) {
          console.log(`ℹ️ message ${messageId}: already handled — skipping (retry)`);
          return null;
        }

        const chatSnap = await db.collection('chats').doc(chatId).get();
        if (!chatSnap.exists) {
          console.log(`ℹ️ message ${messageId}: chat ${chatId} no longer exists — nothing to notify`);
          return null;
        }
        const chat = chatSnap.data() || {};

        const participants = [chat.buyerId, chat.sellerId]
            .filter((id) => typeof id === 'string' && id.length > 0);

        if (!participants.includes(senderId)) {
          console.error(`⚠️ message ${messageId}: sender ${senderId} is not a participant of chat ${chatId} — not notifying anyone`);
          return null;
        }

        const readBy = Array.isArray(current.readBy) ? current.readBy : [];
        const recipients = [...new Set(participants)]
            .filter((id) => id !== senderId)
            .filter((id) => !readBy.includes(id));

        if (recipients.length === 0) {
          console.log(`ℹ️ message ${messageId}: no recipient to notify (read on arrival, or no second participant)`);
          return null;
        }

        const queued = await db.collection('fcm_queue')
            .where('createdAt', '>=', messageCreatedAt)
            .limit(CHAT_QUEUE_SCAN_LIMIT)
            .get();

        let senderName = typeof current.senderName === 'string' ?
            current.senderName.trim() : '';
        if (!senderName) {
          const u = await db.collection('users').doc(senderId).get();
          const ud = u.exists ? (u.data() || {}) : {};
          senderName = ud.displayName || ud.name || '';
        }
        senderName = senderName || 'משתמש';

        let preview = typeof current.content === 'string' ?
            current.content.replace(/\s+/g, ' ').trim() : '';
        if (!preview) preview = current.imageUrl ? '📷 תמונה' : 'הודעה חדשה';
        if (preview.length > CHAT_PREVIEW_MAX_CHARS) {
          preview = `${preview.slice(0, CHAT_PREVIEW_MAX_CHARS - 1)}…`;
        }

        const title = `💬 ${senderName}`;
        const notified = [];

        for (const recipientId of recipients) {
          let coveredBy = null;
          for (const d of queued.docs) {
            const kind = chatPushAlreadyQueuedBy(d.data() || {}, chatId, recipientId);
            if (kind === 'client') { coveredBy = 'client'; break; }
            if (kind === 'server') coveredBy = 'server';
          }

          if (coveredBy === 'client') {
            console.log(`ℹ️ message ${messageId}: sender's client already queued the push to ${recipientId} — not duplicating`);
            continue;
          }

          await db.collection('notifications')
              .doc(chatNotificationDocId(chatId, recipientId))
              .set({
                userId: recipientId,
                type: 'new_message',
                title,
                body: preview,
                data: {chatId, senderId, messageId},
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              }, {merge: true});

          if (coveredBy === 'server') {
            console.log(`ℹ️ message ${messageId}: chat ${chatId} already buzzed ${recipientId} moments ago — row refreshed, push collapsed`);
            continue;
          }

          await notifyUser(recipientId, 'new_message', title, preview,
              {chatId, senderId, messageId, tag: `chat_${chatId}`},
              {skipInApp: true});

          notified.push(recipientId);
        }

        await snap.ref.update({
          chatNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          chatNotifiedRecipients: notified,
        });
        console.log(`✅ message ${messageId} in chat ${chatId}: pushed [${notified.join(', ')}]${notified.length ? '' : ' (nothing to push — this conversation had already buzzed)'}`);
      } catch (e) {
        console.error(`⚠️ notifyChatRecipientOnMessage failed for ${messageId}:`, e);
      }
      return null;
    });

exports.deleteUserAccount = functions
    .runWith({timeoutSeconds: 540, memory: '512MB'})
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
      }
      const uid = context.auth.uid;
      const db = admin.firestore();
      const ANON = 'משתמש שנמחק';
      const counts = {};

      async function commitInChunks(ops) {
        for (let i = 0; i < ops.length; i += 400) {
          const batch = db.batch();
          for (const op of ops.slice(i, i + 400)) {
            if (op.update) {
              batch.update(op.ref, op.update);
            } else {
              batch.delete(op.ref);
            }
          }
          await batch.commit();
        }
        return ops.length;
      }

      async function deleteWhere(coll, field, value) {
        const snap = await db.collection(coll).where(field, '==', value).get();
        return commitInChunks(snap.docs.map((d) => ({ref: d.ref})));
      }

      try {
        counts.products = await deleteWhere('products', 'sellerId', uid);

        const bucket = admin.storage().bucket();
        for (const prefix of [`product_images/${uid}/`, `avatars/${uid}/`,
          `storefront_assets/${uid}/`]) {
          try {
            await bucket.deleteFiles({prefix});
          } catch (e) {
            console.error(`⚠️ deleteUserAccount: storage prefix ${prefix} cleanup failed:`, e);
          }
        }

        const buyerOrders = await db.collection('orders')
            .where('buyerId', '==', uid).get();
        counts.ordersAnonymizedAsBuyer = await commitInChunks(
            buyerOrders.docs.map((d) => ({
              ref: d.ref,
              update: {
                buyerName: ANON,
                buyerPhone: ANON,
                buyerNotes: null,
                anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            })));

        const sellerOrders = await db.collection('orders')
            .where('sellerId', '==', uid).get();
        counts.ordersAnonymizedAsSeller = await commitInChunks(
            sellerOrders.docs.map((d) => ({
              ref: d.ref,
              update: {
                sellerName: ANON,
                pickupAddress: ANON,
                pickupPhone: ANON,
                anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            })));

        counts.addresses = await deleteWhere('addresses', 'userId', uid);
        counts.notifications = await deleteWhere('notifications', 'userId', uid);
        counts.priceOffersAsBuyer = await deleteWhere('price_offers', 'buyerId', uid);
        counts.priceOffersAsSeller = await deleteWhere('price_offers', 'sellerId', uid);
        counts.stories = await deleteWhere('stories', 'sellerId', uid);
        counts.userInteractions = await deleteWhere('user_interactions', 'userId', uid);

        await db.recursiveDelete(db.collection('carts').doc(uid));

        await db.collection('user_activities').doc(uid).delete();
        await db.collection('notification_preferences').doc(uid).delete();
        counts.savedSearches = await deleteWhere('saved_searches', 'userId', uid);
        counts.alerts = await deleteWhere('alerts', 'userId', uid);
        counts.alertMatches = await deleteWhere('alert_matches', 'userId', uid);

        const chatRefs = new Map();
        const [chatsAsBuyer, chatsAsSeller, chatsAsParticipant] = await Promise.all([
          db.collection('chats').where('buyerId', '==', uid).get(),
          db.collection('chats').where('sellerId', '==', uid).get(),
          db.collection('chats').where('participants', 'array-contains', uid).get()
              .catch(() => ({docs: []})),
        ]);
        for (const snap of [chatsAsBuyer, chatsAsSeller, chatsAsParticipant]) {
          for (const d of snap.docs) chatRefs.set(d.id, d.ref);
        }
        let messagesDeleted = 0;
        let messageSweepIncomplete = false;
        const chatIdList = [...chatRefs.keys()];
        for (let i = 0; i < chatIdList.length; i += 10) {
          const chunk = chatIdList.slice(i, i + 10);
          if (chunk.length === 0) continue;
          let iterations = 0;
          let chunkDrained = false;
          while (iterations < 100) {
            iterations++;
            const msgSnap = await db.collection('messages')
                .where('chatId', 'in', chunk)
                .limit(300)
                .get();
            if (msgSnap.empty) { chunkDrained = true; break; }
            await commitInChunks(msgSnap.docs.map((d) => ({ref: d.ref})));
            messagesDeleted += msgSnap.size;
            if (msgSnap.size < 300) { chunkDrained = true; break; }
          }
          if (!chunkDrained) messageSweepIncomplete = true;
        }
        counts.messages = messagesDeleted;

        if (messageSweepIncomplete) {
          await raiseOpsAlert({
            type: 'gdpr_erasure_incomplete',
            entityId: uid,
            message: 'deleteUserAccount: message purge hit its iteration cap; ' +
              'chats deliberately NOT deleted so a retry can still resolve them. ' +
              'Manual intervention required.',
          });
          throw new functions.https.HttpsError(
              'deadline-exceeded',
              'מחיקת החשבון לא הושלמה. הפנייה נרשמה ותטופל — נסה שוב מאוחר יותר.');
        }

        for (const ref of chatRefs.values()) {
          await db.recursiveDelete(ref);
        }
        counts.chats = chatRefs.size;

        await db.recursiveDelete(db.collection('users').doc(uid));

        await admin.auth().deleteUser(uid);

        console.log(`🗑️ deleteUserAccount: ${uid} erased`, counts);
        return {ok: true, counts};
      } catch (error) {
        console.error(`❌ deleteUserAccount failed for ${uid}:`, error);
        throw new functions.https.HttpsError(
            'internal', error.message || 'Account deletion failed');
      }
    });

Object.assign(exports, require('./src/pickupOrders')({
  functions,
  admin,
  stripe,
  notifyUser,
  assertStaff,
  webhookSecret: process.env.STRIPE_WEBHOOK_SECRET || (_legacyStripeCfg && _legacyStripeCfg.webhook_secret),
}));
