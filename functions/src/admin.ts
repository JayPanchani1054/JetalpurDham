/**
 * Lazily-initialised Firebase Admin services and small helpers around them.
 */
import { randomUUID } from 'node:crypto';

import { getApps, initializeApp } from 'firebase-admin/app';
import { type Firestore, getFirestore, GrpcStatus } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getDownloadURL, getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions/logger';

import { buildMessages, type Lang, LANGUAGES, type LocalizedPush, httpsUrlOrNull, parseGsUrl } from './util';

if (getApps().length === 0) initializeApp();

let firestore: Firestore | undefined;

/** Firestore with `ignoreUndefinedProperties` so optional fields can be omitted. */
export function db(): Firestore {
  if (!firestore) {
    firestore = getFirestore();
    firestore.settings({ ignoreUndefinedProperties: true });
  }
  return firestore;
}

/** Project id of the running function (or emulator). */
export function projectId(): string | null {
  if (process.env['GCLOUD_PROJECT']) return process.env['GCLOUD_PROJECT'];
  try {
    const config = JSON.parse(process.env['FIREBASE_CONFIG'] ?? '{}') as { projectId?: unknown };
    return typeof config.projectId === 'string' ? config.projectId : null;
  } catch {
    return null;
  }
}

/** Numeric gRPC status (Firestore) or HTTP status (Storage) of an error. */
export function errorCode(error: unknown): unknown {
  return typeof error === 'object' && error !== null && 'code' in error ? (error as { code: unknown }).code : undefined;
}

export function isAlreadyExists(error: unknown): boolean {
  return errorCode(error) === GrpcStatus.ALREADY_EXISTS;
}

export function isNotFound(error: unknown): boolean {
  return errorCode(error) === GrpcStatus.NOT_FOUND;
}

export function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return typeof error === 'string' ? error : JSON.stringify(error);
}

/**
 * Public download URL (with token) for a Storage object — the same kind of
 * URL the Firebase console shows. Files uploaded with tools that do not add a
 * download token (gsutil, gcloud) get one here.
 */
export async function downloadUrlFor(path: string, bucketName?: string): Promise<string> {
  const storage = getStorage();
  const file = (bucketName ? storage.bucket(bucketName) : storage.bucket()).file(path);
  try {
    return await getDownloadURL(file);
  } catch (error) {
    if (errorCode(error) !== 'storage/no-download-token') throw error;
  }
  const [metadata] = await file.getMetadata();
  try {
    await file.setMetadata(
      { metadata: { firebaseStorageDownloadTokens: randomUUID() } },
      metadata.metageneration !== undefined ? { ifMetagenerationMatch: metadata.metageneration } : {},
    );
  } catch (error) {
    // 412: someone else added a token at the same moment — use theirs.
    if (errorCode(error) !== 412) throw error;
  }
  return getDownloadURL(file);
}

/**
 * Resolves a MediaRef (https URL, gs:// URL or bare Storage path) to a public
 * https URL. Returns null (never throws) when it cannot be resolved.
 */
export async function resolveMediaUrl(ref: unknown): Promise<string | null> {
  if (typeof ref !== 'string') return null;
  const value = ref.trim();
  if (value === '') return null;
  if (/^https?:\/\//iu.test(value)) return httpsUrlOrNull(value);
  try {
    if (value.toLowerCase().startsWith('gs://')) {
      const gs = parseGsUrl(value);
      return gs ? await downloadUrlFor(gs.path, gs.bucket) : null;
    }
    return await downloadUrlFor(value.replace(/^\/+/u, ''));
  } catch (error) {
    logger.warn('Could not resolve media URL; sending without it.', { ref: value, error: errorMessage(error) });
    return null;
  }
}

export interface SendSummary {
  successCount: number;
  failureCount: number;
  errors: string[];
}

/** Sends [push] to every language topic (lang_en, lang_gu, lang_hi). */
export async function sendToAllLanguages(push: LocalizedPush, languages: readonly Lang[] = LANGUAGES): Promise<SendSummary> {
  const messages = buildMessages(push, languages);
  const response = await getMessaging().sendEach(messages);
  const errors = response.responses
    .map((r, i) => (r.success ? null : `${messages[i]?.topic ?? '?'}: ${r.error?.message ?? 'unknown error'}`))
    .filter((e): e is string => e !== null);
  return { successCount: response.successCount, failureCount: response.failureCount, errors };
}
