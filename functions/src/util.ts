/**
 * Pure helpers (no Firebase calls) shared by the Cloud Functions. Everything
 * here is deterministic and unit-tested in util.test.ts.
 *
 * Content is typed by hand in the Firebase console, so every helper accepts
 * `unknown` and never throws on missing or wrongly-typed values.
 */
import { createHash } from 'node:crypto';

import type { TopicMessage } from 'firebase-admin/messaging';

import { DEFAULT_BOOK_LANGUAGE, DonationEmailLimits, DonationRetention, Push, StorageFolders } from './config';

// ---------------------------------------------------------------------------
// Languages & LocalizedText
// ---------------------------------------------------------------------------

export const LANGUAGES = ['en', 'gu', 'hi'] as const;
export type Lang = (typeof LANGUAGES)[number];

/** Same fallback order as LocalizedText in the app: English, Gujarati, Hindi. */
const FALLBACK_ORDER: readonly Lang[] = ['en', 'gu', 'hi'];

export type Localized = Record<Lang, string>;

/** Shown when an event or message has no title. */
export const DEFAULT_TITLE: Localized = {
  en: 'Jetalpur Dham',
  gu: 'જેતલપુરધામ',
  hi: 'जेतलपुरधाम',
};

/** Shown when an event or message has no description. */
export const DEFAULT_BODY: Localized = {
  en: 'Tap to view details',
  gu: 'વિગતો જોવા માટે ટૅપ કરો',
  hi: 'विवरण देखने के लिए टैप करें',
};

/** Max characters taken from a long description for a notification body. */
export const DESCRIPTION_PREVIEW_LENGTH = 140;
const MAX_TITLE_LENGTH = 120;
const MAX_BODY_LENGTH = 400;

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Resolves a LocalizedText value: either a plain string (used for every
 * language) or a map like `{ en, gu, hi }`. Missing languages fall back to
 * English, then Gujarati, then Hindi, then any other key. Returns '' when
 * nothing usable is present.
 */
export function localize(value: unknown, lang: string): string {
  if (typeof value === 'string') return value.trim();
  if (!isRecord(value)) return '';
  const texts = new Map<string, string>();
  for (const [key, text] of Object.entries(value)) {
    if (typeof text === 'string' && text.trim() !== '') {
      texts.set(key.trim().toLowerCase(), text.trim());
    }
  }
  const exact = texts.get(lang.toLowerCase());
  if (exact) return exact;
  for (const code of FALLBACK_ORDER) {
    const text = texts.get(code);
    if (text) return text;
  }
  const first = texts.values().next();
  return first.done ? '' : first.value;
}

/** True when [value] resolves to non-empty text in at least one language. */
export function hasText(value: unknown): boolean {
  return localize(value, 'en') !== '';
}

/** Collapses runs of whitespace (including new lines) into single spaces. */
export function collapseWhitespace(text: string): string {
  return text.replace(/\s+/gu, ' ').trim();
}

/**
 * Shortens [text] to at most [max] characters, preferring a word boundary,
 * and adds an ellipsis when something was cut. Safe for any Unicode text.
 */
export function truncate(text: string, max: number): string {
  const chars = Array.from(text);
  if (chars.length <= max) return text;
  const keep = Math.max(1, max - 1);
  const cut = chars.slice(0, keep).join('');
  // Keep the whole cut when it already ends at a word boundary.
  const endsOnWord = /\s/u.test(chars[keep] ?? ' ');
  const lastSpace = cut.lastIndexOf(' ');
  const head = !endsOnWord && lastSpace >= cut.length * 0.6 ? cut.slice(0, lastSpace) : cut;
  return `${head.replace(/[\s,.;:–—-]+$/u, '')}…`;
}

/**
 * Reads a boolean the way the app does (Fs.boolean): real booleans, the
 * strings "true"/"false"/"yes"/"no"/"1"/"0" and numbers are accepted.
 */
export function asBool(value: unknown, fallback: boolean): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const v = value.trim().toLowerCase();
    if (v === 'true' || v === 'yes' || v === '1') return true;
    if (v === 'false' || v === 'no' || v === '0') return false;
  }
  if (typeof value === 'number') return value !== 0;
  return fallback;
}

/** Non-empty trimmed string or null. */
export function asString(value: unknown): string | null {
  if (typeof value === 'string') {
    const v = value.trim();
    return v === '' ? null : v;
  }
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return null;
}

/** Finite number (numbers or numeric strings) or null. */
export function asNumber(value: unknown): number | null {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string' && value.trim() !== '') {
    const n = Number(value.trim());
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

// ---------------------------------------------------------------------------
// URLs and routes
// ---------------------------------------------------------------------------

/** Returns [value] when it is a valid https URL, otherwise null. */
export function httpsUrlOrNull(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const v = value.trim();
  if (!v.toLowerCase().startsWith('https://')) return null;
  try {
    const url = new URL(v);
    return url.protocol === 'https:' && url.hostname !== '' ? v : null;
  } catch {
    return null;
  }
}

/** Splits `gs://bucket/path/to/file` into its bucket and object path. */
export function parseGsUrl(value: string): { bucket: string; path: string } | null {
  const match = /^gs:\/\/([^/]+)\/(.+)$/u.exec(value.trim());
  if (!match || !match[1] || !match[2]) return null;
  return { bucket: match[1], path: match[2] };
}

/** In-app location of an event (matches Routes.event in the app). */
export function eventRoute(eventId: string): string {
  return `/events/${encodeURIComponent(eventId)}`;
}

/**
 * The events document id staff typed into a notification's `eventId`. Also
 * accepts what people tend to paste instead — `events/holi-2027`,
 * `/events/holi-2027` — and returns null for anything that cannot be a
 * document id.
 */
export function normalizeEventId(value: unknown): string | null {
  const raw = asString(value);
  if (!raw) return null;
  let id = raw.replace(/^\/+|\/+$/gu, '');
  if (id.toLowerCase().startsWith('events/')) id = id.slice('events/'.length).replace(/^\/+/u, '');
  id = decodeName(id).trim();
  return isValidDocId(id) ? id : null;
}

/**
 * Locations a notification may open, with everything below them; a root
 * ending in '/' only allows what is below it. Same list as
 * Routes._deepLinkRoots in the app, which checks every route again.
 */
const SAFE_ROUTE_ROOTS = ['/home', '/kirtan', '/places', '/library', '/reader/', '/events'] as const;

/**
 * Screens a notification cannot open from cold (same as
 * Routes._deepLinkRedirects in the app): the player needs a queue only the
 * app can build, so its tab opens instead.
 */
const ROUTE_REDIRECTS: Readonly<Record<string, string>> = { '/player': '/kirtan' };

/**
 * Returns the internal location the app should open for [value] (such as
 * `/events/abc` or `/home/donate`), or null when the app must not open it
 * from a notification. Mirrors Routes.deepLinkTarget in the app.
 */
export function safeRoute(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const route = value.trim();
  if (route === '' || route.length > 300) return null;
  if (!route.startsWith('/') || route.startsWith('//')) return null;
  if (/\s/u.test(route)) return null;
  // The app opens the parsed location, in which '.' and '..' segments are
  // already resolved ('/home/../player' is '/player'), so check that path.
  let path: string;
  try {
    path = new URL(route, 'https://app.invalid').pathname;
  } catch {
    return null;
  }
  const isUnder = (root: string): boolean =>
    root.endsWith('/') ? path.length > root.length && path.startsWith(root) : path === root || path.startsWith(`${root}/`);
  for (const [from, to] of Object.entries(ROUTE_REDIRECTS)) {
    if (isUnder(from)) return to;
  }
  return SAFE_ROUTE_ROOTS.some(isUnder) ? route : null;
}

// ---------------------------------------------------------------------------
// Push notifications
// ---------------------------------------------------------------------------

/** What the app needs to show one push message in every language. */
export interface LocalizedPush {
  /** LocalizedText. Falls back to DEFAULT_TITLE when empty. */
  title: unknown;
  /** LocalizedText used as the body when present (e.g. shortDescription). */
  body?: unknown;
  /** LocalizedText shortened to 140 characters when [body] is empty. */
  fallbackBody?: unknown;
  /** Public https image URL (already resolved). Ignored when not https. */
  imageUrl?: string | null;
  /** Extra data for the app. Every value must be a string. */
  data: Record<string, string>;
}

/** Title and body for one language, with all fallbacks applied. */
export function pushText(push: LocalizedPush, lang: Lang): { title: string; body: string } {
  const title = collapseWhitespace(localize(push.title, lang)) || DEFAULT_TITLE[lang];
  const body = collapseWhitespace(localize(push.body, lang));
  if (body) return { title: truncate(title, MAX_TITLE_LENGTH), body: truncate(body, MAX_BODY_LENGTH) };
  const description = collapseWhitespace(localize(push.fallbackBody, lang));
  return {
    title: truncate(title, MAX_TITLE_LENGTH),
    body: description ? truncate(description, DESCRIPTION_PREVIEW_LENGTH) : DEFAULT_BODY[lang],
  };
}

/** FCM topic for a language, e.g. `lang_gu`. */
export function topicFor(lang: Lang): string {
  return `${Push.topicPrefix}${lang}`;
}

/**
 * Builds one FCM message per language topic (lang_en, lang_gu, lang_hi), each
 * with the title and body in that language.
 */
export function buildMessages(push: LocalizedPush, languages: readonly Lang[] = LANGUAGES): TopicMessage[] {
  const imageUrl = httpsUrlOrNull(push.imageUrl);
  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(push.data)) {
    if (typeof value === 'string') data[key] = value;
  }
  return languages.map((lang): TopicMessage => {
    const { title, body } = pushText(push, lang);
    return {
      topic: topicFor(lang),
      notification: imageUrl ? { title, body, imageUrl } : { title, body },
      data: { ...data },
      android: {
        priority: 'high',
        notification: {
          channelId: Push.androidChannelId,
          color: Push.color,
          icon: Push.androidIcon,
          ...(imageUrl ? { imageUrl } : {}),
        },
      },
      apns: {
        payload: {
          // The Admin SDK sends mutableContent as "mutable-content": 1.
          aps: { sound: 'default', mutableContent: true },
        },
        ...(imageUrl ? { fcmOptions: { imageUrl } } : {}),
      },
    };
  });
}

/**
 * True when a retried trigger event is older than [maxAgeMs] and should be
 * dropped. Unparseable times are treated as fresh.
 */
export function isStaleEvent(eventTime: string | undefined, nowMs: number, maxAgeMs: number): boolean {
  if (!eventTime) return false;
  const time = Date.parse(eventTime);
  return Number.isFinite(time) && nowMs - time > maxAgeMs;
}

/** True when a timestamp-like field has been written (not missing/null/''). */
function isSet(value: unknown): boolean {
  if (value === undefined || value === null) return false;
  if (typeof value === 'string') return value.trim() !== '';
  return true;
}

/**
 * An event is announced exactly once, when `sendNotification` is true, the
 * event is active, it has a title and it has not been announced before
 * (`notifiedAt` missing). Deleting `notifiedAt` sends it again.
 */
export function shouldNotifyEvent(data: unknown): boolean {
  if (!isRecord(data)) return false;
  if (!asBool(data['sendNotification'], false)) return false;
  if (!asBool(data['isActive'], true)) return false;
  if (isSet(data['notifiedAt'])) return false;
  return hasText(data['title']);
}

/** Statuses written to `notifications/{id}` by the functions. */
export const NotificationStatus = {
  sending: 'sending',
  sent: 'sent',
  error: 'error',
} as const;

/** True when an ad-hoc notification document still needs to be sent. */
export function isNotificationPending(data: unknown): boolean {
  if (!isRecord(data)) return false;
  const status = asString(data['status'])?.toLowerCase();
  return status !== NotificationStatus.sending && status !== NotificationStatus.sent && status !== NotificationStatus.error;
}

/**
 * Where a tap on an ad-hoc notification should open: a valid `route`, else the
 * event of `eventId`, else the events list.
 */
export function notificationRoute(route: unknown, eventId: string | null): string {
  return safeRoute(route) ?? (eventId ? eventRoute(eventId) : '/events');
}

// ---------------------------------------------------------------------------
// Storage paths → Firestore documents
// ---------------------------------------------------------------------------

/** URL-friendly lowercase ASCII slug: "Jay Sadguru!" → "jay-sadguru". */
export function slug(input: string): string {
  return input
    .normalize('NFKD')
    .replace(/[̀-ͯ]/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/gu, '-')
    .replace(/^-+|-+$/gu, '');
}

/**
 * Deterministic Firestore document id for [raw] (usually a Storage path).
 * Readable when the name is plain ASCII; otherwise (Gujarati/Hindi names,
 * very long names) a short hash keeps ids unique and stable.
 */
export function stableId(raw: string, maxLength = 96): string {
  const base = slug(raw);
  const lossy = base === '' || /[^\x00-\x7F]/u.test(raw) || base.length > maxLength;
  if (!lossy) return base;
  const hash = createHash('sha1').update(raw, 'utf8').digest('hex').slice(0, 10);
  const head = base.slice(0, maxLength - hash.length - 1).replace(/-+$/u, '');
  return head ? `${head}-${hash}` : hash;
}

/** File name without its extension ("01 - Jay.mp3" → "01 - Jay"). */
export function stripExtension(fileName: string): string {
  const dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.slice(0, dot) : fileName;
}

/** Lower-case extension without the dot, or ''. */
export function extensionOf(fileName: string): string {
  const dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.slice(dot + 1).toLowerCase() : '';
}

/** Leading track number such as "01 - ", "1. ", "12_", "003 ". */
const TRACK_PREFIX = /^\s*(\d{1,3})(?:\s*[-._)\]:–—]+\s*|\s+)(?=\S)/u;

/** Order taken from a leading track number ("01 - Jay.mp3" → 1), or null. */
export function leadingOrder(fileName: string): number | null {
  const match = TRACK_PREFIX.exec(stripExtension(decodeName(fileName)));
  return match?.[1] ? Number(match[1]) : null;
}

/** "001", "0153" — a file name that is only a number. */
const NUMBER_ONLY = /^(\d{1,6})$/u;
/** "Avsar (12)" — what Windows Explorer's "rename all" produces. */
const NUMBERED_COPY = /\s*\((\d{1,6})\)$/u;
/** "IMG_0001", "DSC01234", "DSCN0042" — camera sequence numbers. */
const CAMERA_NAME = /^[A-Za-z]{2,5}[_-]?(\d{3,6})$/u;

/**
 * Position of an uploaded photo taken from its file name, so photos keep the
 * order staff gave them (or the camera's order) instead of upload order:
 * "01 - Aarti.jpg" → 1, "001.jpg" → 1, "Avsar (12).jpg" → 12,
 * "IMG_0042.jpg" → 42. Returns null when the name carries no number.
 */
export function photoOrder(fileName: string): number | null {
  const leading = leadingOrder(fileName);
  if (leading !== null) return leading;
  const base = collapseWhitespace(stripExtension(decodeName(fileName)));
  for (const pattern of [NUMBER_ONLY, NUMBERED_COPY, CAMERA_NAME]) {
    const match = pattern.exec(base);
    if (match?.[1]) return Number(match[1]);
  }
  return null;
}

function decodeName(name: string): string {
  if (!/%[0-9A-Fa-f]{2}/u.test(name)) return name;
  try {
    return decodeURIComponent(name);
  } catch {
    return name;
  }
}

/**
 * Turns a file or folder name into readable words: underscores and dashes
 * become spaces; all-lowercase or ALL-CAPS English words get a capital first
 * letter. Gujarati/Hindi text is kept exactly as written.
 */
export function humanize(text: string): string {
  const words = collapseWhitespace(decodeName(text).normalize('NFC').replace(/[_\-–—]+/gu, ' ')).split(' ');
  const letters = words.join('').replace(/[^A-Za-z]/gu, '');
  const shouting = letters.length > 1 && letters === letters.toUpperCase();
  return words
    .filter((w) => w !== '')
    .map((word) => {
      if (!/^[A-Za-z]/u.test(word)) return word;
      const rest = shouting ? word.slice(1).toLowerCase() : word.slice(1);
      return word.charAt(0).toUpperCase() + rest;
    })
    .join(' ');
}

/**
 * Readable title from an uploaded file name:
 * "01 - jay_sadguru_swami.mp3" → "Jay Sadguru Swami".
 */
export function prettyTitle(fileName: string): string {
  const base = stripExtension(decodeName(fileName));
  const title = humanize(base.replace(TRACK_PREFIX, ''));
  if (title !== '') return title;
  return humanize(base) || 'Untitled';
}

/** Language whose script [text] is written in (Gujarati, Devanagari, else English). */
export function scriptLanguage(text: string): Lang {
  if (/[઀-૿]/u.test(text)) return 'gu';
  if (/[ऀ-ॿ]/u.test(text)) return 'hi';
  return 'en';
}

/** LocalizedText map for an auto-created title, keyed by its script. */
export function localizedTitle(text: string): Partial<Localized> {
  return { [scriptLanguage(text)]: text };
}

/** Firestore rejects ids containing "/", "." or "..", and "__x__". */
export function isValidDocId(id: string): boolean {
  return id !== '' && id.length <= 200 && id !== '.' && id !== '..' && !id.includes('/') && !/^__.*__$/u.test(id);
}

const AUDIO_EXTENSIONS = new Set(['mp3', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'opus', 'flac']);
const IMAGE_EXTENSIONS = new Set(['jpg', 'jpeg', 'png', 'webp', 'gif']);
/** iPhone photos: most Android phones cannot show them — upload JPEG instead. */
const UNSUPPORTED_IMAGE_EXTENSIONS = new Set(['heic', 'heif', 'svg', 'tif', 'tiff', 'bmp']);
const THUMB_FOLDERS = new Set(['thumbs', 'thumbnails']);
/** Suffix added by the "Resize Images" extension: photo_400x400.jpg */
const RESIZED_SUFFIX = /_(\d{2,4})x(\d{2,4})$/u;

/**
 * True for files written by the "Resize Images" extension, which marks its
 * output with the custom metadata `resizedImage: "true"`.
 */
export function isMarkedResized(metadata: unknown): boolean {
  return isRecord(metadata) && String(metadata['resizedImage']).toLowerCase() === 'true';
}

function mediaType(contentType: string | null | undefined): string {
  return (contentType ?? '').split(';')[0]?.trim().toLowerCase() ?? '';
}

export function isAudio(fileName: string, contentType?: string | null): boolean {
  const type = mediaType(contentType);
  if (type.startsWith('audio/')) return true;
  return (type === '' || type === 'application/octet-stream' || type === 'video/mp4') && AUDIO_EXTENSIONS.has(extensionOf(fileName));
}

export function isImage(fileName: string, contentType?: string | null): boolean {
  const ext = extensionOf(fileName);
  if (UNSUPPORTED_IMAGE_EXTENSIONS.has(ext)) return false;
  const type = mediaType(contentType);
  if (type === 'image/heic' || type === 'image/heif' || type === 'image/svg+xml' || type === 'image/tiff') return false;
  if (type.startsWith('image/')) return true;
  return (type === '' || type === 'application/octet-stream') && IMAGE_EXTENSIONS.has(ext);
}

export function isPdf(fileName: string, contentType?: string | null): boolean {
  const type = mediaType(contentType);
  if (type === 'application/pdf') return true;
  return (type === '' || type === 'application/octet-stream') && extensionOf(fileName) === 'pdf';
}

/** What an uploaded/deleted Storage object means for Firestore. */
export type StorageTarget =
  | { kind: 'kirtan'; categoryId: string; fileName: string; docId: string }
  | { kind: 'photo'; albumId: string; fileName: string; docId: string }
  | { kind: 'thumb'; albumId: string; fileName: string; photoId: string }
  | { kind: 'book'; categoryId: string; fileName: string; docId: string }
  | { kind: 'ignore'; reason: string };

/**
 * Maps a Storage object to the document it manages:
 *  * `kirtans/{categoryId}/{file}` (audio)  → `kirtans/{docId}`
 *  * `gallery/{albumId}/{file}` (image)     → `albums/{albumId}/photos/{docId}`
 *  * `gallery/{albumId}/thumbs/{file}_400x400.jpg` → thumbnail of that photo
 *  * `books/{categoryId}/{file}.pdf`        → `books/{docId}`
 * Sub-folders are allowed; the id is derived from the whole path so it is
 * stable across re-uploads and unique per file.
 *
 * A gallery file is a thumbnail only when it is inside a `thumbs` folder or
 * the Resize Images extension marked it ([metadata] `resizedImage: "true"`),
 * so a devotee's own photo named e.g. `Stage_1920x1080.jpg` is still added.
 */
export function classifyObject(
  name: string | null | undefined,
  contentType?: string | null,
  metadata?: unknown,
): StorageTarget {
  if (!name || name.endsWith('/')) return { kind: 'ignore', reason: 'folder placeholder' };
  const segments = name.split('/').map((s) => s.trim()).filter((s) => s !== '');
  const fileName = segments[segments.length - 1] ?? '';
  if (fileName === '' || fileName.startsWith('.')) return { kind: 'ignore', reason: 'hidden or empty file name' };
  if (segments.length < 3) return { kind: 'ignore', reason: 'not inside a category/album folder' };

  const [root, parentId] = segments as [string, string, ...string[]];
  if (!isValidDocId(parentId)) return { kind: 'ignore', reason: `invalid folder name "${parentId}"` };
  // Path inside the category/album folder, without the file extension.
  const inner = segments.slice(2);
  const innerKey = [...inner.slice(0, -1), stripExtension(fileName)].join('/');

  switch (root) {
    case StorageFolders.kirtans:
      if (!isAudio(fileName, contentType)) return { kind: 'ignore', reason: 'not an audio file' };
      return { kind: 'kirtan', categoryId: parentId, fileName, docId: stableId(`${parentId}/${innerKey}`) };

    case StorageFolders.books:
      if (!isPdf(fileName, contentType)) return { kind: 'ignore', reason: 'not a PDF file' };
      return { kind: 'book', categoryId: parentId, fileName, docId: stableId(`${parentId}/${innerKey}`) };

    case StorageFolders.gallery: {
      const folders = inner.slice(0, -1);
      const base = stripExtension(fileName);
      const inThumbFolder = folders.some((f) => THUMB_FOLDERS.has(f.toLowerCase()));
      if (inThumbFolder || isMarkedResized(metadata)) {
        const resized = RESIZED_SUFFIX.test(base);
        if (!resized || !isImage(fileName, contentType)) return { kind: 'ignore', reason: 'thumbnail without a size suffix' };
        const originalFolders = folders.filter((f) => !THUMB_FOLDERS.has(f.toLowerCase()));
        const originalKey = [...originalFolders, base.replace(RESIZED_SUFFIX, '')].join('/');
        return { kind: 'thumb', albumId: parentId, fileName, photoId: stableId(originalKey) };
      }
      if (!isImage(fileName, contentType)) return { kind: 'ignore', reason: 'not a supported image (use JPEG, PNG or WebP)' };
      return { kind: 'photo', albumId: parentId, fileName, docId: stableId(innerKey) };
    }

    default:
      return { kind: 'ignore', reason: 'folder is not managed automatically' };
  }
}

/** Fields for a new `kirtans` document created from an upload. */
export function newKirtanFields(categoryId: string, fileName: string): Record<string, unknown> {
  const order = leadingOrder(fileName);
  return {
    title: localizedTitle(prettyTitle(fileName)),
    categoryId,
    ...(order !== null ? { order } : {}),
    isActive: true,
  };
}

/** Fields for a new `books` document created from an upload. */
export function newBookFields(categoryId: string, fileName: string): Record<string, unknown> {
  const order = leadingOrder(fileName);
  return {
    title: localizedTitle(prettyTitle(fileName)),
    categoryId,
    language: DEFAULT_BOOK_LANGUAGE,
    ...(order !== null ? { order } : {}),
    isActive: true,
  };
}

/** Fields for a new album created because photos were uploaded to it. */
export function newAlbumFields(albumId: string): Record<string, unknown> {
  return { title: localizedTitle(humanize(albumId) || albumId), isActive: true };
}

// ---------------------------------------------------------------------------
// Donation request e-mail
// ---------------------------------------------------------------------------

const EMAIL_PATTERN = /^[^\s@,;<>]+@[^\s@,;<>]+\.[^\s@,;<>]+$/u;

/** Accepts one address, a comma/semicolon separated list, or an array. */
export function parseEmails(value: unknown): string[] {
  const raw: unknown[] = Array.isArray(value) ? value : [value];
  const emails = raw
    .filter((v): v is string => typeof v === 'string')
    .flatMap((v) => v.split(/[\s,;]+/u))
    .map((v) => v.trim())
    .filter((v) => EMAIL_PATTERN.test(v));
  return [...new Set(emails.map((e) => e.toLowerCase()))].slice(0, 10);
}

export function escapeHtml(text: string): string {
  return text
    .replace(/&/gu, '&amp;')
    .replace(/</gu, '&lt;')
    .replace(/>/gu, '&gt;')
    .replace(/"/gu, '&quot;')
    .replace(/'/gu, '&#39;');
}

const METHOD_LABELS: Record<string, string> = {
  upi: 'UPI',
  bank: 'Bank transfer',
  cash: 'Cash',
  cheque: 'Cheque',
  other: 'Other',
};

const LANGUAGE_LABELS: Record<string, string> = {
  en: 'English',
  gu: 'Gujarati',
  hi: 'Hindi',
};

/** "₹1,25,000" (Indian digit grouping). */
export function formatRupees(amount: number): string {
  const formatted = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 2 }).format(amount);
  return `₹${formatted}`;
}

export interface DonationEmail {
  subject: string;
  text: string;
  html: string;
  replyTo: string | null;
}

/**
 * Summary e-mail for temple staff about a new "I have donated" form, in the
 * format of the "Trigger Email from Firestore" extension. All user input is
 * HTML-escaped.
 */
export function buildDonationEmail(
  request: unknown,
  requestId: string,
  options: { projectId?: string | null; submittedAt?: Date | null } = {},
): DonationEmail {
  const r = isRecord(request) ? request : {};
  const field = (key: string, max = 1000): string | null => {
    const v = asString(r[key]);
    return v === null ? null : truncate(v, max);
  };
  const name = field('name', 80) ?? 'A devotee';
  const amount = asNumber(r['amount']);
  const method = field('method', 20);
  const language = field('language', 5);

  const rows: Array<[string, string | null]> = [
    ['Name', name],
    ['Phone', field('phone', 20)],
    ['Email', field('email', 254)],
    ['Amount', amount !== null && amount > 0 ? formatRupees(amount) : null],
    ['Purpose', field('purpose', 200)],
    ['Paid by', method ? (METHOD_LABELS[method.toLowerCase()] ?? method) : null],
    ['Transaction ref.', field('transactionRef', 120)],
    ['Message', field('message', 1000)],
    ['App language', language ? (LANGUAGE_LABELS[language.toLowerCase()] ?? language) : null],
    ['Device', [field('platform', 20), field('appVersion', 40)].filter(Boolean).join(' · ') || null],
    [
      'Submitted',
      options.submittedAt
        ? options.submittedAt.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', dateStyle: 'medium', timeStyle: 'short' })
        : null,
    ],
  ];
  const present = rows.filter((row): row is [string, string] => row[1] !== null && row[1] !== '');

  const subjectName = collapseWhitespace(name);
  const subject = amount !== null && amount > 0
    ? `New donation details: ${subjectName} (${formatRupees(amount)})`
    : `New donation details: ${subjectName}`;

  const consoleUrl = donationConsoleUrl(options.projectId, requestId);

  const text = [
    'A devotee shared donation details in the Jetalpur Dham app.',
    '',
    ...present.map(([label, value]) => `${label}: ${value}`),
    '',
    `Request id: ${requestId}`,
    ...(consoleUrl ? [`Open in Firebase console: ${consoleUrl}`] : []),
    '',
    'Please verify the payment in the temple account and contact the devotee to send a receipt.',
  ].join('\n');

  const tableRows = present
    .map(
      ([label, value]) =>
        `<tr><td style="padding:6px 12px 6px 0;color:#57534e;vertical-align:top;white-space:nowrap">${escapeHtml(label)}</td>` +
        `<td style="padding:6px 0;color:#1c1917;white-space:pre-wrap">${escapeHtml(value)}</td></tr>`,
    )
    .join('');
  const html =
    '<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.5;color:#1c1917">' +
    '<h2 style="color:#C2410C;margin:0 0 12px">New donation details</h2>' +
    '<p style="margin:0 0 12px">A devotee shared donation details in the Jetalpur Dham app.</p>' +
    `<table style="border-collapse:collapse">${tableRows}</table>` +
    `<p style="margin:16px 0 0;color:#57534e">Request id: ${escapeHtml(requestId)}` +
    (consoleUrl ? ` · <a href="${escapeHtml(consoleUrl)}">Open in Firebase console</a>` : '') +
    '</p>' +
    '<p style="margin:12px 0 0">Please verify the payment in the temple account and contact the devotee to send a receipt.</p>' +
    '</div>';

  const email = field('email', 254);
  const replyTo = email && EMAIL_PATTERN.test(email) ? email : null;
  return { subject: subject.replace(/[\r\n]+/gu, ' '), text, html, replyTo };
}

/** Firebase console page of the donation_requests list, or of one request. */
export function donationConsoleUrl(projectId: string | null | undefined, requestId?: string): string | null {
  if (!projectId) return null;
  const doc = requestId ? `~2F${encodeURIComponent(requestId)}` : '';
  return `https://console.firebase.google.com/project/${encodeURIComponent(projectId)}/firestore/databases/-default-/data/~2Fdonation_requests${doc}`;
}

/** Id of the `mail` document that carries the e-mail about one request. */
export function donationMailId(requestId: string): string {
  return `donation-${requestId}`;
}

// ---------------------------------------------------------------------------
// Donation e-mail limits (abuse protection)
// ---------------------------------------------------------------------------

export const HOUR_MS = 60 * 60 * 1000;
export const DAY_MS = 24 * HOUR_MS;

/** Recent forms, each count including the new form itself. */
export interface DonationEmailCounts {
  /** Forms from everyone in the hour up to the new form. */
  lastHour: number;
  /** Forms from everyone in the 24 hours up to the new form. */
  lastDay: number;
  /** Forms with the same phone number in those 24 hours; null when not counted. */
  samePhoneLastDay?: number | null;
}

export type DonationEmailSkipReason = 'hourly-limit' | 'daily-limit' | 'phone-limit';

export interface DonationEmailLimitValues {
  perHour: number;
  perDay: number;
  perPhonePerDay: number;
}

/**
 * Why no e-mail should be sent for a new donation form, or null to send it.
 * The global limits come first: they protect the mail account and are checked
 * before the (more expensive) per-phone count.
 */
export function donationEmailSkipReason(
  counts: DonationEmailCounts,
  limits: DonationEmailLimitValues = DonationEmailLimits,
): DonationEmailSkipReason | null {
  if (counts.lastHour > limits.perHour) return 'hourly-limit';
  if (counts.lastDay > limits.perDay) return 'daily-limit';
  const samePhone = counts.samePhoneLastDay;
  if (samePhone !== null && samePhone !== undefined && samePhone > limits.perPhonePerDay) return 'phone-limit';
  return null;
}

/** Phone number without spaces, dashes, dots or brackets, or null. */
export function compactPhone(value: unknown): string | null {
  const phone = asString(value)?.replace(/[\s\-().]/gu, '') ?? '';
  return phone === '' ? null : phone;
}

/** How many of [phones] are the same number as [phone] (ignoring formatting). */
export function samePhoneCount(phones: readonly unknown[], phone: unknown): number {
  const target = compactPhone(phone);
  if (target === null) return 0;
  return phones.filter((p) => compactPhone(p) === target).length;
}

/** "2026-10-12": the calendar date in India of [date]. */
export function indiaDateKey(date: Date): string {
  // Built from the parts, so it never depends on a locale's date pattern.
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const part = (type: Intl.DateTimeFormatPartTypes) => parts.find((p) => p.type === type)?.value ?? '';
  return `${part('year')}-${part('month')}-${part('day')}`;
}

/**
 * One "e-mails paused" notice per day at most:
 * `paused-donation-emails-2026-10-12`. It must not start with `donation-`:
 * devotees' forms may carry any document id, so `donation-<requestId>` can be
 * any id with that prefix, and a form with the id `paused-…` would otherwise
 * take (or, when deleted, remove) the day's notice.
 */
export function donationPausedMailId(date: Date): string {
  return `paused-donation-emails-${indiaDateKey(date)}`;
}

/**
 * Notice for staff that per-form e-mails were paused because too many forms
 * arrived, so they know to check the console instead of their inbox.
 */
export function buildDonationPausedEmail(
  reason: Exclude<DonationEmailSkipReason, 'phone-limit'>,
  counts: DonationEmailCounts,
  options: { projectId?: string | null; limits?: DonationEmailLimitValues } = {},
): { subject: string; text: string; html: string } {
  const limits = options.limits ?? DonationEmailLimits;
  const detail = reason === 'hourly-limit'
    ? `${counts.lastHour} forms in the last hour`
    : `${counts.lastDay} forms in the last 24 hours`;
  const consoleUrl = donationConsoleUrl(options.projectId);
  const paragraphs = [
    `Many donation forms arrived in the Jetalpur Dham app in a short time (${detail}). ` +
      "To protect the temple's e-mail account, the app has stopped sending an e-mail for each new form for now.",
    'No form is lost: every form is saved in Firestore under donation_requests. ' +
      'Please check the list there (sort by createdAt, newest first).',
    `E-mails start again by themselves when fewer forms arrive (at most ${limits.perHour} an hour and ` +
      `${limits.perDay} a day). You get this notice at most once a day.`,
    'If you did not expect this many forms, someone may be sending fake forms. ' +
      'Please tell the app developer (Firebase App Check stops this).',
  ];
  const text = [
    ...paragraphs.flatMap((p) => [p, '']),
    ...(consoleUrl ? [`Open in Firebase console: ${consoleUrl}`] : []),
  ].join('\n').trimEnd();
  const html =
    '<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.5;color:#1c1917">' +
    '<h2 style="color:#C2410C;margin:0 0 12px">Donation e-mails paused</h2>' +
    paragraphs.map((p) => `<p style="margin:0 0 12px">${escapeHtml(p)}</p>`).join('') +
    (consoleUrl ? `<p style="margin:0"><a href="${escapeHtml(consoleUrl)}">Open donation_requests in the Firebase console</a></p>` : '') +
    '</div>';
  return { subject: 'Jetalpur Dham app: donation e-mails paused (many forms received)', text, html };
}

// ---------------------------------------------------------------------------
// Donation request retention
// ---------------------------------------------------------------------------

/**
 * Months to keep donation forms: a whole number in
 * [DonationRetention.minMonths, DonationRetention.maxMonths] read from
 * [value] (the DONATION_RETENTION_MONTHS environment variable), else the
 * default (12). Never returns 0, so a typo can never delete everything.
 */
export function retentionMonths(value: unknown): number {
  const months = asNumber(value);
  if (months === null || !Number.isInteger(months)) return DonationRetention.defaultMonths;
  if (months < DonationRetention.minMonths || months > DonationRetention.maxMonths) return DonationRetention.defaultMonths;
  return months;
}

/**
 * The moment [months] calendar months before [now] (UTC); forms created
 * before it are deleted. The day is clamped to the end of a shorter month:
 * 31 March − 1 month = 28/29 February.
 */
export function retentionCutoff(now: Date, months: number): Date {
  if (!Number.isInteger(months) || months < 1) throw new RangeError(`Invalid retention months: ${months}`);
  if (Number.isNaN(now.getTime())) throw new RangeError('Invalid date');
  const firstOfMonth = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth() - months,
    1,
    now.getUTCHours(),
    now.getUTCMinutes(),
    now.getUTCSeconds(),
    now.getUTCMilliseconds(),
  ));
  const daysInMonth = new Date(Date.UTC(firstOfMonth.getUTCFullYear(), firstOfMonth.getUTCMonth() + 1, 0)).getUTCDate();
  firstOfMonth.setUTCDate(Math.min(now.getUTCDate(), daysInMonth));
  return firstOfMonth;
}
