/**
 * Storage uploads become app content automatically, so temple staff only
 * have to upload files in the Firebase console:
 *
 *   kirtans/{categoryId}/01 - Jay Sadguru Swami.mp3  → kirtans/{id}
 *   gallery/{albumId}/photo.jpg                      → albums/{albumId}/photos/{id}
 *   books/{categoryId}/Vachanamrut.pdf               → books/{id}
 *
 * Deleting the file removes the document again. Re-uploading a file with the
 * same name only refreshes its URL and size — titles and translations typed
 * by staff are never overwritten.
 */
import { FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions/logger';
import { onObjectDeleted, onObjectFinalized, type StorageObjectData } from 'firebase-functions/v2/storage';

import { db, downloadUrlFor, errorMessage, isAlreadyExists, isNotFound } from './admin';
import { Collections, REGION } from './config';
import {
  asNumber,
  asString,
  classifyObject,
  isStaleEvent,
  newAlbumFields,
  newBookFields,
  newKirtanFields,
  photoOrder,
  type StorageTarget,
} from './util';

/** Retried deliveries older than this are dropped instead of retried forever. */
const MAX_EVENT_AGE_MS = 60 * 60 * 1000;

type Target<K extends StorageTarget['kind']> = Extract<StorageTarget, { kind: K }>;

/** Fields refreshed on every (re-)upload of the same file. */
function fileFields(object: StorageObjectData): Record<string, unknown> {
  return {
    storagePath: object.name,
    sizeBytes: asNumber(object.size) ?? undefined,
    contentType: asString(object.contentType) ?? undefined,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

async function upsertKirtan(target: Target<'kirtan'>, object: StorageObjectData, url: string): Promise<void> {
  const ref = db().collection(Collections.kirtans).doc(target.docId);
  const refresh = { audioUrl: url, ...fileFields(object) };
  try {
    await ref.create({
      ...newKirtanFields(target.categoryId, target.fileName),
      ...refresh,
      createdAt: FieldValue.serverTimestamp(),
    });
    logger.info('Kirtan created from upload', { id: target.docId, path: object.name });
  } catch (error) {
    if (!isAlreadyExists(error)) throw error;
    await ref.update(refresh);
    logger.info('Kirtan file refreshed', { id: target.docId, path: object.name });
  }
}

async function upsertBook(target: Target<'book'>, object: StorageObjectData, url: string): Promise<void> {
  const ref = db().collection(Collections.books).doc(target.docId);
  const refresh = { pdfUrl: url, ...fileFields(object) };
  try {
    await ref.create({
      ...newBookFields(target.categoryId, target.fileName),
      ...refresh,
      createdAt: FieldValue.serverTimestamp(),
    });
    logger.info('Book created from upload', { id: target.docId, path: object.name });
  } catch (error) {
    if (!isAlreadyExists(error)) throw error;
    await ref.update(refresh);
    logger.info('Book file refreshed', { id: target.docId, path: object.name });
  }
}

function hasCover(value: unknown): boolean {
  return typeof value === 'string' && value.trim() !== '';
}

async function addPhoto(target: Target<'photo'>, object: StorageObjectData, url: string): Promise<void> {
  const albumRef = db().collection(Collections.albums).doc(target.albumId);
  const photoRef = albumRef.collection(Collections.photos).doc(target.docId);

  // 1. Make sure the album exists (a new album gets this photo as its cover).
  let albumCreated = false;
  try {
    await albumRef.create({
      ...newAlbumFields(target.albumId),
      coverUrl: url,
      photoCount: 0,
      createdAt: FieldValue.serverTimestamp(),
    });
    albumCreated = true;
    logger.info('Album created from upload', { albumId: target.albumId });
  } catch (error) {
    if (!isAlreadyExists(error)) throw error;
  }

  // 2. Create the photo (and count it) or refresh a re-uploaded one.
  const order = photoOrder(target.fileName);
  let isNewPhoto = false;
  try {
    await photoRef.create({
      url,
      ...(order !== null ? { order } : {}),
      ...fileFields(object),
      createdAt: FieldValue.serverTimestamp(),
    });
    isNewPhoto = true;
  } catch (error) {
    if (!isAlreadyExists(error)) throw error;
    await photoRef.update({ url, ...fileFields(object) });
  }

  try {
    if (isNewPhoto) {
      // Increments never conflict, so hundreds of parallel uploads stay fast.
      await albumRef.update({ photoCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() });
    }
    // 3. Give an existing album without a cover this photo.
    if (!albumCreated) {
      const album = await albumRef.get();
      if (album.exists && !hasCover(album.get('coverUrl'))) await albumRef.update({ coverUrl: url });
    }
  } catch (error) {
    // The album document was deleted while photos were still uploading.
    if (!isNotFound(error)) throw error;
    logger.warn('Album document missing; photo kept without updating the album', { albumId: target.albumId });
  }
}

/** Links a "Resize Images" thumbnail to its photo document (thumbUrl). */
async function attachThumbnail(target: Target<'thumb'>, object: StorageObjectData, url: string): Promise<void> {
  const photoRef = db()
    .collection(Collections.albums)
    .doc(target.albumId)
    .collection(Collections.photos)
    .doc(target.photoId);
  // The thumbnail can arrive a moment before the original's document exists.
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      await photoRef.update({ thumbUrl: url, thumbStoragePath: object.name });
      return;
    } catch (error) {
      if (!isNotFound(error)) throw error;
      await sleep(attempt * 2000);
    }
  }
  logger.info('Thumbnail has no matching photo; ignored', { path: object.name, photoId: target.photoId });
}

export const onStorageUpload = onObjectFinalized({ region: REGION, retry: true }, async (event) => {
  const object = event.data;
  const target = classifyObject(object.name, object.contentType, object.metadata);
  if (target.kind === 'ignore') {
    logger.info('Upload ignored', { path: object.name, reason: target.reason });
    return;
  }
  if (asNumber(object.size) === 0) {
    logger.info('Empty file ignored', { path: object.name });
    return;
  }
  if (isStaleEvent(event.time, Date.now(), MAX_EVENT_AGE_MS)) {
    logger.error('Giving up on an old upload event', { path: object.name, time: event.time });
    return;
  }

  // Thrown errors make Cloud Functions retry the event (handlers are idempotent).
  try {
    const url = await downloadUrlFor(object.name, object.bucket);
    switch (target.kind) {
      case 'kirtan':
        return await upsertKirtan(target, object, url);
      case 'book':
        return await upsertBook(target, object, url);
      case 'photo':
        return await addPhoto(target, object, url);
      case 'thumb':
        return await attachThumbnail(target, object, url);
    }
  } catch (error) {
    logger.error('Could not process upload; will retry', { path: object.name, error: errorMessage(error) });
    throw error;
  }
});

async function deleteWhereStoragePath(collection: string, path: string): Promise<void> {
  const docs = await db().collection(collection).where('storagePath', '==', path).get();
  await Promise.all(docs.docs.map((doc) => doc.ref.delete()));
  if (!docs.empty) logger.info('Removed documents for deleted file', { collection, path, count: docs.size });
}

async function removePhoto(target: Target<'photo'>, path: string): Promise<void> {
  const albumRef = db().collection(Collections.albums).doc(target.albumId);
  const photos = await albumRef.collection(Collections.photos).where('storagePath', '==', path).get();
  for (const photo of photos.docs) {
    const removed = await db().runTransaction(async (tx) => {
      const [photoSnap, albumSnap] = await Promise.all([tx.get(photo.ref), tx.get(albumRef)]);
      if (!photoSnap.exists) return null;
      tx.delete(photo.ref);
      if (albumSnap.exists) {
        const count = asNumber(albumSnap.get('photoCount')) ?? 1;
        tx.update(albumRef, { photoCount: Math.max(0, Math.round(count) - 1), updatedAt: FieldValue.serverTimestamp() });
      }
      return { url: asString(photoSnap.get('url')), cover: albumSnap.exists ? asString(albumSnap.get('coverUrl')) : null };
    });
    // Replace the album cover when it was this photo.
    if (removed?.cover && (removed.cover === removed.url || removed.cover === path)) {
      const next = await albumRef.collection(Collections.photos).limit(1).get();
      const nextUrl = asString(next.docs[0]?.get('url'));
      await albumRef.update({ coverUrl: nextUrl ?? FieldValue.delete() });
    }
  }
  if (!photos.empty) logger.info('Removed photo for deleted file', { albumId: target.albumId, path });
}

async function detachThumbnail(target: Target<'thumb'>, path: string): Promise<void> {
  const photos = await db()
    .collection(Collections.albums)
    .doc(target.albumId)
    .collection(Collections.photos)
    .where('thumbStoragePath', '==', path)
    .get();
  await Promise.all(
    photos.docs.map((doc) => doc.ref.update({ thumbUrl: FieldValue.delete(), thumbStoragePath: FieldValue.delete() })),
  );
}

export const onStorageDelete = onObjectDeleted({ region: REGION, retry: true }, async (event) => {
  const object = event.data;
  const target = classifyObject(object.name, object.contentType, object.metadata);
  if (target.kind === 'ignore') return;
  if (isStaleEvent(event.time, Date.now(), MAX_EVENT_AGE_MS)) {
    logger.error('Giving up on an old delete event', { path: object.name, time: event.time });
    return;
  }

  try {
    // Replacing a file also "deletes" the old version: keep the document then.
    const [exists] = await getStorage().bucket(object.bucket).file(object.name).exists();
    if (exists) return;

    switch (target.kind) {
      case 'kirtan':
        return await deleteWhereStoragePath(Collections.kirtans, object.name);
      case 'book':
        return await deleteWhereStoragePath(Collections.books, object.name);
      case 'photo':
        return await removePhoto(target, object.name);
      case 'thumb':
        return await detachThumbnail(target, object.name);
    }
  } catch (error) {
    logger.error('Could not process delete; will retry', { path: object.name, error: errorMessage(error) });
    throw error;
  }
});
