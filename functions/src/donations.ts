/**
 * Donation forms — the "I have donated / contact me" form in the app.
 *
 *  * onDonationRequestCreate  – e-mails staff about a new form (within limits)
 *  * onDonationRequestDelete  – deletes the e-mail copy when a form is deleted
 *  * purgeOldDonationRequests – every night deletes forms older than the
 *                               retention period of the privacy policy
 *
 * When `config/donation.notifyEmail` holds one or more addresses, a document
 * is written to the `mail` collection in the format of the official
 * "Trigger Email from Firestore" extension, which sends the e-mail. Without
 * an address (or without the extension) the request is only logged; staff can
 * always see every request in the console under `donation_requests`.
 */
import { Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/logger';
import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db, errorMessage, isAlreadyExists, projectId } from './admin';
import { Collections, DonationEmailLimits, DonationRetention, REGION } from './config';
import {
  buildDonationEmail,
  buildDonationPausedEmail,
  DAY_MS,
  type DonationEmailCounts,
  type DonationEmailSkipReason,
  donationEmailSkipReason,
  donationMailId,
  donationPausedMailId,
  HOUR_MS,
  parseEmails,
  retentionCutoff,
  retentionMonths,
  samePhoneCount,
} from './util';

/**
 * Abuse protection. The security rules let anyone create a strictly validated
 * form without signing in (devotees do not have accounts), so a script could
 * create thousands of forms, and each would e-mail the office through the
 * temple's mail account. Above DonationEmailLimits the form is still saved but
 * no e-mail is queued; staff get at most one "e-mails paused" notice a day.
 *
 * This only protects the inbox and the mail account. The real fix is Firebase
 * App Check enforced for Cloud Firestore (Play Integrity on Android, App Attest
 * on iPhone), which rejects forms that do not come from the genuine app — turn
 * it on before the public launch.
 */
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
      const submittedAt = createdAt instanceof Timestamp ? createdAt : Timestamp.fromDate(eventDate(event.time));
      const counts = await recentDonationCounts(submittedAt, request['phone']);
      const skip = counts ? donationEmailSkipReason(counts) : null;
      if (counts && skip) {
        logger.warn('Donation e-mail skipped: too many forms (the request is saved)', { requestId, reason: skip, ...counts });
        if (skip !== 'phone-limit') await queuePausedNotice(to, skip, counts, submittedAt.toDate());
        return;
      }

      const email = buildDonationEmail(request, requestId, {
        projectId: projectId(),
        submittedAt: submittedAt.toDate(),
      });
      // Deterministic id: a duplicate trigger delivery can never send twice.
      await db()
        .collection(Collections.mail)
        .doc(donationMailId(requestId))
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

/**
 * Counts the forms submitted up to [until] (the new form's createdAt, so the
 * counts include it). Uses only Firestore's automatic single-field indexes:
 * two count() range queries on `createdAt` (cheap even during a flood) and,
 * only when both are under the limit, one read of the phone numbers of at most
 * `perDay` recent forms. Filtering on phone and createdAt in one query would
 * need a composite index, so phone numbers are compared here instead.
 *
 * Returns null — and the e-mail is sent — when counting fails.
 */
async function recentDonationCounts(until: Timestamp, phone: unknown): Promise<DonationEmailCounts | null> {
  try {
    const requests = db().collection(Collections.donationRequests);
    const within = (ms: number) =>
      requests
        .where('createdAt', '>', Timestamp.fromMillis(until.toMillis() - ms))
        .where('createdAt', '<=', until);
    const [hour, day] = await Promise.all([within(HOUR_MS).count().get(), within(DAY_MS).count().get()]);
    const counts: DonationEmailCounts = { lastHour: hour.data().count, lastDay: day.data().count };
    if (donationEmailSkipReason(counts) !== null) return counts;

    const recent = await within(DAY_MS).select('phone').limit(DonationEmailLimits.perDay + 1).get();
    return { ...counts, samePhoneLastDay: samePhoneCount(recent.docs.map((doc) => doc.get('phone')), phone) };
  } catch (error) {
    logger.error('Could not count recent donation forms; sending the e-mail anyway', { error: errorMessage(error) });
    return null;
  }
}

/** Tells staff (at most once a day) that per-form e-mails are paused. */
async function queuePausedNotice(
  to: string[],
  reason: Exclude<DonationEmailSkipReason, 'phone-limit'>,
  counts: DonationEmailCounts,
  at: Date,
): Promise<void> {
  const email = buildDonationPausedEmail(reason, counts, { projectId: projectId() });
  try {
    await db().collection(Collections.mail).doc(donationPausedMailId(at)).create({ to, message: email });
    logger.warn('Donation e-mails paused; notice queued', { reason });
  } catch (error) {
    if (!isAlreadyExists(error)) throw error;
  }
}

function eventDate(time: string | undefined): Date {
  const ms = time ? Date.parse(time) : Number.NaN;
  return Number.isFinite(ms) ? new Date(ms) : new Date();
}

/**
 * The e-mail document holds a copy of the devotee's details, so it goes when
 * the form goes — when staff delete a form on a devotee's request, and when
 * purgeOldDonationRequests deletes old forms. Deleting is idempotent, so the
 * trigger is retried on failure.
 */
export const onDonationRequestDelete = onDocumentDeleted(
  { document: `${Collections.donationRequests}/{requestId}`, region: REGION, retry: true },
  async (event) => {
    const requestId = event.params.requestId;
    try {
      await db().collection(Collections.mail).doc(donationMailId(requestId)).delete();
    } catch (error) {
      logger.error('Could not delete the e-mail copy of a deleted donation request', { requestId, error: errorMessage(error) });
      throw error;
    }
  },
);

/**
 * Every night deletes `donation_requests` submitted more than
 * DONATION_RETENTION_MONTHS (default 12) months ago, together with their
 * `mail/donation-<id>` copies. Forms are always deleted after they were
 * submitted, so this keeps the privacy policy's promise of deletion "within
 * [12] months after the receipt is issued".
 *
 * Safe by design: at most DonationRetention.maxDeletesPerRun forms per run, in
 * batches; the rest wait for the next night. Forms without `createdAt`
 * (typed in by hand) are never touched.
 */
export const purgeOldDonationRequests = onSchedule(
  {
    schedule: DonationRetention.schedule,
    timeZone: DonationRetention.timeZone,
    region: REGION,
    timeoutSeconds: 300,
  },
  async () => {
    const months = retentionMonths(process.env[DonationRetention.envVar]);
    const cutoff = retentionCutoff(new Date(), months);
    const old = db()
      .collection(Collections.donationRequests)
      .where('createdAt', '<', Timestamp.fromDate(cutoff))
      .orderBy('createdAt');
    let deleted = 0;
    let more = false;
    try {
      while (deleted < DonationRetention.maxDeletesPerRun) {
        const limit = Math.min(DonationRetention.batchSize, DonationRetention.maxDeletesPerRun - deleted);
        const snapshot = await old.select().limit(limit).get();
        if (snapshot.empty) break;
        const batch = db().batch();
        for (const doc of snapshot.docs) {
          batch.delete(doc.ref);
          batch.delete(db().collection(Collections.mail).doc(donationMailId(doc.id)));
        }
        await batch.commit();
        deleted += snapshot.size;
        more = snapshot.size === limit;
        if (!more) break;
      }
    } catch (error) {
      logger.error('Could not delete old donation requests', { deleted, months, error: errorMessage(error) });
      throw error;
    }
    logger.info('Old donation requests deleted', {
      deleted,
      months,
      cutoff: cutoff.toISOString(),
      ...(more ? { note: 'more may remain; they are deleted on the next run' } : {}),
    });
  },
);
