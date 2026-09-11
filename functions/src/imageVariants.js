const admin = require('firebase-admin');
const functions = require('firebase-functions');
const {storageObjectPath} = require('./storageUrls');

const PRODUCT_IMAGES_PREFIX = 'product_images/';

function parseResizedObjectPath(objectPath) {
  if (typeof objectPath !== 'string' ||
      !objectPath.startsWith(PRODUCT_IMAGES_PREFIX)) {
    return null;
  }
  const slash = objectPath.lastIndexOf('/');
  if (slash <= PRODUCT_IMAGES_PREFIX.length - 2) return null;
  const folder = objectPath.slice(0, slash);
  const fileName = objectPath.slice(slash + 1);

  const match = /^(.+)_(\d+)x(\d+)(\.[^./]+)?$/.exec(fileName);
  if (!match) return null;
  const [, stem, widthStr, heightStr, ext] = match;
  if (!stem) return null;
  const width = Number(widthStr);
  const height = Number(heightStr);
  if (!Number.isFinite(width) || !Number.isFinite(height)) return null;

  return {
    originalPath: `${folder}/${stem}${ext || ''}`,
    width,
    height,
  };
}

function variantKeyFor(width, height) {
  if (width === 600 && height === 600) return 'thumb';
  if (width === 1280 && height === 1280) return 'medium';
  return null;
}

function sellerUidFromProductImagePath(objectPath) {
  if (typeof objectPath !== 'string' ||
      !objectPath.startsWith(PRODUCT_IMAGES_PREFIX)) {
    return null;
  }
  const rest = objectPath.slice(PRODUCT_IMAGES_PREFIX.length);
  const slash = rest.indexOf('/');
  if (slash <= 0) return null;
  const uid = rest.slice(0, slash);
  return uid || null;
}

function downloadUrlFor(bucket, objectPath) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/` +
    `${encodeURIComponent(objectPath)}?alt=media`;
}

function mergeVariant(existing, originalUrl, variantKey, variantUrl) {
  const list = Array.isArray(existing) ? existing : [];
  const idx = list.findIndex((e) => e && e.original === originalUrl);
  if (idx === -1) {
    return [...list, {original: originalUrl, [variantKey]: variantUrl}];
  }
  const next = list.slice();
  next[idx] = {...next[idx], original: originalUrl, [variantKey]: variantUrl};
  return next;
}

const onProductImageResized = functions.storage.object().onFinalize(async (object) => {
  const objectPath = object.name;
  const parsed = parseResizedObjectPath(objectPath);
  if (!parsed) return null;

  const variantKey = variantKeyFor(parsed.width, parsed.height);
  if (!variantKey) return null;

  const sellerUid = sellerUidFromProductImagePath(parsed.originalPath);
  if (!sellerUid) return null;

  const db = admin.firestore();
  const variantUrl = downloadUrlFor(object.bucket, objectPath);

  const candidates = await db.collection('products')
      .where('sellerId', '==', sellerUid)
      .get();

  for (const doc of candidates.docs) {
    const data = doc.data() || {};
    const imageUrls = Array.isArray(data.imageUrls) ? data.imageUrls : [];
    const originalUrl = imageUrls.find(
        (u) => storageObjectPath(u) === parsed.originalPath);
    if (!originalUrl) continue;

    const nextVariants = mergeVariant(
        data.imageVariants, originalUrl, variantKey, variantUrl);
    await doc.ref.update({imageVariants: nextVariants});
    return null;
  }

  return null;
});

module.exports = {
  parseResizedObjectPath,
  variantKeyFor,
  sellerUidFromProductImagePath,
  downloadUrlFor,
  mergeVariant,
  onProductImageResized,
};
