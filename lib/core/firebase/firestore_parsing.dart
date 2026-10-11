import 'package:cloud_firestore/cloud_firestore.dart';

/// Defensive converters for Firestore data. Content is edited by hand in the
/// Firebase console, so every reader must tolerate missing fields and wrong
/// types without throwing.
abstract final class Fs {
  static String string(Object? value, [String fallback = '']) {
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    return fallback;
  }

  static String? stringOrNull(Object? value) {
    final String s = string(value);
    return s.isEmpty ? null : s;
  }

  static int integer(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static int? integerOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? doubleOrNull(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  /// Missing booleans use [fallback]; strings like "true"/"false" are accepted.
  static bool boolean(Object? value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is String) {
      final String v = value.trim().toLowerCase();
      if (v == 'true' || v == 'yes' || v == '1') return true;
      if (v == 'false' || v == 'no' || v == '0') return false;
    }
    if (value is num) return value != 0;
    return fallback;
  }

  /// Accepts a Firestore [Timestamp], ISO-8601 string, epoch milliseconds or
  /// [DateTime]. Returned in local time.
  static DateTime? dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value.trim())?.toLocal();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  static List<String> stringList(Object? value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return <String>[value.trim()];
    }
    return const <String>[];
  }

  static Map<String, Object?> map(Object? value) {
    if (value is Map) {
      return value.map(
        (Object? k, Object? v) => MapEntry<String, Object?>(k.toString(), v),
      );
    }
    return const <String, Object?>{};
  }

  static List<Map<String, Object?>> mapList(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];
    return value.whereType<Map<Object?, Object?>>().map(map).toList();
  }

  /// Accepts a [GeoPoint] or a map with lat/lng (or latitude/longitude).
  static GeoPoint? geoPoint(Object? value) {
    if (value is GeoPoint) return value;
    if (value is Map) {
      final Map<String, Object?> m = map(value);
      final double? lat = doubleOrNull(m['lat'] ?? m['latitude']);
      final double? lng = doubleOrNull(m['lng'] ?? m['lon'] ?? m['longitude']);
      if (lat != null && lng != null) return GeoPoint(lat, lng);
    }
    return null;
  }
}

/// Sort key used by every list in the app: ascending `order`, items without
/// an order go last. Ties keep the secondary comparison.
int compareByOrder(int? a, int? b) {
  const int last = 1 << 30;
  return (a ?? last).compareTo(b ?? last);
}
