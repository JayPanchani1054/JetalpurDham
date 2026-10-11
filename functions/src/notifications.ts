/**
 * Push notifications to all devotees, in their app language.
 *
 *  * onEventWrite: an `events` document with `sendNotification: true` is
 *    announced exactly once (`notifiedAt` is written first, in a transaction).
 *  * onNotificationCreate: any document added to `notifications` is sent as an
 *    ad-hoc message; the result is written back to the same document.
 */
import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/logger';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';

import { db, errorMessage, resolveMediaUrl, sendToAllLanguages } from './admin';
import { Collections, REGION } from './config';
import {
  asString,
  eventRoute,
  hasText,
  isNotificationPending,
  isRecord,
  NotificationStatus,
  notificationRoute,
  shouldNotifyEvent,
} from './util';

export const onEventWrite = onDocumentWritten(
  { document: `${Collections.events}/{eventId}`, region: REGION, retry: false },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    if (!shouldNotifyEvent(after.data())) return;

    const eventId = event.params.eventId;
    const ref = after.ref;
    let claimedSend = false;
    try {
      // Claim the send inside a transaction so duplicate trigger deliveries or
      // quick successive edits can never announce the same event twice.
      const claimed = await db().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const data = snap.data();
        if (!snap.exists || !shouldNotifyEvent(data)) return null;
        tx.update(ref, {
          notifiedAt: FieldValue.serverTimestamp(),
          notificationStatus: NotificationStatus.sending,
          notificationError: FieldValue.delete(),
        });
        return data ?? null;
      });
      if (!claimed) return;
      claimedSend = true;

      const imageUrl = await resolveMediaUrl(claimed['bannerUrl']);
      const summary = await sendToAllLanguages({
        title: claimed['title'],
        body: claimed['shortDescription'],
        fallbackBody: claimed['description'],
        imageUrl,
        data: { type: 'event', eventId, route: eventRoute(eventId) },
      });
      const failed = summary.failureCount > 0;
      await ref.update({
        notificationStatus: failed ? NotificationStatus.error : NotificationStatus.sent,
        notificationError: failed ? summary.errors.join('\n') : FieldValue.delete(),
      });
      logger.info('Event notification sent', { eventId, ...summary });
    } catch (error) {
      logger.error('Event notification failed', { eventId, error: errorMessage(error) });
      // Only after a successful claim: notifiedAt is set, so this write cannot
      // re-trigger a send (writing it before the claim could loop).
      if (claimedSend) {
        await ref
          .update({ notificationStatus: NotificationStatus.error, notificationError: errorMessage(error) })
          .catch(() => undefined);
      }
    }
  },
);

export const onNotificationCreate = onDocumentCreated(
  { document: `${Collections.notifications}/{notificationId}`, region: REGION, retry: false },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const ref = snapshot.ref;
    const notificationId = event.params.notificationId;

    try {
      const claimed = await db().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const data = snap.data();
        if (!snap.exists || !isNotificationPending(data)) return null;
        tx.update(ref, { status: NotificationStatus.sending });
        return data ?? null;
      });
      if (!claimed) return;

      // Fill anything left empty from the linked event (title, text, banner).
      const eventId = asString(claimed['eventId']);
      let linkedEvent: Record<string, unknown> = {};
      if (eventId) {
        const eventSnap = await db().collection(Collections.events).doc(eventId).get();
        const data = eventSnap.data();
        if (isRecord(data)) linkedEvent = data;
      }

      const title = hasText(claimed['title']) ? claimed['title'] : linkedEvent['title'];
      const body = hasText(claimed['body']) ? claimed['body'] : linkedEvent['shortDescription'];
      const imageUrl = await resolveMediaUrl(asString(claimed['imageUrl']) ?? linkedEvent['bannerUrl']);
      const route = notificationRoute(claimed['route'], eventId);
      const data: Record<string, string> = { type: eventId ? 'event' : 'general', route };
      if (eventId) data['eventId'] = eventId;

      const summary = await sendToAllLanguages({
        title,
        body,
        fallbackBody: linkedEvent['description'],
        imageUrl,
        data,
      });
      const failed = summary.failureCount > 0;
      await ref.update({
        status: failed ? NotificationStatus.error : NotificationStatus.sent,
        sentAt: failed ? null : FieldValue.serverTimestamp(),
        error: failed ? summary.errors.join('\n') : null,
        successCount: summary.successCount,
        failureCount: summary.failureCount,
        route,
      });
      logger.info('Ad-hoc notification sent', { notificationId, ...summary });
    } catch (error) {
      logger.error('Ad-hoc notification failed', { notificationId, error: errorMessage(error) });
      await ref
        .update({ status: NotificationStatus.error, sentAt: null, error: errorMessage(error) })
        .catch(() => undefined);
    }
  },
);
