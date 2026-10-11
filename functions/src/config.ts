/**
 * Shared settings for every Cloud Function. Keep these in step with
 * docs/DATA_MODEL.md and the Flutter app (lib/core/**).
 */

/**
 * Region for every function: Mumbai, the closest Google Cloud region to
 * Gujarat.
 *
 * IMPORTANT: Firestore- and Storage-triggered functions must run in the same
 * location as the database / bucket that fires them. Create the Firestore
 * database and the Storage bucket in `asia-south1` (see
 * docs/FIREBASE_SETUP.md). If your bucket or database lives elsewhere, change
 * this value to that location before deploying.
 */
export const REGION = 'asia-south1';

/** Firestore collection names (mirror of FirestorePaths in the app). */
export const Collections = {
  config: 'config',
  kirtans: 'kirtans',
  albums: 'albums',
  photos: 'photos',
  books: 'books',
  events: 'events',
  notifications: 'notifications',
  donationRequests: 'donation_requests',
  /** Read by the official "Trigger Email from Firestore" extension. */
  mail: 'mail',
} as const;

/** Top-level Storage folders that create Firestore documents automatically. */
export const StorageFolders = {
  kirtans: 'kirtans',
  gallery: 'gallery',
  books: 'books',
} as const;

/** Push notification settings shared with the app. */
export const Push = {
  /** Each device subscribes to exactly one of these topics: lang_<code>. */
  topicPrefix: 'lang_',
  /** Android notification channel created by the app. */
  androidChannelId: 'utsav_updates',
  /** Saffron brand colour (AppColors.primary). */
  color: '#C2410C',
  /** android/app/src/main/res/drawable/ic_notification.xml */
  androidIcon: 'ic_notification',
} as const;

/** Default language of PDFs uploaded to books/ (most shastras are Gujarati). */
export const DEFAULT_BOOK_LANGUAGE = 'gu';
