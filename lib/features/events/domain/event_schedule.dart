import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Characters, StringCharacters;

import 'temple_event.dart';

/// Pure date logic for events: Upcoming/Past split, sorting and the relative
/// label ("Today", "In 3 days", "Ongoing"). Everything works on calendar days
/// in local time and takes `today` as a parameter, so it is fully testable.

/// Midnight (local) of [value]'s calendar day.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Whole calendar days from [from] to [to] (negative when [to] is earlier).
/// Uses UTC dates so daylight-saving changes never shift the result.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Upcoming = `endAt ?? startAt` falls on [today] or later. Undated events
/// are treated as current (shown at the end of Upcoming) so they never vanish.
bool isUpcomingEvent(TempleEvent event, DateTime today) {
  final DateTime? last = event.lastMoment;
  if (last == null) return true;
  return calendarDaysBetween(today, last) >= 0;
}

/// Active upcoming events, soonest first (undated last).
List<TempleEvent> upcomingEvents(Iterable<TempleEvent> events, DateTime today) {
  return events
      .where((TempleEvent e) => e.isActive && isUpcomingEvent(e, today))
      .toList()
    ..sort(_compareSoonestFirst);
}

/// Active past events, newest first.
List<TempleEvent> pastEvents(Iterable<TempleEvent> events, DateTime today) {
  return events
      .where((TempleEvent e) => e.isActive && !isUpcomingEvent(e, today))
      .toList()
    ..sort(_compareNewestFirst);
}

int _compareSoonestFirst(TempleEvent a, TempleEvent b) {
  final DateTime? sa = a.startAt;
  final DateTime? sb = b.startAt;
  if (sa != null && sb != null) {
    final int byStart = sa.compareTo(sb);
    if (byStart != 0) return byStart;
  } else if (sa != null || sb != null) {
    return sa == null ? 1 : -1;
  }
  return _compareTitleThenId(a, b);
}

int _compareNewestFirst(TempleEvent a, TempleEvent b) {
  final DateTime? sa = a.startAt;
  final DateTime? sb = b.startAt;
  if (sa != null && sb != null) {
    final int byStart = sb.compareTo(sa);
    if (byStart != 0) return byStart;
  } else if (sa != null || sb != null) {
    return sa == null ? 1 : -1;
  }
  return _compareTitleThenId(a, b);
}

int _compareTitleThenId(TempleEvent a, TempleEvent b) {
  final int byTitle = a
      .titleIn('en')
      .toLowerCase()
      .compareTo(b.titleIn('en').toLowerCase());
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}

/// Where an event sits relative to today.
enum EventWhen { today, tomorrow, inDays, ongoing, past, undated }

/// Relative position of an event, e.g. `inDays` with [days] = 5.
@immutable
class EventRelative {
  const EventRelative(this.when, [this.days = 0]);

  final EventWhen when;

  /// Days until the start (only meaningful for [EventWhen.inDays]).
  final int days;

  /// Upcoming or happening now: "Watch Live" makes sense.
  bool get isCurrentOrFuture =>
      when != EventWhen.past && when != EventWhen.undated;

  /// Happening today (single-day today, or a multi-day utsav in progress).
  bool get isNow => when == EventWhen.today || when == EventWhen.ongoing;

  @override
  bool operator ==(Object other) =>
      other is EventRelative && other.when == when && other.days == days;

  @override
  int get hashCode => Object.hash(when, days);

  @override
  String toString() => 'EventRelative($when, $days)';
}

/// Computes the relative label for [event] as seen on [today].
EventRelative relativeEventTime(TempleEvent event, DateTime today) {
  final DateTime? start = event.startAt;
  if (start == null) return const EventRelative(EventWhen.undated);
  final int untilStart = calendarDaysBetween(today, start);
  if (untilStart > 1) return EventRelative(EventWhen.inDays, untilStart);
  if (untilStart == 1) return const EventRelative(EventWhen.tomorrow, 1);
  if (untilStart == 0) return const EventRelative(EventWhen.today);
  final DateTime? end = event.endAt;
  if (end != null && calendarDaysBetween(today, end) >= 0) {
    return const EventRelative(EventWhen.ongoing);
  }
  return const EventRelative(EventWhen.past);
}

/// True when [value] has a meaningful time of day (not exactly midnight).
bool hasTimeOfDay(DateTime? value) =>
    value != null &&
    (value.hour != 0 || value.minute != 0 || value.second != 0);

/// Shortens [text] to about [maxChars] characters at a word boundary, with an
/// ellipsis. Whitespace runs (including new lines) collapse to one space.
/// Grapheme-safe, so Gujarati/Hindi conjuncts and matras are never split.
String eventExcerpt(String text, {int maxChars = 280}) {
  final String normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final Characters chars = normalized.characters;
  if (chars.length <= maxChars) return normalized;
  String cut = chars.take(maxChars).toString();
  final int lastSpace = cut.lastIndexOf(' ');
  if (lastSpace > maxChars * 0.6) cut = cut.substring(0, lastSpace);
  return '${cut.trimRight()}…';
}

/// Plain-text message used when sharing an event. Empty parts are skipped.
String buildEventShareText({
  required String title,
  String? when,
  String? venue,
  String? excerpt,
  String? footer,
}) {
  bool has(String? s) => s != null && s.trim().isNotEmpty;
  final List<String> head = <String>[
    title.trim(),
    if (has(when)) when!.trim(),
    if (has(venue)) venue!.trim(),
  ];
  return <String>[
    head.join('\n'),
    if (has(excerpt)) excerpt!.trim(),
    if (has(footer)) footer!.trim(),
  ].join('\n\n');
}
