import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/event_schedule.dart';
import '../domain/temple_event.dart';

/// Every active event, live from Firestore (served from the offline cache
/// without internet). No server-side ordering or filtering, so a missing
/// field can never hide an event and no composite index is needed.
final StreamProvider<List<TempleEvent>> eventsProvider =
    StreamProvider<List<TempleEvent>>((Ref ref) {
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.events)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                parseEventDocuments(
                  snapshot.docs.map(
                    (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                        MapEntry<String, Map<String, Object?>>(
                          doc.id,
                          doc.data(),
                        ),
                  ),
                ),
          );
    });

/// Parses `id → data` documents, skipping inactive and malformed ones.
List<TempleEvent> parseEventDocuments(
  Iterable<MapEntry<String, Map<String, Object?>>> documents,
) {
  final List<TempleEvent> events = <TempleEvent>[];
  for (final MapEntry<String, Map<String, Object?>> doc in documents) {
    try {
      final TempleEvent event = TempleEvent.fromMap(doc.key, doc.value);
      if (event.isActive) events.add(event);
    } catch (error, stack) {
      // One malformed document must never hide the rest of the list.
      AppLogger.error('Skipping malformed event ${doc.key}', error, stack);
    }
  }
  return events;
}

/// Today's calendar date. Refreshes itself just after midnight so the
/// Upcoming/Past split and "Today"/"Tomorrow" labels stay correct while the
/// app is left open.
final NotifierProvider<EventsToday, DateTime> eventsTodayProvider =
    NotifierProvider<EventsToday, DateTime>(EventsToday.new);

class EventsToday extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    final DateTime now = DateTime.now();
    _scheduleNextDay(now);
    return dateOnly(now);
  }

  void _scheduleNextDay(DateTime now) {
    _timer?.cancel();
    final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 2),
      () {
        final DateTime later = DateTime.now();
        state = dateOnly(later);
        _scheduleNextDay(later);
      },
    );
  }
}

/// Upcoming events (`endAt ?? startAt` is today or later), soonest first.
final Provider<AsyncValue<List<TempleEvent>>> upcomingEventsProvider =
    Provider<AsyncValue<List<TempleEvent>>>((Ref ref) {
      final DateTime today = ref.watch(eventsTodayProvider);
      return ref
          .watch(eventsProvider)
          .whenData((List<TempleEvent> all) => upcomingEvents(all, today));
    });

/// Past events, newest first.
final Provider<AsyncValue<List<TempleEvent>>> pastEventsProvider =
    Provider<AsyncValue<List<TempleEvent>>>((Ref ref) {
      final DateTime today = ref.watch(eventsTodayProvider);
      return ref
          .watch(eventsProvider)
          .whenData((List<TempleEvent> all) => pastEvents(all, today));
    });

/// Result of looking up one event by id.
@immutable
class EventLookup {
  const EventLookup(this.event, {this.isFromCache = false});

  /// The event, or null when it does not exist or is hidden (`isActive`).
  final TempleEvent? event;

  /// True when the answer came from the offline cache only. A missing event
  /// from the cache is "unknown" (offline), not "deleted".
  final bool isFromCache;

  bool get isUnavailableOffline => event == null && isFromCache;

  @override
  bool operator ==(Object other) =>
      other is EventLookup &&
      other.event == event &&
      other.isFromCache == isFromCache;

  @override
  int get hashCode => Object.hash(event, isFromCache);
}

/// One event by id, live. Works on its own (e.g. when a notification opens
/// `/events/<id>` directly) without the list ever being loaded.
final StreamProviderFamily<EventLookup, String> eventLookupProvider =
    StreamProvider.autoDispose.family<EventLookup, String>((
      Ref ref,
      String id,
    ) {
      final String docId = id.trim();
      // A Firestore document id can never contain '/'.
      if (docId.isEmpty || docId.contains('/')) {
        return Stream<EventLookup>.value(const EventLookup(null));
      }
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.events)
          .doc(docId)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
            final Map<String, dynamic>? data = snapshot.data();
            if (!snapshot.exists || data == null) {
              return EventLookup(
                null,
                isFromCache: snapshot.metadata.isFromCache,
              );
            }
            final TempleEvent event = TempleEvent.fromMap(snapshot.id, data);
            return EventLookup(event.isActive ? event : null);
          });
    });
