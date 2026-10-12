import 'dart:async';
import 'dart:ui' show Locale;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/deep_links.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../firebase_options.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Handles a push message while the app is in the background/terminated.
/// Must be a top-level function (runs in its own isolate).
///
/// Notification messages are displayed by the operating system itself, so
/// the only job here is to make sure Firebase is ready in this isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (error, stack) {
    AppLogger.error('Background Firebase init failed', error, stack);
  }
}

/// Push notifications (FCM) + local notifications for foreground messages.
///
/// Contract used by the rest of the app (none of these ever throw):
///  * [initialize] is started once by bootstrap after Firebase init, right
///    after the first frame.
///  * [syncSubscription] is called on start and whenever the language or the
///    notifications toggle changes. Each device follows exactly one topic:
///    `lang_en`, `lang_gu` or `lang_hi`.
///  * [requestPermission] is called from the home screen prompt.
///  * Notification taps open `DeepLinks.open(route)` (see [routeFor]).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Android channel for utsav / katha updates (also the FCM default channel
  /// declared in AndroidManifest.xml).
  static const String channelId = 'utsav_updates';
  static const String _androidIcon = '@drawable/ic_notification';
  static const Duration _platformTimeout = Duration(seconds: 20);

  /// A notification tap that opened the app waits for [initialize], so each
  /// local platform step gets only a few seconds.
  static const Duration _initStepTimeout = Duration(seconds: 4);

  FlutterLocalNotificationsPlugin get _local =>
      FlutterLocalNotificationsPlugin();

  Future<void>? _initializing;
  bool _localReady = false;
  AppLocalizations _strings = _stringsFor(AppLanguage.en);

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  /// Topic changes run one after another, in the order requested.
  Future<void> _syncQueue = Future<void>.value();

  /// Last requested subscription state, re-applied when the token changes.
  (AppLanguage, bool)? _desired;

  /// The state that was successfully applied in this session.
  (AppLanguage, bool)? _applied;

  // ---------------------------------------------------------------------------
  // Routing (pure, unit tested)
  // ---------------------------------------------------------------------------

  /// Where a tap on [message] should land: `data.route` when it is a safe
  /// in-app location (see [Routes.deepLinkTarget]), else the event in
  /// `data.eventId`, else the events tab.
  static String routeFor(RemoteMessage message) => routeForData(message.data);

  /// See [routeFor].
  static String routeForData(Map<String, dynamic> data) {
    final Object? route = data['route'];
    final String? target = route is String
        ? Routes.deepLinkTarget(route.trim())
        : null;
    if (target != null) return target;
    final Object? eventId = data['eventId'];
    if (eventId is String && eventId.trim().isNotEmpty) {
      return Routes.event(eventId.trim());
    }
    return Routes.events;
  }

  /// Route stored in a local notification's payload.
  static String routeForPayload(String? payload) =>
      Routes.deepLinkTarget(payload?.trim()) ?? Routes.events;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      await _initializeSteps();
    } catch (error, stack) {
      AppLogger.error('Notifications initialisation failed', error, stack);
    }
  }

  /// Each step is guarded on its own so one failing platform call never
  /// stops the others (e.g. a missing APNs setup must not break deep links).
  Future<void> _initializeSteps() async {
    if (!_firebaseReady) return;

    await _guard('load language', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _strings = _stringsFor(
        AppLanguage.fromCode(prefs.getString(PrefKeys.language)),
      );
    });

    await _guard('local notifications', _initLocalNotifications);

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    if (_isIOS) {
      // Show banners for messages that arrive while the app is open.
      await _guard(
        'foreground presentation',
        () => messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        ),
      );
    }

    await _guard('listeners', () async {
      await _cancelSubscriptions();
      _foregroundSub = FirebaseMessaging.onMessage.listen(
        _onForegroundMessage,
        onError: _logStreamError,
      );
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) => DeepLinks.open(routeFor(message)),
        onError: _logStreamError,
      );
      _tokenSub = messaging.onTokenRefresh.listen(
        (_) => _resyncDesired(force: true),
        onError: _logStreamError,
      );
    });

    // App opened from a terminated state by tapping a push notification.
    await _guard('initial message', () async {
      final RemoteMessage? initial = await messaging.getInitialMessage();
      if (initial != null) DeepLinks.open(routeFor(initial));
    });

    // App opened by tapping a notification we showed in the foreground.
    if (_localReady) {
      await _guard('launch details', () async {
        final NotificationAppLaunchDetails? details = await _local
            .getNotificationAppLaunchDetails();
        if (details != null && details.didNotificationLaunchApp) {
          DeepLinks.open(
            routeForPayload(details.notificationResponse?.payload),
          );
        }
      });
    }
  }

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // Never ask on launch: the home screen explains first, then asks.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    _localReady = true;
    await _createAndroidChannel();
  }

  /// Creates (or renames, after a language change) the Android channel.
  Future<void> _createAndroidChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _androidPlugin;
    if (android == null) return;
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        _strings.notificationChannelName,
        description: _strings.notificationChannelDesc,
        importance: Importance.high,
      ),
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    DeepLinks.open(routeForPayload(response.payload));
  }

  /// Android does not show notification messages while the app is open, so
  /// mirror them as a local notification. (iOS shows them itself.)
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (!_isAndroid || !_localReady) return;
    try {
      final RemoteNotification? notification = message.notification;
      final String title =
          (notification?.title ?? _dataString(message.data, 'title')).trim();
      final String body =
          (notification?.body ?? _dataString(message.data, 'body')).trim();
      if (title.isEmpty && body.isEmpty) return;
      await _local.show(
        id: _notificationId(message),
        title: title.isEmpty ? null : title,
        body: body.isEmpty ? null : body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _strings.notificationChannelName,
            channelDescription: _strings.notificationChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            color: AppColors.saffron,
            styleInformation: body.isEmpty
                ? null
                : BigTextStyleInformation(
                    body,
                    contentTitle: title.isEmpty ? null : title,
                  ),
          ),
        ),
        payload: routeFor(message),
      );
    } catch (error, stack) {
      AppLogger.error('Could not show foreground notification', error, stack);
    }
  }

  // ---------------------------------------------------------------------------
  // Topic subscription
  // ---------------------------------------------------------------------------

  Future<void> syncSubscription({
    required AppLanguage language,
    required bool enabled,
  }) {
    _desired = (language, enabled);
    final Future<void> next = _syncQueue.then((_) => _sync(language, enabled));
    _syncQueue = next;
    return next;
  }

  Future<void> _sync(AppLanguage language, bool enabled) async {
    try {
      // Channel name and foreground notifications follow the app language.
      final AppLocalizations strings = _stringsFor(language);
      if (!identical(strings, _strings)) {
        _strings = strings;
        if (_localReady) {
          await _guard(
            'channel',
            _createAndroidChannel,
            timeout: _platformTimeout,
          );
        }
      }

      if (!_firebaseReady) return;
      if (_applied == (language, enabled)) return;

      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      // iOS rejects topic calls until APNs has issued a device token.
      if (_isIOS && !await _waitForApnsToken(messaging)) {
        AppLogger.info('APNs token not ready; topic sync postponed');
        return;
      }

      final String wanted = language.notificationTopic;
      bool allOk = true;
      Future<void> run(String what, Future<void> Function() call) async {
        try {
          await call().timeout(_platformTimeout);
        } catch (error) {
          // Usually offline; FCM retries queued topic operations itself and
          // the next app start syncs again.
          allOk = false;
          AppLogger.info('Topic $what failed: $error');
        }
      }

      if (enabled) {
        await run(
          'subscribe $wanted',
          () => messaging.subscribeToTopic(wanted),
        );
      }
      for (final AppLanguage other in AppLanguage.values) {
        final String topic = other.notificationTopic;
        if (enabled && topic == wanted) continue;
        await run(
          'unsubscribe $topic',
          () => messaging.unsubscribeFromTopic(topic),
        );
      }
      _applied = allOk ? (language, enabled) : null;
    } catch (error, stack) {
      AppLogger.error('Notification topic sync failed', error, stack);
    }
  }

  Future<bool> _waitForApnsToken(FirebaseMessaging messaging) async {
    const List<int> delaysMs = <int>[0, 500, 1000, 1500, 2000, 3000];
    for (final int delay in delaysMs) {
      if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
      try {
        final String? token = await messaging.getAPNSToken().timeout(
          const Duration(seconds: 5),
        );
        if (token != null && token.isNotEmpty) return true;
      } catch (_) {
        // Not available yet; try again shortly.
      }
    }
    return false;
  }

  /// Re-applies the last requested state (after a token refresh or once
  /// permission is granted on iOS, when the APNs token becomes available).
  void _resyncDesired({bool force = false}) {
    final (AppLanguage, bool)? desired = _desired;
    if (desired == null) return;
    if (force) _applied = null;
    if (_applied == desired) return;
    unawaited(syncSubscription(language: desired.$1, enabled: desired.$2));
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  /// Asks the OS for permission. Returns true when notifications are allowed
  /// (or provisionally allowed on iOS).
  Future<bool> requestPermission() async {
    bool granted = false;
    if (_firebaseReady) {
      try {
        final NotificationSettings settings = await FirebaseMessaging.instance
            .requestPermission();
        granted = _isAllowed(settings.authorizationStatus);
      } catch (error, stack) {
        AppLogger.error('FCM permission request failed', error, stack);
        granted = await _requestLocalPermission();
      }
    } else {
      granted = await _requestLocalPermission();
    }
    if (granted) _resyncDesired();
    return granted;
  }

  /// Fallback through flutter_local_notifications (Android 13+ runtime
  /// permission, iOS authorization). Used only when FCM cannot ask, so the
  /// user never sees the system dialog twice.
  Future<bool> _requestLocalPermission() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _androidPlugin;
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      if (_isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios = _local
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (error, stack) {
      AppLogger.error('Notification permission request failed', error, stack);
    }
    return false;
  }

  /// Whether the OS-level permission has been decided (granted or denied).
  /// Returns true when it cannot be determined, so the app never nags.
  Future<bool> isPermissionDetermined() async {
    if (!_firebaseReady) return true;
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .getNotificationSettings()
          .timeout(_platformTimeout);
      return settings.authorizationStatus != AuthorizationStatus.notDetermined;
    } catch (error, stack) {
      AppLogger.error('Reading notification settings failed', error, stack);
      return true;
    }
  }

  /// Stops listening to FCM streams (tests / hot restart).
  @visibleForTesting
  Future<void> dispose() => _cancelSubscriptions();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _cancelSubscriptions() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenSub?.cancel();
    _foregroundSub = null;
    _openedSub = null;
    _tokenSub = null;
  }

  static bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _isAndroid
      ? _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
      : null;

  static bool _isAllowed(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  static final Map<AppLanguage, AppLocalizations> _stringsCache =
      <AppLanguage, AppLocalizations>{};

  static AppLocalizations _stringsFor(AppLanguage language) =>
      _stringsCache[language] ??= lookupAppLocalizations(Locale(language.code));

  static String _dataString(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    return value is String ? value : '';
  }

  /// Stable 31-bit id per message so a repeated delivery replaces itself.
  static int _notificationId(RemoteMessage message) {
    final String key =
        message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
    return key.hashCode & 0x7fffffff;
  }

  static void _logStreamError(Object error, StackTrace stack) {
    AppLogger.error('Notification stream error', error, stack);
  }

  static Future<void> _guard(
    String step,
    Future<void> Function() body, {
    Duration timeout = _initStepTimeout,
  }) async {
    try {
      await body().timeout(timeout);
    } catch (error, stack) {
      AppLogger.error('Notifications: $step failed', error, stack);
    }
  }
}
