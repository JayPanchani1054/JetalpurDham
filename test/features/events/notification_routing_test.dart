import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/l10n/app_language.dart';
import 'package:jetalpur_dham/core/router/routes.dart';
import 'package:jetalpur_dham/features/events/application/notification_service.dart';

void main() {
  group('NotificationService.routeFor', () {
    String route(Map<String, dynamic> data) =>
        NotificationService.routeFor(RemoteMessage(data: data));

    test('uses a safe in-app route from data.route', () {
      expect(route(<String, dynamic>{'route': '/kirtan'}), '/kirtan');
      expect(
        route(<String, dynamic>{'route': ' /home/donate '}),
        '/home/donate',
      );
      expect(
        route(<String, dynamic>{'route': '/events/abc', 'eventId': 'zzz'}),
        '/events/abc',
        reason: 'an explicit route wins over eventId',
      );
    });

    test('falls back to the event when the route is unsafe or missing', () {
      expect(
        route(<String, dynamic>{'eventId': 'annakut-2026'}),
        '/events/annakut-2026',
      );
      expect(
        route(<String, dynamic>{
          'route': 'https://evil.example.com',
          'eventId': 'x',
        }),
        '/events/x',
      );
      expect(
        route(<String, dynamic>{'route': '//evil.example.com', 'eventId': 'x'}),
        '/events/x',
      );
      expect(
        route(<String, dynamic>{'route': '/admin', 'eventId': 'x'}),
        '/events/x',
      );
    });

    test('encodes unusual event ids', () {
      expect(
        route(<String, dynamic>{'eventId': 'a b/c'}),
        Routes.event('a b/c'),
      );
    });

    test('defaults to the events tab', () {
      expect(route(<String, dynamic>{}), Routes.events);
      expect(route(<String, dynamic>{'type': 'general'}), Routes.events);
      expect(route(<String, dynamic>{'eventId': '   '}), Routes.events);
      expect(
        route(<String, dynamic>{'eventId': 42, 'route': 7}),
        Routes.events,
      );
    });

    test('routeForData matches routeFor', () {
      expect(
        NotificationService.routeForData(<String, dynamic>{'eventId': 'e'}),
        '/events/e',
      );
    });
  });

  group('NotificationService.routeForPayload', () {
    test('accepts safe routes only', () {
      expect(NotificationService.routeForPayload('/events/e1'), '/events/e1');
      expect(NotificationService.routeForPayload('/library'), '/library');
      expect(NotificationService.routeForPayload(null), Routes.events);
      expect(NotificationService.routeForPayload(''), Routes.events);
      expect(
        NotificationService.routeForPayload('https://x.org'),
        Routes.events,
      );
    });
  });

  test('every language has a valid FCM topic', () {
    final RegExp valid = RegExp(r'^[a-zA-Z0-9-_.~%]{1,900}$');
    expect(
      AppLanguage.values.map((AppLanguage l) => l.notificationTopic),
      <String>['lang_en', 'lang_gu', 'lang_hi'],
    );
    for (final AppLanguage language in AppLanguage.values) {
      expect(valid.hasMatch(language.notificationTopic), isTrue);
    }
  });

  test('channel id matches the AndroidManifest default channel', () {
    expect(NotificationService.channelId, 'utsav_updates');
  });
}
