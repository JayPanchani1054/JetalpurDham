import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/utils/launcher.dart';

void main() {
  group('Launcher.emailUri', () {
    test('address only', () {
      expect(
        Launcher.emailUri(' office@example.org ').toString(),
        'mailto:office@example.org',
      );
    });

    test('encodes spaces and line breaks the way mail apps expect', () {
      final Uri uri = Launcher.emailUri(
        'office@example.org',
        subject: 'App feedback & ideas',
        body: '\n\n---\nJetalpur Dham · Version 1.0.0 (1)\nAndroid',
      );
      expect(
        uri.toString(),
        'mailto:office@example.org'
        '?subject=App%20feedback%20%26%20ideas'
        '&body=%0A%0A---%0AJetalpur%20Dham%20%C2%B7%20Version%201.0.0%20(1)'
        '%0AAndroid',
      );
      expect(uri.queryParameters['subject'], 'App feedback & ideas');
      expect(uri.queryParameters['body'], contains('Version 1.0.0 (1)\n'));
    });

    test('keeps Gujarati and Hindi text intact', () {
      final Uri uri = Launcher.emailUri(
        'office@example.org',
        subject: 'જેતલપુર ધામ એપ વિશે પ્રતિસાદ',
        body: 'जेतलपुर धाम',
      );
      expect(uri.queryParameters['subject'], 'જેતલપુર ધામ એપ વિશે પ્રતિસાદ');
      expect(uri.queryParameters['body'], 'जेतलपुर धाम');
    });
  });
}
