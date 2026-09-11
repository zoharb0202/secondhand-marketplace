const admin = require('firebase-admin');
const crypto = require('crypto');

function _cacheKey(namespace, material) {
  const h = crypto.createHash('sha256').update(String(material)).digest('hex');
  return `${namespace}_${h.slice(0, 48)}`;
}

async function cacheGet(namespace, material) {
  try {
    const ref = admin.firestore().collection('ai_cache')
        .doc(_cacheKey(namespace, material));
    const snap = await ref.get();
    if (!snap.exists) return null;
    const d = snap.data();
    if (d.expiresAt && d.expiresAt.toMillis && d.expiresAt.toMillis() <= Date.now()) {
      return null;
    }
    ref.update({ hits: admin.firestore.FieldValue.increment(1) }).catch(() => {});
    console.log(`💾 [CACHE] HIT ${namespace}`);
    return d.value;
  } catch (e) {
    console.error('⚠️ cacheGet failed:', e.message);
    return null;
  }
}

async function cacheSet(namespace, material, value, ttlSeconds) {
  try {
    await admin.firestore().collection('ai_cache')
        .doc(_cacheKey(namespace, material))
        .set({
          namespace,
          value,
          hits: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromMillis(
              Date.now() + ttlSeconds * 1000),
        });
    console.log(`💾 [CACHE] STORED ${namespace} (ttl ${ttlSeconds}s)`);
  } catch (e) {
    console.error('⚠️ cacheSet failed:', e.message);
  }
}

async function withCache(namespace, material, ttlSeconds, computeFn) {
  const cached = await cacheGet(namespace, material);
  if (cached !== null && cached !== undefined) return cached;
  const value = await computeFn();
  await cacheSet(namespace, material, value, ttlSeconds);
  return value;
}

async function batchWrite(operations) {
  const BATCH_SIZE = 500;
  const batches = [];

  for (let i = 0; i < operations.length; i += BATCH_SIZE) {
    const batchOps = operations.slice(i, i + BATCH_SIZE);
    const batch = admin.firestore().batch();

    for (const op of batchOps) {
      switch (op.type) {
        case 'set':
          batch.set(op.ref, op.data, op.options || {});
          break;
        case 'update':
          batch.update(op.ref, op.data);
          break;
        case 'delete':
          batch.delete(op.ref);
          break;
        default:
          console.warn(`Unknown operation type: ${op.type}`);
      }
    }

    batches.push(batch.commit());
  }

  await Promise.all(batches);
  console.log(`✅ Batch write completed: ${operations.length} operations in ${batches.length} batches`);
}

async function checkRateLimit(userId, action, maxRequests = 10, windowMs = 60000) {
  const now = Date.now();
  const rateLimitRef = admin.firestore()
    .collection('rate_limits')
    .doc(`${userId}_${action}`);

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);

      if (!doc.exists) {
        transaction.set(rateLimitRef, {
          count: 1,
          windowStart: now,
          expiresAt: new Date(now + windowMs),
        });
        return true;
      }

      const data = doc.data();
      const windowStart = data.windowStart;

      if (now - windowStart > windowMs) {
        transaction.update(rateLimitRef, {
          count: 1,
          windowStart: now,
          expiresAt: new Date(now + windowMs),
        });
        return true;
      }

      if (data.count >= maxRequests) {
        console.warn(`⚠️ Rate limit exceeded for user ${userId} on action ${action}`);
        return false;
      }

      transaction.update(rateLimitRef, {
        count: admin.firestore.FieldValue.increment(1),
      });
      return true;
    });

    return result;
  } catch (error) {
    console.error('❌ Rate limit check failed:', error);
    return false;
  }
}

class FunctionCache {
  constructor(ttlMs = 300000) {
    this.cache = new Map();
    this.ttl = ttlMs;
  }

  set(key, value) {
    this.cache.set(key, {
      value,
      expiresAt: Date.now() + this.ttl,
    });
  }

  get(key) {
    const entry = this.cache.get(key);

    if (!entry) return null;

    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return null;
    }

    return entry.value;
  }

  has(key) {
    return this.get(key) !== null;
  }

  delete(key) {
    this.cache.delete(key);
  }

  clear() {
    this.cache.clear();
  }

  size() {
    return this.cache.size;
  }
}

async function retryWithBackoff(fn, maxRetries = 3, delayMs = 1000) {
  let lastError;

  for (let i = 0; i <= maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (i === maxRetries) {
        break;
      }

      const delay = delayMs * Math.pow(2, i);
      console.log(`⚠️ Retry ${i + 1}/${maxRetries} after ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

async function processInParallel(items, processor, concurrency = 10) {
  const results = [];
  const executing = [];

  for (const [index, item] of items.entries()) {
    const promise = Promise.resolve().then(() => processor(item, index));
    results.push(promise);

    if (concurrency <= items.length) {
      const e = promise.then(() => {
        executing.splice(executing.indexOf(e), 1);
      });
      executing.push(e);

      if (executing.length >= concurrency) {
        await Promise.race(executing);
      }
    }
  }

  return Promise.all(results);
}

function logIndexHint(collectionName, fields) {
  console.log(`📊 Query on ${collectionName} with fields: ${fields.join(', ')}`);
  console.log(`💡 Ensure composite index exists for optimal performance`);
}

function createErrorResponse(code, message, details = {}) {
  return {
    success: false,
    error: {
      code,
      message,
      details,
      timestamp: new Date().toISOString(),
    },
  };
}

function createSuccessResponse(data, message = 'Success') {
  return {
    success: true,
    message,
    data,
    timestamp: new Date().toISOString(),
  };
}

module.exports = {
  batchWrite,
  checkRateLimit,
  FunctionCache,
  cacheGet,
  cacheSet,
  withCache,
  retryWithBackoff,
  processInParallel,
  logIndexHint,
  createErrorResponse,
  createSuccessResponse,
};
