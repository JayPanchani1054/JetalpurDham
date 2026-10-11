import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/models/localized_text.dart';
import 'package:jetalpur_dham/features/events/data/events_repository.dart';
import 'package:jetalpur_dham/features/events/domain/temple_event.dart';

void main() {
  group('EventType.parse', () {
    test('accepts known values case-insensitively', () {
      expect(EventType.parse('utsav'), EventType.utsav);
      expect(EventType.parse(' Katha '), EventType.katha);
      expect(EventType.parse('ANNOUNCEMENT'), EventType.announcement);
      expect(EventType.parse('other'), EventType.other);
    });

    test('unknown, missing or wrong-typed values become other', () {
      expect(EventType.parse('festival'), EventType.other);
      expect(EventType.parse(null), EventType.other);
      expect(EventType.parse(42), EventType.other);
    });
  });

  group('TempleEvent.fromMap', () {
    test('parses a complete document', () {
      final DateTime start = DateTime(2026, 10, 20, 18, 30);
      final DateTime end = DateTime(2026, 10, 22, 21);
      final TempleEvent event = TempleEvent.fromMap('e1', <String, Object?>{
        'title': <String, Object?>{'en': 'Annakut', 'gu': 'અન્નકૂટ'},
        'shortDescription': 'Grand annakut darshan',
        'description': <String, Object?>{'en': 'Long text'},
        'location': 'Sabha Mandap',
        'bannerUrl': 'events/annakut.jpg',
        'startAt': Timestamp.fromDate(start),
        'endAt': Timestamp.fromDate(end),
        'type': 'utsav',
        'albumId': 'avsar-200',
        'liveUrl': 'https://youtube.com/live/abc',
        'isActive': true,
        'sendNotification': true,
      });
      expect(event.id, 'e1');
      expect(event.title.resolve('gu'), 'અન્નકૂટ');
      expect(event.shortDescription.resolve('hi'), 'Grand annakut darshan');
      expect(event.location.resolve('en'), 'Sabha Mandap');
      expect(event.bannerUrl, 'events/annakut.jpg');
      expect(event.startAt, start);
      expect(event.endAt, end);
      expect(event.type, EventType.utsav);
      expect(event.albumId, 'avsar-200');
      expect(event.liveUrl, 'https://youtube.com/live/abc');
      expect(event.isActive, isTrue);
      expect(event.isMultiDay, isTrue);
      expect(event.lastMoment, end);
      expect(event.body.resolve('en'), 'Long text');
    });

    test('tolerates an empty document', () {
      final TempleEvent event = TempleEvent.fromMap('lonely', const {});
      expect(event.title.isEmpty, isTrue);
      expect(event.titleIn('en'), 'lonely');
      expect(event.startAt, isNull);
      expect(event.endAt, isNull);
      expect(event.lastMoment, isNull);
      expect(event.type, EventType.other);
      expect(event.isActive, isTrue, reason: 'missing isActive means active');
      expect(event.bannerUrl, isNull);
      expect(event.albumId, isNull);
      expect(event.liveUrl, isNull);
      expect(event.isMultiDay, isFalse);
    });

    test('tolerates wrong field types', () {
      final TempleEvent event = TempleEvent.fromMap('w', <String, Object?>{
        'title': 12,
        'startAt': 'not a date',
        'endAt': <String>['x'],
        'type': true,
        'albumId': '   ',
        'liveUrl': 99,
        'isActive': 'false',
        'bannerUrl': <String, Object?>{},
      });
      expect(event.titleIn('en'), 'w');
      expect(event.startAt, isNull);
      expect(event.endAt, isNull);
      expect(event.type, EventType.other);
      expect(event.albumId, isNull);
      expect(event.liveUrl, isNull);
      expect(event.isActive, isFalse);
      expect(event.bannerUrl, isNull);
    });

    test('accepts ISO strings and epoch millis for dates', () {
      final TempleEvent iso = TempleEvent.fromMap('i', <String, Object?>{
        'startAt': '2026-11-01T07:00:00',
      });
      expect(iso.startAt, DateTime(2026, 11, 1, 7));

      final DateTime when = DateTime(2026, 12, 25, 9);
      final TempleEvent millis = TempleEvent.fromMap('m', <String, Object?>{
        'startAt': when.millisecondsSinceEpoch,
      });
      expect(millis.startAt, when);
    });

    test('ignores an end before the start', () {
      final TempleEvent event = TempleEvent.fromMap('x', <String, Object?>{
        'startAt': Timestamp.fromDate(DateTime(2026, 10, 20)),
        'endAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
      });
      expect(event.startAt, DateTime(2026, 10, 20));
      expect(event.endAt, isNull);
    });

    test('uses endAt as the start when startAt is missing', () {
      final TempleEvent event = TempleEvent.fromMap('x', <String, Object?>{
        'endAt': Timestamp.fromDate(DateTime(2026, 10, 20)),
      });
      expect(event.startAt, DateTime(2026, 10, 20));
      expect(event.endAt, isNull);
      expect(event.isMultiDay, isFalse);
    });

    test('same-day end is not multi-day', () {
      final TempleEvent event = TempleEvent.fromMap('x', <String, Object?>{
        'startAt': Timestamp.fromDate(DateTime(2026, 10, 20, 9)),
        'endAt': Timestamp.fromDate(DateTime(2026, 10, 20, 21)),
      });
      expect(event.isMultiDay, isFalse);
    });

    test('normalises live links', () {
      String? live(Object? value) =>
          TempleEvent.fromMap('x', <String, Object?>{'liveUrl': value}).liveUrl;
      expect(live('https://youtu.be/x'), 'https://youtu.be/x');
      expect(live('http://example.org/live'), 'http://example.org/live');
      expect(live('youtube.com/live/abc'), 'https://youtube.com/live/abc');
      expect(live('javascript:alert(1)'), isNull);
      expect(live('not a link'), isNull);
      expect(live(''), isNull);
    });

    test('body falls back to the short description', () {
      final TempleEvent event = TempleEvent.fromMap('x', <String, Object?>{
        'shortDescription': 'Short',
      });
      expect(event.body.resolve('en'), 'Short');
    });

    test('equality compares every field', () {
      final Map<String, Object?> data = <String, Object?>{
        'title': 'Sabha',
        'startAt': Timestamp.fromDate(DateTime(2026, 10, 20)),
        'type': 'katha',
      };
      expect(TempleEvent.fromMap('a', data), TempleEvent.fromMap('a', data));
      expect(
        TempleEvent.fromMap('a', data).hashCode,
        TempleEvent.fromMap('a', data).hashCode,
      );
      expect(
        TempleEvent.fromMap('a', data),
        isNot(
          TempleEvent.fromMap('a', <String, Object?>{...data, 'type': 'utsav'}),
        ),
      );
      expect(
        TempleEvent.fromMap('a', data),
        isNot(TempleEvent.fromMap('b', data)),
      );
    });
  });

  group('parseEventDocuments', () {
    test('keeps active events, including ones without isActive', () {
      final List<TempleEvent> events = parseEventDocuments(
        <MapEntry<String, Map<String, Object?>>>[
          const MapEntry<String, Map<String, Object?>>('a', <String, Object?>{
            'title': 'A',
          }),
          const MapEntry<String, Map<String, Object?>>('b', <String, Object?>{
            'title': 'B',
            'isActive': false,
          }),
          const MapEntry<String, Map<String, Object?>>('c', <String, Object?>{
            'title': 'C',
            'isActive': true,
          }),
        ],
      );
      expect(events.map((TempleEvent e) => e.id), <String>['a', 'c']);
      expect(
        events.first.title,
        const LocalizedText(<String, String>{'*': 'A'}),
      );
    });
  });

  group('EventLookup', () {
    test('a cache miss is "unavailable offline", not "not found"', () {
      expect(
        const EventLookup(null, isFromCache: true).isUnavailableOffline,
        isTrue,
      );
      expect(const EventLookup(null).isUnavailableOffline, isFalse);
      final TempleEvent event = TempleEvent.fromMap('x', const {});
      expect(
        EventLookup(event, isFromCache: true).isUnavailableOffline,
        isFalse,
      );
      expect(EventLookup(event), EventLookup(event));
    });
  });
}
