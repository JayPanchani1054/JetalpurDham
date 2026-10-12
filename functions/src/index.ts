/**
 * Cloud Functions for the Jetalpur Dham app.
 *
 * The temple runs everything from the Firebase console; these functions do
 * the busy work:
 *  * onEventWrite            – announces an utsav/katha to every devotee once
 *                              (`sendNotification: true` on an events doc)
 *  * onNotificationCreate    – sends an ad-hoc message added to `notifications`
 *  * onStorageUpload         – turns uploaded kirtans, photos and PDFs into
 *                              app content
 *  * onStorageDelete         – removes that content when the file is deleted
 *  * onDonationRequestCreate – e-mails staff about a new donation form
 *                              (rate-limited against floods)
 *  * onDonationRequestDelete – deletes the e-mail copy of a deleted form
 *  * purgeOldDonationRequests – nightly: deletes donation forms older than
 *                              the privacy policy's retention (12 months)
 *
 * See docs/FIREBASE_SETUP.md (deploying) and docs/ADMIN_GUIDE.md (daily use).
 */
import { setGlobalOptions } from 'firebase-functions/v2';

import { REGION } from './config';

setGlobalOptions({
  region: REGION,
  // Plenty for a temple app and caps the bill if something goes wrong.
  maxInstances: 10,
  memory: '256MiB',
  timeoutSeconds: 120,
});

export { onDonationRequestCreate, onDonationRequestDelete, purgeOldDonationRequests } from './donations';
export { onEventWrite, onNotificationCreate } from './notifications';
export { onStorageDelete, onStorageUpload } from './storage';
