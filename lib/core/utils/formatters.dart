import 'package:intl/intl.dart';

/// Display formatting helpers. All functions are locale aware and never throw.
abstract final class Formatters {
  /// `3:07` or `1:02:45`.
  static String duration(Duration? value) {
    if (value == null || value.isNegative) return '--:--';
    final int h = value.inHours;
    final String m = (value.inMinutes % 60).toString().padLeft(
      h > 0 ? 2 : 1,
      '0',
    );
    final String s = (value.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// `4.2 MB`.
  static String bytes(int? value) {
    if (value == null || value <= 0) return '0 MB';
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double size = value.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  /// `12 Oct 2026` in the given locale (e.g. `gu`).
  static String date(DateTime? value, String locale) =>
      value == null ? '' : _safe(() => DateFormat.yMMMd(locale).format(value));

  /// `Sunday, 12 October 2026`.
  static String longDate(DateTime? value, String locale) => value == null
      ? ''
      : _safe(() => DateFormat.yMMMMEEEEd(locale).format(value));

  /// `7:30 PM`.
  static String time(DateTime? value, String locale) =>
      value == null ? '' : _safe(() => DateFormat.jm(locale).format(value));

  /// Day-of-month (`12`) and short month (`Oct`) for date badges.
  static String day(DateTime value, String locale) =>
      _safe(() => DateFormat.d(locale).format(value));
  static String shortMonth(DateTime value, String locale) =>
      _safe(() => DateFormat.MMM(locale).format(value));

  static String _safe(String Function() format) {
    try {
      return format();
    } catch (_) {
      return '';
    }
  }
}
