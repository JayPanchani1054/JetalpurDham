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
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/preferences.dart';
import 'core/utils/app_logger.dart';
import 'features/events/application/notification_service.dart';
import 'features/kirtan/application/kirtan_audio_init.dart';
import 'firebase_options.dart';

/// Initialises every service before the first frame, isolating failures so a
/// single misconfigured service can never stop the app from opening.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await initializeDateFormatting();

  await _guard('Firebase', () async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Full offline support: everything a devotee has opened stays readable
    // without internet.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode && (prefs.getBool(PrefKeys.crashReportsEnabled) ?? true),
    );
    AppLogger.crashlyticsReady = true;
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  });

  await _guard('Notifications', NotificationService.instance.initialize);
  await _guard('Audio', initKirtanAudio);
  await _guard('PDF', pdfrxFlutterInitialize);

  runApp(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const JetalpurDhamApp(),
    ),
  );
}

Future<void> _guard(String name, Future<void> Function() body) async {
  try {
    await body().timeout(const Duration(seconds: 15));
  } catch (error, stack) {
    AppLogger.error('$name initialisation failed', error, stack);
  }
}
