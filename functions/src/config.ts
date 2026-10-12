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

/**
 * Limits on the staff e-mail sent for each new `donation_requests` form.
 *
 * Anyone can create a (strictly validated) form without signing in, and each
 * one sends an e-mail through the temple's mail account (Gmail allows about
 * 500 a day). Above these limits the form is still saved — staff see it in the
 * console — but no e-mail is sent. Every count includes the new form itself,
 * so the e-mail is skipped from the (limit + 1)-th form on.
 *
 * These limits only protect the inbox. The real protection against scripted
 * forms is Firebase App Check enforced for Cloud Firestore (see
 * onDonationRequestCreate).
 */
export const DonationEmailLimits = {
  /** Forms from everyone in the last hour. */
  perHour: 30,
  /** Forms from everyone in the last 24 hours (well under Gmail's daily cap). */
  perDay: 150,
  /** Forms with the same phone number in the last 24 hours. */
  perPhonePerDay: 5,
} as const;

/**
 * Automatic deletion of old `donation_requests` (and their `mail` copies), as
 * promised in docs/PRIVACY_POLICY.md ("deleted ... within [12] months").
 */
export const DonationRetention = {
  /**
   * Months a form is kept after it was submitted. Override it by putting
   * `DONATION_RETENTION_MONTHS=18` (for example) in `functions/.env` and
   * deploying again; keep it equal to the number in the privacy policy.
   */
  defaultMonths: 12,
  /** Environment variable read by purgeOldDonationRequests. */
  envVar: 'DONATION_RETENTION_MONTHS',
  /** Values outside this range are ignored (the default is used instead). */
  minMonths: 1,
  maxMonths: 120,
  /** Every day at 03:30 India time, when nobody is working in the console. */
  schedule: '30 3 * * *',
  timeZone: 'Asia/Kolkata',
  /** Forms deleted per batch; each also deletes its mail copy (2 writes, < 500). */
  batchSize: 200,
  /** Upper bound per daily run; anything left over is deleted the next day. */
  maxDeletesPerRun: 2000,
} as const;
