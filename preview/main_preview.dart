// Demo build of the Jetalpur Dham app — explore every screen with sample
// content and no Firebase project:
//
//   flutter run -t preview/main_preview.dart                 (phone)
//   flutter build apk -t preview/main_preview.dart           (installable demo APK)
//   flutter build web -t preview/main_preview.dart           (browser preview)
//
// Content: the real seed data (temple history, prasadi places and their mahima,
// categories, Avsar 200), real kirtan titles and shastra names, and original
// placeholder artwork, PDF and tanpura audio from preview/demo_media.
// Push notifications, the Google map and donation payments are disabled.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jetalpur_dham/app.dart';
import 'package:jetalpur_dham/core/firebase/firebase_providers.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/utils/app_logger.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_audio_init.dart';
import 'package:jetalpur_dham/features/places/application/places_view_mode.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';

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

  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreProvider.overrideWithValue(db),
        // A Google Maps key is not bundled with the demo, so the prasadi
        // places open in the list view (map works once a key is configured).
        placesMapEnabledProvider.overrideWithValue(false),
      ],
      child: const JetalpurDhamApp(),
    ),
  );
}
