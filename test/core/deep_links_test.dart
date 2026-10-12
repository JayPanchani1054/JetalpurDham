import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/router/routes.dart';
import 'package:jetalpur_dham/features/events/application/notification_service.dart';

void main() {
  group('Routes.deepLinkTarget', () {
    test('opens app locations as they are', () {
      for (final String location in <String>[
        Routes.home,
        Routes.donate,
        Routes.settings,
        Routes.album('avsar-200'),
        Routes.photo('avsar-200', 3),
        Routes.kirtan,
        Routes.kirtanDownloads,
        Routes.places,
        Routes.place('nij-mandir'),
        Routes.panorama('nij-mandir', 1),
        Routes.library,
        Routes.book('vachanamrut'),
        Routes.reader('vachanamrut'),
        Routes.events,
        Routes.event('annakut 2026'),
        '/events?tab=past',
      ]) {
        expect(Routes.deepLinkTarget(location), location, reason: location);
        expect(Routes.isSafeDeepLink(location), isTrue, reason: location);
      }
    });

    test('opens the Kirtan tab instead of the player', () {
      // The player needs a queue, which a notification cannot carry.
      for (final String location in <String>[
        Routes.player,
        '${Routes.player}?id=k1',
        '${Routes.player}/k1',
      ]) {
        expect(Routes.deepLinkTarget(location), Routes.kirtan);
        expect(Routes.isSafeDeepLink(location), isFalse);
      }
    });

    test('rejects unknown, external and incomplete locations', () {
      for (final String? location in <String?>[
        null,
        '',
        'kirtan',
        'https://evil.example.com',
        '//evil.example.com',
        '/admin',
        Routes.splash,
        '/homepage',
        '/kirtans',
        '/reader',
        '/reader/',
      ]) {
        expect(Routes.deepLinkTarget(location), isNull, reason: location);
        expect(Routes.isSafeDeepLink(location), isFalse, reason: location);
      }
    });
  });

  group('notification routes', () {
    test('a push for the player opens the Kirtan tab', () {
      expect(
        NotificationService.routeForData(<String, dynamic>{
          'route': ' /player ',
          'eventId': 'x',
        }),
        Routes.kirtan,
      );
      expect(NotificationService.routeForPayload('/player'), Routes.kirtan);
    });

    test('other routes are unchanged', () {
      expect(
        NotificationService.routeForData(<String, dynamic>{
          'route': '/library/vachanamrut',
        }),
        '/library/vachanamrut',
      );
      expect(
        NotificationService.routeForData(<String, dynamic>{
          'route': '/kirtans',
          'eventId': 'x',
        }),
        Routes.event('x'),
      );
      expect(NotificationService.routeForPayload('/nowhere'), Routes.events);
    });
  });
}
