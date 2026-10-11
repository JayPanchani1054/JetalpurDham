/**
 * Alerts temple staff when a devotee submits the "I have donated / contact me"
 * form in the app.
 *
 * When `config/donation.notifyEmail` holds one or more addresses, a document
 * is written to the `mail` collection in the format of the official
 * "Trigger Email from Firestore" extension, which sends the e-mail. Without
 * an address (or without the extension) the request is only logged; staff can
 * always see every request in the console under `donation_requests`.
 */
import { Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/logger';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { db, errorMessage, isAlreadyExists, projectId } from './admin';
import { Collections, REGION } from './config';
import { buildDonationEmail, parseEmails } from './util';

export const onDonationRequestCreate = onDocumentCreated(
  { document: `${Collections.donationRequests}/{requestId}`, region: REGION, retry: false },
  async (event) => {
    const requestId = event.params.requestId;
    try {
      const request = event.data?.data();
      if (!request) return;

      const config = await db().collection(Collections.config).doc('donation').get();
      const to = parseEmails(config.get('notifyEmail'));
      if (to.length === 0) {
        logger.info('New donation request (set config/donation.notifyEmail to get e-mails)', { requestId });
        return;
      }

      const createdAt = request['createdAt'];
      const email = buildDonationEmail(request, requestId, {
        projectId: projectId(),
        submittedAt: createdAt instanceof Timestamp ? createdAt.toDate() : new Date(),
      });
      // Deterministic id: a duplicate trigger delivery can never send twice.
      await db()
        .collection(Collections.mail)
        .doc(`donation-${requestId}`)
        .create({
          to,
          ...(email.replyTo ? { replyTo: email.replyTo } : {}),
          message: { subject: email.subject, text: email.text, html: email.html },
        });
      logger.info('Donation e-mail queued', { requestId, recipients: to.length });
    } catch (error) {
      if (isAlreadyExists(error)) return;
      // Never throw: the devotee's request is already safely stored.
      logger.error('Could not queue donation e-mail', { requestId, error: errorMessage(error) });
    }
  },
);
