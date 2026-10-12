import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/preferences.dart';
import 'core/utils/app_logger.dart';
import 'features/events/application/notification_service.dart';
import 'features/kirtan/application/kirtan_audio_init.dart';
import 'firebase_options.dart';

/// Starts the app while keeping the native splash short. Only what the first
/// frame needs (preferences, date formats, system UI, Firebase) is awaited,
/// side by side and each with a time limit, so a slow or misconfigured
/// service can never stop the app from opening.
///
/// Not awaited before the first frame:
///  * background audio: the kirtan player waits for it (`kirtanAudioReady`);
///  * notifications: a tap that opened the app is held by `DeepLinks` until
///    the splash has finished;
///  * the PDF engine: the reader starts it when a book is opened.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(initKirtanAudio());

  final Future<SharedPreferences> prefs = SharedPreferences.getInstance();
  final Future<void> firebase = _initFirebase(prefs);
  await Future.wait(<Future<void>>[
    prefs,
    _guard('System UI', _configureSystemUi),
    _guard('Date formats', initializeDateFormatting),
    _guard('Firebase', () => firebase, timeout: const Duration(seconds: 8)),
  ]);

  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(await prefs),
      ],
      child: const JetalpurDhamApp(),
    ),
  );

  // Needs Firebase, even when it finished after its time limit above. Its
  // platform steps have their own short limits; this one only logs.
  unawaited(
    _guard('Notifications', () async {
      await firebase.catchError((Object _) {});
      await NotificationService.instance.initialize();
    }, timeout: const Duration(seconds: 30)),
  );
}

Future<void> _configureSystemUi() async {
  await Future.wait(<Future<void>>[
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]),
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
  ]);
}

Future<void> _initFirebase(Future<SharedPreferences> prefs) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Full offline support: everything a devotee has opened stays readable
  // without internet.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Registered before runApp, as firebase_messaging requires.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final bool crashReports =
      (await prefs).getBool(PrefKeys.crashReportsEnabled) ?? true;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode && crashReports,
  );
  AppLogger.crashlyticsReady = true;
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // Uncaught asynchronous errors (for example a kirtan stream that drops on
  // a poor network) do not crash a Flutter app, so they are not reported as
  // crashes.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack).ignore();
    return true;
  };
}

Future<void> _guard(
  String name,
  Future<void> Function() body, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    await body().timeout(timeout);
  } catch (error, stack) {
    AppLogger.error('$name initialisation failed', error, stack);
  }
}
