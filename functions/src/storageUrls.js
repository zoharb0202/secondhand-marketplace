const admin = require('firebase-admin');

const STORAGE_BUCKET_FALLBACK = 'your-project-id.firebasestorage.app';

function storageBucketNames() {
  const names = [STORAGE_BUCKET_FALLBACK];
  try {
    const options = admin.app().options || {};
    if (typeof options.storageBucket === 'string' && options.storageBucket &&
        names.indexOf(options.storageBucket) === -1) {
      names.push(options.storageBucket);
    }
  } catch (e) {
  }
  return names;
}

function storageObjectPath(raw) {
  let url;
  try {
    url = new URL(raw);
  } catch (e) {
    return null;
  }
  if (url.protocol !== 'https:') return null;

  let bucket = null;
  let encodedPath = null;
  const host = url.hostname.toLowerCase();
  if (host === 'firebasestorage.googleapis.com') {
    const match = /^\/v0\/b\/([^/]+)\/o\/(.+)$/.exec(url.pathname);
    if (match) {
      bucket = match[1];
      encodedPath = match[2];
    }
  } else if (host === 'storage.googleapis.com') {
    const match = /^\/([^/]+)\/(.+)$/.exec(url.pathname);
    if (match) {
      bucket = match[1];
      encodedPath = match[2];
    }
  }
  if (!bucket || !encodedPath) return null;

  let path;
  try {
    bucket = decodeURIComponent(bucket);
    path = decodeURIComponent(encodedPath);
  } catch (e) {
    return null;
  }
  if (storageBucketNames().indexOf(bucket) === -1) return null;
  if (path.split('/').indexOf('..') !== -1) return null;
  return path;
}

function objectBelongsToFolder(raw, prefix) {
  if (typeof raw !== 'string' || raw.length === 0) return false;
  const objectPath = storageObjectPath(raw);
  return objectPath !== null &&
    objectPath.indexOf(prefix) === 0 &&
    objectPath.length > prefix.length;
}

async function objectExistsInFolder(raw, prefix) {
  if (!objectBelongsToFolder(raw, prefix)) return false;
  const objectPath = storageObjectPath(raw);
  try {
    const [meta] = await admin.storage().bucket().file(objectPath).getMetadata();
    return !!(meta && Number(meta.size) > 0);
  } catch (e) {
    return false;
  }
}

module.exports = {
  STORAGE_BUCKET_FALLBACK,
  storageBucketNames,
  storageObjectPath,
  objectBelongsToFolder,
  objectExistsInFolder,
};
