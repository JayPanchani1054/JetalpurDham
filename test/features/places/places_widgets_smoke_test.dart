import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jetalpur_dham/core/firebase/media_url.dart';
import 'package:jetalpur_dham/core/l10n/app_language.dart';
import 'package:jetalpur_dham/core/l10n/l10n.dart';
import 'package:jetalpur_dham/core/router/routes.dart';
import 'package:jetalpur_dham/core/services/connectivity_service.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/theme/app_theme.dart';
import 'package:jetalpur_dham/features/places/application/places_view_mode.dart';
import 'package:jetalpur_dham/features/places/data/places_repository.dart';
import 'package:jetalpur_dham/features/places/domain/prasadi_place.dart';
import 'package:jetalpur_dham/features/places/presentation/panorama_screen.dart';
import 'package:jetalpur_dham/features/places/presentation/place_detail_screen.dart';
import 'package:jetalpur_dham/features/places/presentation/places_screen.dart';
import 'package:jetalpur_dham/features/places/presentation/widgets/home_places_preview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the Prasadi screens with fake data (no Firebase, no Google Maps
/// platform view, no network) to catch build errors and layout overflows,
/// including Gujarati content, large text and dark mode.

final String _longMahima = List<String>.filled(
  40,
  'Shreeji Maharaj sanctified this place during the great yagna.',
).join(' ');

final List<PrasadiPlace> _places = <PrasadiPlace>[
  PrasadiPlace.fromMap('dev-sarovar', <String, Object?>{
    'name': <String, Object?>{
      'en': 'Dev Sarovar (Jetalpur Lake)',
      'gu': 'દેવ સરોવર (જેતલપુરનું તળાવ)',
    },
    'shortDescription': <String, Object?>{
      'en': 'The sacred lake where Shreeji Maharaj bathed with the sants.',
      'gu': 'જ્યાં શ્રીજી મહારાજે સંતો સાથે સ્નાન કર્યું તે પવિત્ર સરોવર.',
    },
    'mahima': <String, Object?>{
      'en': _longMahima,
      'gu': 'મહિમા…\n$_longMahima',
    },
    'address': 'Jetalpur, Ahmedabad, Gujarat',
    'location': const GeoPoint(22.88915, 72.59595),
    'category': 'water',
    'images': <Object?>['places/dev-sarovar/1.jpg', 'places/dev-sarovar/2.jpg'],
    'panoramaUrls': <Object?>[
      'places/dev-sarovar/360-1.jpg',
      'places/dev-sarovar/360-2.jpg',
    ],
    'streetView': <String, Object?>{'heading': 120},
    'order': 1,
  }),
  PrasadiPlace.fromMap('yagnashala', <String, Object?>{
    'name': <String, Object?>{
      'en': 'Yagnashala – Yagnabhumi of Shreeji Maharaj',
      'gu': 'યજ્ઞશાળા – શ્રીજી મહારાજની યજ્ઞભૂમિ',
    },
    'category': 'yagna',
    'location': const GeoPoint(22.88975, 72.59585),
    'order': 2,
  }),
  PrasadiPlace.fromMap('prasadi-vastu', <String, Object?>{
    'name': 'Prasadi Vastu',
    'shortDescription': 'Sacred relics of Shreeji Maharaj',
    'order': 3,
  }),
];

/// Resolver that is always "offline", so Storage paths fail gracefully
/// (an [Error] is never retried by Riverpod, so no timers stay pending).
class _OfflineResolver implements MediaUrlResolver {
  @override
  Future<String> resolve(String raw) =>
      Future<String>.error(StateError('offline in tests'));
}

Future<void> _pump(
  WidgetTester tester,
  Widget? child, {
  GoRouter? router,
  List<PrasadiPlace>? places,
  bool online = true,
  Size size = const Size(390, 844),
  double textScale = 1,
  AppLanguage language = AppLanguage.en,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    PrefKeys.language: language.code,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOnlineProvider.overrideWith((Ref ref) => Stream<bool>.value(online)),
        placesProvider.overrideWith(
          (Ref ref) => Stream<List<PrasadiPlace>>.value(places ?? _places),
        ),
        placesMapEnabledProvider.overrideWithValue(false),
        mediaUrlResolverProvider.overrideWithValue(_OfflineResolver()),
      ],
      child: router == null
          ? MaterialApp(
              theme: AppTheme.light(language),
              darkTheme: AppTheme.dark(language),
              themeMode: themeMode,
              locale: language.locale,
              supportedLocales: AppLanguage.supportedLocales,
              localizationsDelegates: _delegates,
              builder: (BuildContext context, Widget? child) =>
                  _textScale(context, child, textScale),
              home: child,
            )
          : MaterialApp.router(
              theme: AppTheme.light(language),
              darkTheme: AppTheme.dark(language),
              themeMode: themeMode,
              locale: language.locale,
              supportedLocales: AppLanguage.supportedLocales,
              localizationsDelegates: _delegates,
              builder: (BuildContext context, Widget? child) =>
                  _textScale(context, child, textScale),
              routerConfig: router,
            ),
    ),
  );
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const List<LocalizationsDelegate<dynamic>> _delegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];

Widget _textScale(BuildContext context, Widget? child, double scale) =>
    MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child ?? const SizedBox.shrink(),
    );

/// Just the Prasadi routes, shaped like the app router (the 360° screen is
/// a child route of the place).
GoRouter _placesRouter() => GoRouter(
  initialLocation: Routes.places,
  routes: <RouteBase>[
    GoRoute(
      path: Routes.places,
      builder: (_, _) => const PlacesScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: ':placeId',
          builder: (_, GoRouterState state) =>
              PlaceDetailScreen(placeId: state.pathParameters['placeId']!),
          routes: <RouteBase>[
            GoRoute(
              path: 'panorama',
              builder: (_, GoRouterState state) => PanoramaScreen(
                placeId: state.pathParameters['placeId']!,
                initialIndex:
                    int.tryParse(state.uri.queryParameters['i'] ?? '') ?? 0,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The page's own scroll view (photo carousels are scrollables too).
Finder get _mainScrollable => find.byType(Scrollable).first;

void main() {
  testWidgets('Places tab lists places (map disabled → list only)', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const PlacesScreen());
    expect(find.text('Prasadi Places'), findsOneWidget);
    expect(find.text('Dev Sarovar (Jetalpur Lake)'), findsOneWidget);
    expect(find.text('Vav / Talav'), findsOneWidget);
    expect(find.text('Places blessed by Shree Swaminarayan Bhagwan'), findsOne);
    // No map/list toggle without the map.
    expect(find.byIcon(Icons.map_outlined), findsNothing);
    expect(find.byIcon(Icons.view_agenda_outlined), findsNothing);
    // The 360° badge marks places with 360° darshan.
    expect(find.text('360°'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Prasadi Vastu'),
      300,
      scrollable: _mainScrollable,
    );
    expect(find.text('Sacred relics of Shreeji Maharaj'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Places tab in Gujarati, small phone, large text, dark', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PlacesScreen(),
      size: const Size(320, 640),
      textScale: 1.4,
      language: AppLanguage.gu,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('દેવ સરોવર (જેતલપુરનું તળાવ)'), findsOneWidget);
    expect(find.text('વાવ / તળાવ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Places tab empty and offline states', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const PlacesScreen(), places: const <PrasadiPlace>[]);
    expect(find.text('Prasadi places will be added soon.'), findsOneWidget);

    await _pump(
      tester,
      const PlacesScreen(),
      places: const <PrasadiPlace>[],
      online: false,
    );
    expect(
      find.text('No internet connection. Please check your network.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Place detail shows actions, mahima and address', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const PlaceDetailScreen(placeId: 'dev-sarovar'));
    // Heading + the (hidden until collapsed) app bar title.
    expect(find.text('Dev Sarovar (Jetalpur Lake)'), findsNWidgets(2));
    expect(find.text('360° Darshan'), findsOneWidget);
    expect(find.text('Street View'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Mahima'),
      300,
      scrollable: _mainScrollable,
    );
    expect(find.text(_longMahima), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Open in Google Maps'),
      400,
      scrollable: _mainScrollable,
    );
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Jetalpur, Ahmedabad, Gujarat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Place detail without photos, mahima or panorama', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PlaceDetailScreen(placeId: 'prasadi-vastu'),
      size: const Size(320, 568),
      textScale: 1.4,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Prasadi Vastu'), findsNWidgets(2));
    expect(find.text('360° Darshan'), findsNothing);
    expect(find.text('Directions'), findsNothing);
    expect(find.text('Mahima'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Place detail in Gujarati with large text', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PlaceDetailScreen(placeId: 'dev-sarovar'),
      size: const Size(320, 640),
      textScale: 1.4,
      language: AppLanguage.gu,
    );
    await tester.scrollUntilVisible(
      find.text('૩૬૦° દર્શન'),
      200,
      scrollable: _mainScrollable,
    );
    expect(find.text('રસ્તો બતાવો'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('મહિમા'),
      300,
      scrollable: _mainScrollable,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unknown place shows the not-found state', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const PlaceDetailScreen(placeId: 'missing'));
    expect(find.text('This place is no longer available.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360° screen handles an unreachable photo gracefully', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PanoramaScreen(placeId: 'dev-sarovar', initialIndex: 7),
    );
    expect(find.text('Dev Sarovar (Jetalpur Lake)'), findsOneWidget);
    expect(find.text('Something went wrong. Please try again.'), findsOne);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Street View'), findsOneWidget);
    expect(find.bySemanticsLabel('View 2'), findsOneWidget);
    expect(find.byTooltip('Move phone to look around'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Retrying fails the same way without errors.
    await tester.tap(find.text('Retry'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Retry'), findsOneWidget);

    // Switching photo and toggling motion keep working.
    await tester.tap(find.bySemanticsLabel('View 1'));
    await tester.tap(find.byTooltip('Move phone to look around'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('360° screen for a place without panoramas', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const PanoramaScreen(placeId: 'yagnashala'));
    expect(find.text('This place is no longer available.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home preview shows cards and hides when empty', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: HomePlacesPreview())),
      textScale: 1.4,
    );
    expect(find.text('Prasadi Places'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('Dev Sarovar (Jetalpur Lake)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: HomePlacesPreview())),
      places: const <PrasadiPlace>[],
    );
    expect(find.text('Prasadi Places'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Navigation: list → detail (Hero) → 360° → back', (
    WidgetTester tester,
  ) async {
    final GoRouter router = _placesRouter();
    addTearDown(router.dispose);
    await _pump(tester, null, router: router);

    await tester.tap(find.text('Yagnashala – Yagnabhumi of Shreeji Maharaj'));
    await _settle(tester);
    expect(find.text('Directions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Back to the list (Hero flies back), then open the place with 360°.
    router.pop();
    await _settle(tester);
    await tester.tap(find.text('Dev Sarovar (Jetalpur Lake)'));
    await _settle(tester);
    expect(find.text('360° Darshan'), findsOneWidget);

    await tester.tap(find.text('360° Darshan'));
    await _settle(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await _settle(tester);
    expect(find.text('360° Darshan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
