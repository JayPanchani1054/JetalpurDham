import '../../../core/firebase/firestore_parsing.dart';

/// Event dates are shown in temple time: India Standard Time (UTC+05:30,
/// no daylight saving). Devotees abroad then see the same date and time that
/// is printed on the temple's invitations, and a date-only utsav entered as
/// "20 Oct, 00:00" never shows up as "19 Oct, 1:30 PM" in another country.
///
/// Temple times are plain [DateTime] values whose fields (year … second)
/// read as IST wall-clock time.
abstract final class TempleTime {
  /// India Standard Time.
  static const Duration utcOffset = Duration(hours: 5, minutes: 30);

  /// Temple wall-clock time of an absolute [instant].
  static DateTime fromInstant(DateTime instant) {
    final DateTime t = instant.toUtc().add(utcOffset);
    return DateTime(
      t.year,
      t.month,
      t.day,
      t.hour,
      t.minute,
      t.second,
      t.millisecond,
    );
  }

  /// Current temple wall-clock time ([instant] defaults to now).
  static DateTime now([DateTime? instant]) =>
      fromInstant(instant ?? DateTime.now());

  /// Converts a Firestore date value to temple time. Never throws.
  ///
  /// Values that name an instant (Firestore Timestamp, epoch milliseconds,
  /// ISO strings with `Z` or an offset, UTC [DateTime]s) are converted.
  /// Values without a zone (`"2026-11-01T07:00"`, a local [DateTime]) are
  /// already temple wall-clock time and are kept as they are.
  static DateTime? parse(Object? value) {
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value.trim());
      if (parsed == null) return null;
      return parsed.isUtc ? fromInstant(parsed) : parsed;
    }
    if (value is DateTime) return value.isUtc ? fromInstant(value) : value;
    final DateTime? instant = Fs.dateTime(value);
    return instant == null ? null : fromInstant(instant);
  }

  /// Time left until the next temple midnight, measured from [templeNow]
  /// (a temple wall-clock time). Computed in UTC so the device's own
  /// daylight-saving changes never skew it.
  static Duration untilNextMidnight(DateTime templeNow) {
    final DateTime current = DateTime.utc(
      templeNow.year,
      templeNow.month,
      templeNow.day,
      templeNow.hour,
      templeNow.minute,
      templeNow.second,
      templeNow.millisecond,
    );
    final DateTime next = DateTime.utc(
      templeNow.year,
      templeNow.month,
      templeNow.day + 1,
    );
    return next.difference(current);
  }

  /// True when the phone is not set to India time, so event times get an
  /// "(India time)" hint.
  static bool isDeviceOutsideIndia([DateTime? deviceNow]) =>
      (deviceNow ?? DateTime.now()).timeZoneOffset != utcOffset;
}
