import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jetalpur_dham/app.dart';
import 'package:jetalpur_dham/core/firebase/firebase_providers.dart';
import 'package:jetalpur_dham/core/router/app_router.dart';
import 'package:jetalpur_dham/core/router/routes.dart';
import 'package:jetalpur_dham/core/services/connectivity_service.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/widgets/menu_button.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_player_controller.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_player_state.dart';
import 'package:jetalpur_dham/features/places/application/places_view_mode.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the whole app — real router, shell, drawer and every screen — against
/// an in-memory Firestore loaded with the real seed data (tools/seed) plus a
/// few kirtans, books, photos and an upcoming utsav. Any exception or layout
/// overflow anywhere fails the test.

class _IdlePlayer extends KirtanPlayerController {
  @override
  KirtanQueue build() => const KirtanQueue();
}

Object? _decodeSeedValue(Object? value) {
  if (value is Map) {
    if (value.containsKey(r'$geopoint')) {
      final List<Object?> p = (value[r'$geopoint'] as List<Object?>);
      return GeoPoint((p[0]! as num).toDouble(), (p[1]! as num).toDouble());
    }
    if (value.containsKey(r'$timestamp')) {
      return Timestamp.fromDate(DateTime.parse(value[r'$timestamp'] as String));
    }
    return value.map(
      (Object? k, Object? v) =>
          MapEntry<String, Object?>(k.toString(), _decodeSeedValue(v)),
    );
  }
  if (value is List) return value.map(_decodeSeedValue).toList();
  return value;
}

Future<FakeFirebaseFirestore> _seededFirestore() async {
  final FakeFirebaseFirestore db = FakeFirebaseFirestore();
  final Map<String, Object?> seed = jsonDecode(
    File('tools/seed/seed-data.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final Map<String, Object?> collections =
      seed['collections']! as Map<String, Object?>;
  for (final MapEntry<String, Object?> collection in collections.entries) {
    final Map<String, Object?> docs = collection.value! as Map<String, Object?>;
    for (final MapEntry<String, Object?> doc in docs.entries) {
      await db
          .collection(collection.key)
          .doc(doc.key)
          .set(_decodeSeedValue(doc.value)! as Map<String, Object?>);
    }
  }

  final DateTime now = DateTime.now();
  for (int i = 1; i <= 3; i++) {
    await db.collection('kirtans').doc('k$i').set(<String, Object?>{
      'title': <String, Object?>{
        'en': 'Jay Sadguru Swami $i',
        'gu': 'જય સદગુરુ સ્વામી $i',
      },
      'poet': <String, Object?>{'en': 'Muktanand Swami'},
      'categoryId': collections['kirtan_categories'] is Map
          ? (collections['kirtan_categories']! as Map<String, Object?>)
                .keys
                .first
          : 'aarti',
      'audioUrl': 'https://example.com/k$i.mp3',
      'durationSec': 300,
      'isFeatured': true,
      'order': i,
    });
  }
  await db.collection('books').doc('vachanamrut').set(<String, Object?>{
    'title': <String, Object?>{'en': 'Vachanamrut', 'gu': 'વચનામૃત'},
    'author': 'Bhagwan Shree Swaminarayan',
    'pdfUrl': 'https://example.com/vachanamrut.pdf',
    'language': 'gu',
    'pageCount': 700,
  });
  await db.collection('events').doc('upcoming-katha').set(<String, Object?>{
    'title': <String, Object?>{'en': 'Shrimad Bhagwat Katha'},
    'shortDescription': 'Seven days of katha',
    'description': 'All devotees are welcome.',
    'startAt': Timestamp.fromDate(now.add(const Duration(days: 3))),
    'endAt': Timestamp.fromDate(now.add(const Duration(days: 9))),
    'type': 'katha',
  });
  for (int i = 1; i <= 5; i++) {
    await db
        .collection('albums')
        .doc('avsar-200')
        .collection('photos')
        .doc('p$i')
        .set(<String, Object?>{
          'url': 'https://example.com/avsar/$i.jpg',
          'order': i,
        });
  }
  await db.collection('config').doc('donation').set(<String, Object?>{
    'enabled': true,
    'upiId': 'jetalpurdham@upi',
    'payeeName': 'Shree Swaminarayan Mandir Jetalpur',
    'bank': <String, Object?>{
      'accountName': 'Shree Swaminarayan Mandir',
      'accountNumber': '000123456789',
      'ifsc': 'SBIN0000001',
      'bankName': 'State Bank of India',
    },
    'contactPhone': '9999999999',
  }, SetOptions(merge: true));
  return db;
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  String initialLocation = Routes.splash,
  FakeFirebaseFirestore? firestore,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    // Skip the one-time notification prompt.
    PrefKeys.notificationPromptShown: true,
  });
  PackageInfo.setMockInitialValues(
    appName: 'Jetalpur Dham',
    packageName: 'com.jetalpurdham.app',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final FakeFirebaseFirestore db = firestore ?? await _seededFirestore();
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final GoRouter router = createRouter(initialLocation: initialLocation);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreProvider.overrideWithValue(db),
        isOnlineProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
        placesMapEnabledProvider.overrideWithValue(false),
        kirtanPlayerProvider.overrideWith(_IdlePlayer.new),
        kirtanIsPlayingProvider.overrideWithValue(false),
        kirtanIsLoadingProvider.overrideWithValue(false),
        kirtanHasNextProvider.overrideWithValue(false),
        kirtanProgressProvider.overrideWith(
          (Ref ref) => Stream<KirtanProgress>.value(const KirtanProgress()),
        ),
        kirtanShuffleProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(false),
        ),
        kirtanLoopModeProvider.overrideWith(
          (Ref ref) => Stream<LoopMode>.value(LoopMode.off),
        ),
        kirtanSpeedProvider.overrideWith((Ref ref) => Stream<double>.value(1)),
      ],
      child: JetalpurDhamApp(router: router),
    ),
  );
  await _settle(tester);
  return router;
}

/// Shimmer and equalizer animations never stop, so pump in fixed steps.
Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _visit(
  WidgetTester tester,
  GoRouter router,
  String location,
) async {
  router.go(location);
  await _settle(tester);
  expect(tester.takeException(), isNull, reason: 'while showing $location');
}

void main() {
  testWidgets('splash opens Home, then every tab and screen renders', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(tester);

    // Splash → Home after its minimum display time.
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.home);
    expect(find.text('Jetalpur Dham'), findsWidgets);

    // Scroll through every Home section.
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -2000),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // Bottom navigation tabs.
    for (final String label in <String>[
      'Kirtan',
      'Prasadi',
      'Shastra',
      'Utsav',
      'Home',
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'tab $label');
    }

    // Every secondary and detail screen, including deep links.
    for (final String location in <String>[
      Routes.gallery,
      Routes.album('avsar-200'),
      Routes.donate,
      Routes.about,
      Routes.settings,
      Routes.kirtanDownloads,
      Routes.places,
      Routes.place('nij-mandir-revati-baldevji'),
      Routes.library,
      Routes.book('vachanamrut'),
      Routes.events,
      Routes.event('upcoming-katha'),
      Routes.event('does-not-exist'),
      '/no/such/route',
      Routes.home,
    ]) {
      await _visit(tester, router, location);
    }
  });

  testWidgets('drawer and language switcher work end to end', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(
      tester,
      initialLocation: Routes.kirtan,
    );

    // Open the drawer from the tab's menu button and go to Donate.
    await tester.tap(find.byTooltip('Menu').first);
    await _settle(tester);
    await tester.tap(find.text('Donate').last);
    await _settle(tester);
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.donate);

    // Switch to Gujarati from the top-right language button.
    await tester.tap(find.byTooltip('Choose language').first);
    await _settle(tester);
    await tester.tap(find.text('ગુજરાતી'));
    await _settle(tester);
    expect(find.text('દાન'), findsWidgets);

    // The whole app now renders in Gujarati, then Hindi.
    for (final String location in <String>[
      Routes.home,
      Routes.events,
      Routes.places,
    ]) {
      await _visit(tester, router, location);
    }
    expect(find.text('ઉત્સવ'), findsWidgets);

    await tester.tap(find.byTooltip('ભાષા પસંદ કરો').first);
    await _settle(tester);
    await tester.tap(find.text('हिन्दी'));
    await _settle(tester);
    await _visit(tester, router, Routes.home);
    expect(find.text('उत्सव'), findsWidgets);
  });

  testWidgets('dark mode renders every tab', (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final GoRouter router = await _pumpApp(
      tester,
      initialLocation: Routes.home,
    );
    for (final String location in <String>[
      Routes.kirtan,
      Routes.places,
      Routes.library,
      Routes.events,
      Routes.donate,
      Routes.home,
    ]) {
      await _visit(tester, router, location);
    }
  });

  testWidgets('Android back closes the drawer first, on a tab and on a page', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(
      tester,
      initialLocation: Routes.kirtan,
    );
    String path() => router.routerDelegate.currentConfiguration.uri.path;
    bool drawerOpen() => shellScaffoldKey.currentState!.isDrawerOpen;
    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await _settle(tester);
    }

    // On a tab other than Home: close the drawer, then go Home.
    await tester.tap(find.byTooltip('Menu').first);
    await _settle(tester);
    expect(drawerOpen(), isTrue);
    await back();
    expect(drawerOpen(), isFalse);
    expect(path(), Routes.kirtan);
    await back();
    expect(path(), Routes.home);

    // On a page inside a tab: close the drawer, then leave the page.
    router.go(Routes.kirtanDownloads);
    await _settle(tester);
    shellScaffoldKey.currentState!.openDrawer();
    await _settle(tester);
    expect(drawerOpen(), isTrue);
    await back();
    expect(drawerOpen(), isFalse);
    expect(path(), Routes.kirtanDownloads);
    await back();
    expect(path(), Routes.kirtan);

    // A full-screen page above the shell is closed first.
    shellScaffoldKey.currentState!.openDrawer();
    await _settle(tester);
    unawaited(router.push<void>(Routes.player));
    await _settle(tester);
    expect(router.state.uri.path, Routes.player);
    await back();
    expect(router.state.uri.path, Routes.kirtan);
    expect(drawerOpen(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings sends feedback with app version and platform', (
    WidgetTester tester,
  ) async {
    final List<String> launched = <String>[];
    const MethodChannel urlLauncher = MethodChannel(
      'plugins.flutter.io/url_launcher',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      urlLauncher,
      (MethodCall call) async {
        if (call.method != 'launch') return null;
        launched.add(
          (call.arguments as Map<Object?, Object?>)['url']! as String,
        );
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        urlLauncher,
        null,
      ),
    );
    final FakeFirebaseFirestore db = await _seededFirestore();
    await _pumpApp(tester, initialLocation: Routes.settings, firestore: db);

    // The seed has no e-mail or WhatsApp number yet.
    expect(find.text('Send feedback'), findsNothing);

    await db.collection('config').doc('app').update(<String, Object?>{
      'email': 'office@example.org',
    });
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.text('Send feedback'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Send feedback'));
    await _settle(tester);

    expect(launched, hasLength(1));
    final Uri mail = Uri.parse(launched.single);
    expect(mail.scheme, 'mailto');
    expect(mail.path, 'office@example.org');
    expect(
      mail.queryParameters['subject'],
      'Feedback on the Jetalpur Dham app',
    );
    expect(mail.queryParameters['body'], contains('Version 1.0.0 (1)'));
    expect(mail.queryParameters['body'], contains('Android · '));
    expect(tester.takeException(), isNull);
  });
}
