import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/l10n/app_language.dart';

/// Handles a push message while the app is in the background/terminated.
/// Must be a top-level function (runs in its own isolate).
///
/// TODO(feature-agent): implement.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push notifications (FCM) + local notifications for foreground messages.
///
/// TODO(feature-agent): implement. Contract used by the rest of the app:
///  * [initialize] is awaited once in bootstrap after Firebase init. Never throws.
///  * [syncSubscription] is called on start and whenever the language or the
///    notifications toggle changes.
///  * [requestPermission] is called from the home screen prompt.
///  * Notification taps must call `DeepLinks.open(route)`.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  Future<void> initialize() async {}

  Future<void> syncSubscription({
    required AppLanguage language,
    required bool enabled,
  }) async {}

  /// Returns true when notifications are allowed after the request.
  Future<bool> requestPermission() async => false;

  /// Whether the OS-level permission has been decided (granted or denied).
  Future<bool> isPermissionDetermined() async => true;
}
