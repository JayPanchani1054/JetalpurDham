import 'package:url_launcher/url_launcher.dart';

import 'app_logger.dart';

/// Wrappers around url_launcher that never throw. Each returns `true` when
/// something was opened so the caller can show a message otherwise.
abstract final class Launcher {
  static Future<bool> url(String url, {bool inApp = false}) async {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || url.trim().isEmpty) return false;
    return _launch(
      uri,
      inApp ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication,
    );
  }

  static Future<bool> phone(String number) =>
      _launch(Uri(scheme: 'tel', path: _digits(number, keepPlus: true)));

  static Future<bool> email(String address, {String? subject}) => _launch(
    Uri(
      scheme: 'mailto',
      path: address.trim(),
      query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
    ),
  );

  /// Opens a WhatsApp chat. [number] should include the country code
  /// (e.g. 919876543210); a 10-digit Indian number gets `91` prefixed.
  static Future<bool> whatsApp(String number, {String? message}) {
    String digits = _digits(number);
    if (digits.length == 10) digits = '91$digits';
    final String text = message == null
        ? ''
        : '?text=${Uri.encodeComponent(message)}';
    return _launch(Uri.parse('https://wa.me/$digits$text'));
  }

  /// Turn-by-turn directions in Google Maps (or the default maps app).
  static Future<bool> directions(double lat, double lng) => _launch(
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    ),
  );

  /// Shows a pin at exact coordinates in Google Maps. (A text label would make
  /// Maps search by name, which can land on the wrong place.)
  static Future<bool> mapLocation(double lat, double lng, {String? label}) =>
      _launch(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      );

  /// Opens Google Street View panorama at a location.
  static Future<bool> streetView(
    double lat,
    double lng, {
    double heading = 0,
    double pitch = 0,
  }) => _launch(
    Uri.parse(
      'https://www.google.com/maps/@?api=1&map_action=pano'
      '&viewpoint=$lat,$lng&heading=${heading.round()}&pitch=${pitch.round()}',
    ),
  );

  static String _digits(String value, {bool keepPlus = false}) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return keepPlus && value.trim().startsWith('+') ? '+$digits' : digits;
  }

  static Future<bool> _launch(
    Uri uri, [
    LaunchMode mode = LaunchMode.externalApplication,
  ]) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (error, stack) {
      AppLogger.error('Could not launch $uri', error, stack);
      return false;
    }
  }
}
