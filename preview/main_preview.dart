// Demo build of the Jetalpur Dham app — explore every screen with sample
// content and no Firebase project:
//
//   flutter run -t preview/main_preview.dart                 (phone)
//   flutter build apk -t preview/main_preview.dart -P jdDemo=true
//                                                            (installable demo APK)
//   flutter build web -t preview/main_preview.dart           (browser preview)
//
// `-P jdDemo=true` (CI: ORG_GRADLE_PROJECT_jdDemo=true) gives the APK its own
// package name and launcher label ("Jetalpur Dham Demo") and signs it with the
// public demo key, so it installs next to the real app; see
// android/app/demo-signing/README.md.
//
// Content: the real seed data (temple history, prasadi places and their mahima,
// categories, Avsar 200), real kirtan titles and shastra names, and original
// placeholder artwork, PDF and tanpura audio from preview/demo_media.
// Push notifications, the Google map and donation payments are disabled.
// A one-time sheet (demo_intro.dart) tells testers this on first launch.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jetalpur_dham/app.dart';
import 'package:jetalpur_dham/core/firebase/firebase_providers.dart';
import 'package:jetalpur_dham/core/router/app_router.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/utils/app_logger.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_audio_init.dart';
import 'package:jetalpur_dham/features/places/application/places_view_mode.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';
import 'demo_intro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // The demo never asks for notification permission.
  await prefs.setBool(PrefKeys.notificationPromptShown, true);
  await initializeDateFormatting();
  if (!kIsWeb) await initKirtanAudio();
  try {
    await pdfrxFlutterInitialize();
  } catch (error, stack) {
    AppLogger.error('PDF engine unavailable in demo', error, stack);
  }
  final FakeFirebaseFirestore db;
  try {
    db = await buildDemoFirestore();
  } catch (error, stack) {
    debugPrint('DEMO DATA FAILED: $error\n$stack');
    rethrow;
  }

  final GoRouter router = createRouter();
  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreProvider.overrideWithValue(db),
        // A Google Maps key is not bundled with the demo, so the prasadi
        // places open in the list view (map works once a key is configured).
        placesMapEnabledProvider.overrideWithValue(false),
      ],
      child: DemoIntroHost(
        router: router,
        prefs: prefs,
        child: JetalpurDhamApp(router: router),
      ),
    ),
  );
}
