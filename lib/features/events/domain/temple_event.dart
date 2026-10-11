import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/models/localized_text.dart';

/// Kind of temple event (`events/{id}.type`).
enum EventType {
  utsav,
  katha,
  announcement,
  other;

  /// Parses the Firestore value. Unknown or missing values become [other].
  static EventType parse(Object? value) {
    final String raw = Fs.string(value).toLowerCase();
    for (final EventType type in EventType.values) {
      if (type.name == raw) return type;
    }
    return EventType.other;
  }
}

/// One utsav, katha or announcement (`events/{eventId}`).
/// See docs/DATA_MODEL.md. Every field is optional except the id, so a
/// half-filled document from the Firebase console never breaks the app.
@immutable
class TempleEvent {
  const TempleEvent({
    required this.id,
    this.title = const LocalizedText.empty(),
    this.shortDescription = const LocalizedText.empty(),
    this.description = const LocalizedText.empty(),
    this.location = const LocalizedText.empty(),
    this.bannerUrl,
    this.startAt,
    this.endAt,
    this.type = EventType.other,
    this.albumId,
    this.liveUrl,
    this.isActive = true,
  });

  /// Parses a Firestore document. Never throws.
  factory TempleEvent.fromMap(String id, Map<String, Object?> map) {
    final DateTime? start = Fs.dateTime(map['startAt']);
    DateTime? end = Fs.dateTime(map['endAt']);
    // An end before the start is a data-entry slip: ignore it.
    if (start != null && end != null && end.isBefore(start)) end = null;
    final LocalizedText title = LocalizedText.fromValue(map['title']);
    return TempleEvent(
      id: id,
      title: title,
      shortDescription: LocalizedText.fromValue(map['shortDescription']),
      description: LocalizedText.fromValue(map['description']),
      location: LocalizedText.fromValue(map['location']),
      bannerUrl: Fs.stringOrNull(map['bannerUrl']),
      // `startAt` is required by the contract; fall back to `endAt` so an
      // event with only an end date is still placed correctly.
      startAt: start ?? end,
      endAt: start == null ? null : end,
      type: EventType.parse(map['type']),
      albumId: Fs.stringOrNull(map['albumId']),
      liveUrl: _httpUrlOrNull(map['liveUrl']),
      isActive: Fs.boolean(map['isActive'], fallback: true),
    );
  }

  final String id;
  final LocalizedText title;
  final LocalizedText shortDescription;
  final LocalizedText description;

  /// Venue, e.g. "Sabha Mandap, Jetalpur Dham".
  final LocalizedText location;

  /// 16:9 banner (https URL, `gs://` URL or Storage path).
  final String? bannerUrl;

  /// Local date-time the event begins. Null only for undated documents.
  final DateTime? startAt;

  /// Optional local end (multi-day utsav). Never before [startAt].
  final DateTime? endAt;
  final EventType type;

  /// Gallery album with the event's photos ("View Photos").
  final String? albumId;

  /// YouTube / live stream link ("Watch Live").
  final String? liveUrl;
  final bool isActive;

  /// The moment that decides Upcoming vs Past: `endAt ?? startAt`.
  DateTime? get lastMoment => endAt ?? startAt;

  /// True when the event spans more than one calendar day.
  bool get isMultiDay {
    final DateTime? start = startAt;
    final DateTime? end = endAt;
    if (start == null || end == null) return false;
    return DateTime(start.year, start.month, start.day) !=
        DateTime(end.year, end.month, end.day);
  }

  /// Display title in [languageCode]; never empty.
  String titleIn(String languageCode) {
    final String text = title.resolve(languageCode);
    return text.isEmpty ? id : text;
  }

  /// Long text for the detail page, falling back to the short description.
  LocalizedText get body =>
      description.isNotEmpty ? description : shortDescription;

  static String? _httpUrlOrNull(Object? value) {
    final String? raw = Fs.stringOrNull(value);
    if (raw == null) return null;
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      // Admins often paste "youtube.com/live/…" without the scheme.
      return raw.contains('.') && !raw.contains(' ') ? 'https://$raw' : null;
    }
    return uri.scheme == 'https' || uri.scheme == 'http' ? raw : null;
  }

  @override
  bool operator ==(Object other) =>
      other is TempleEvent &&
      other.id == id &&
      other.title == title &&
      other.shortDescription == shortDescription &&
      other.description == description &&
      other.location == location &&
      other.bannerUrl == bannerUrl &&
      other.startAt == startAt &&
      other.endAt == endAt &&
      other.type == type &&
      other.albumId == albumId &&
      other.liveUrl == liveUrl &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    shortDescription,
    description,
    location,
    bannerUrl,
    startAt,
    endAt,
    type,
    albumId,
    liveUrl,
    isActive,
  );

  @override
  String toString() => 'TempleEvent($id, ${title.resolve('en')}, $startAt)';
}
