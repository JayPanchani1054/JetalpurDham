import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/events/domain/event_schedule.dart';
import 'package:jetalpur_dham/features/events/domain/temple_event.dart';

TempleEvent _event(
  String id, {
  DateTime? start,
  DateTime? end,
  String? title,
  bool active = true,
}) => TempleEvent.fromMap(id, <String, Object?>{
  'title': ?title,
  'startAt': ?start,
  'endAt': ?end,
  'isActive': active,
});

void main() {
  final DateTime today = DateTime(2026, 10, 11);

  group('calendar helpers', () {
    test('dateOnly drops the time of day', () {
      expect(dateOnly(DateTime(2026, 10, 11, 23, 59)), DateTime(2026, 10, 11));
    });

    test('calendarDaysBetween counts calendar days, not 24h blocks', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 10, 11, 23, 59),
          DateTime(2026, 10, 12, 0, 1),
        ),
        1,
      );
      expect(calendarDaysBetween(today, DateTime(2026, 10, 11, 20)), 0);
      expect(calendarDaysBetween(today, DateTime(2026, 10, 2)), -9);
      // Across a month and a year boundary.
      expect(
        calendarDaysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 2)),
        2,
      );
      // Across a typical DST change date (would be off by an hour in local
      // time zones that observe DST).
      expect(
        calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)),
        2,
      );
    });

    test('hasTimeOfDay is false for midnight and null', () {
      expect(hasTimeOfDay(null), isFalse);
      expect(hasTimeOfDay(DateTime(2026, 10, 11)), isFalse);
      expect(hasTimeOfDay(DateTime(2026, 10, 11, 0, 30)), isTrue);
      expect(hasTimeOfDay(DateTime(2026, 10, 11, 19)), isTrue);
    });
  });

  group('isUpcomingEvent', () {
    test('an event earlier today is still upcoming', () {
      expect(
        isUpcomingEvent(_event('a', start: DateTime(2026, 10, 11, 6)), today),
        isTrue,
      );
    });

    test('yesterday is past', () {
      expect(
        isUpcomingEvent(_event('a', start: DateTime(2026, 10, 10, 20)), today),
        isFalse,
      );
    });

    test('a multi-day utsav ending today or later is upcoming', () {
      expect(
        isUpcomingEvent(
          _event(
            'a',
            start: DateTime(2026, 10, 5),
            end: DateTime(2026, 10, 11, 10),
          ),
          today,
        ),
        isTrue,
      );
      expect(
        isUpcomingEvent(
          _event(
            'a',
            start: DateTime(2026, 10, 5),
            end: DateTime(2026, 10, 10),
          ),
          today,
        ),
        isFalse,
      );
    });

    test('undated events never vanish: they count as upcoming', () {
      expect(isUpcomingEvent(_event('a'), today), isTrue);
    });
  });

  group('upcomingEvents / pastEvents', () {
    final List<TempleEvent> all = <TempleEvent>[
      _event('far', start: DateTime(2026, 12, 2), title: 'Far'),
      _event('past-old', start: DateTime(2025, 1, 2), title: 'Old'),
      _event('undated', title: 'Undated'),
      _event('soon', start: DateTime(2026, 10, 12), title: 'Soon'),
      _event('past-new', start: DateTime(2026, 10, 2), title: 'New'),
      _event(
        'ongoing',
        start: DateTime(2026, 10, 2),
        end: DateTime(2026, 10, 15),
        title: 'Ongoing',
      ),
      _event('hidden', start: DateTime(2026, 10, 13), active: false),
      _event('same-b', start: DateTime(2026, 11, 2), title: 'B'),
      _event('same-a', start: DateTime(2026, 11, 2), title: 'a'),
    ];

    test('upcoming is soonest first, undated last, hidden excluded', () {
      expect(upcomingEvents(all, today).map((TempleEvent e) => e.id), <String>[
        'ongoing',
        'soon',
        'same-a',
        'same-b',
        'far',
        'undated',
      ]);
    });

    test('past is newest first', () {
      expect(pastEvents(all, today).map((TempleEvent e) => e.id), <String>[
        'past-new',
        'past-old',
      ]);
    });

    test('every active event lands in exactly one list', () {
      final int total =
          upcomingEvents(all, today).length + pastEvents(all, today).length;
      expect(total, all.where((TempleEvent e) => e.isActive).length);
    });

    test('lists move forward when the day changes', () {
      final DateTime later = DateTime(2026, 10, 16);
      expect(
        pastEvents(all, later).map((TempleEvent e) => e.id),
        contains('ongoing'),
      );
    });
  });

  group('relativeEventTime', () {
    EventRelative rel(DateTime? start, [DateTime? end]) =>
        relativeEventTime(_event('x', start: start, end: end), today);

    test('today, tomorrow and in N days', () {
      expect(
        rel(DateTime(2026, 10, 11, 19)),
        const EventRelative(EventWhen.today),
      );
      expect(
        rel(DateTime(2026, 10, 12, 6)),
        const EventRelative(EventWhen.tomorrow, 1),
      );
      expect(
        rel(DateTime(2026, 10, 14)),
        const EventRelative(EventWhen.inDays, 3),
      );
      expect(
        rel(DateTime(2026, 11, 11)),
        const EventRelative(EventWhen.inDays, 31),
      );
    });

    test('a multi-day utsav that started earlier is ongoing', () {
      final EventRelative r = rel(
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 13),
      );
      expect(r.when, EventWhen.ongoing);
      expect(r.isNow, isTrue);
      expect(r.isCurrentOrFuture, isTrue);
      // Last day of the utsav.
      expect(
        rel(DateTime(2026, 10, 9), DateTime(2026, 10, 11, 8)).when,
        EventWhen.ongoing,
      );
    });

    test('a multi-day utsav starting today is "today"', () {
      expect(
        rel(DateTime(2026, 10, 11), DateTime(2026, 10, 13)).when,
        EventWhen.today,
      );
    });

    test('past and undated', () {
      final EventRelative past = rel(DateTime(2026, 10, 10));
      expect(past.when, EventWhen.past);
      expect(past.isCurrentOrFuture, isFalse);
      expect(past.isNow, isFalse);
      expect(
        rel(DateTime(2026, 10, 2), DateTime(2026, 10, 10)).when,
        EventWhen.past,
      );
      final EventRelative undated = rel(null);
      expect(undated.when, EventWhen.undated);
      expect(undated.isCurrentOrFuture, isFalse);
    });
  });

  group('eventExcerpt', () {
    test('short text is returned unchanged (whitespace collapsed)', () {
      expect(eventExcerpt('  Jay\n\nSwaminarayan  '), 'Jay Swaminarayan');
    });

    test('long text is cut at a word boundary with an ellipsis', () {
      final String text = List<String>.filled(100, 'word').join(' ');
      final String result = eventExcerpt(text, maxChars: 50);
      expect(result.endsWith('…'), isTrue);
      expect(result.length, lessThanOrEqualTo(51));
      expect(result.contains('wor…'), isFalse);
    });

    test('never splits a Gujarati letter from its matra', () {
      final String text = 'કી' * 40;
      final String result = eventExcerpt(text, maxChars: 10);
      expect(result, '${'કી' * 10}…');
    });
  });

  group('buildEventShareText', () {
    test('joins the parts and skips empty ones', () {
      expect(
        buildEventShareText(
          title: 'Annakut',
          when: 'Sunday, 20 October 2026, 7:00 PM',
          venue: '',
          excerpt: 'Grand darshan',
          footer: 'Jay Shree Swaminarayan',
        ),
        'Annakut\nSunday, 20 October 2026, 7:00 PM\n\n'
        'Grand darshan\n\nJay Shree Swaminarayan',
      );
      expect(buildEventShareText(title: ' Sabha '), 'Sabha');
    });
  });
}
