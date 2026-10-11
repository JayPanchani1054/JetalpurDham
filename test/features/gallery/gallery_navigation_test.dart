import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jetalpur_dham/core/config/app_config.dart';
import 'package:jetalpur_dham/core/firebase/media_url.dart';
import 'package:jetalpur_dham/core/l10n/app_language.dart';
import 'package:jetalpur_dham/core/l10n/l10n.dart';
import 'package:jetalpur_dham/core/router/routes.dart';
import 'package:jetalpur_dham/core/services/connectivity_service.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/theme/app_theme.dart';
import 'package:jetalpur_dham/features/gallery/data/gallery_repository.dart';
import 'package:jetalpur_dham/features/gallery/domain/gallery_models.dart';
import 'package:jetalpur_dham/features/gallery/presentation/album_screen.dart';
import 'package:jetalpur_dham/features/gallery/presentation/gallery_screen.dart';
import 'package:jetalpur_dham/features/gallery/presentation/photo_viewer_screen.dart';
import 'package:jetalpur_dham/features/gallery/presentation/widgets/album_card.dart';
import 'package:jetalpur_dham/features/gallery/presentation/widgets/home_gallery_preview.dart';
import 'package:jetalpur_dham/features/gallery/presentation/widgets/photo_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navigates through the gallery with a router shaped like the app's: a
/// stateful shell branch (home → gallery → album) and the photo viewer on the
/// root navigator. Catches routing mistakes and duplicate hero tags across
/// nested navigators.

final Album _album = Album.fromMap('avsar-200', <String, Object?>{
  'title': 'Avsar 200',
  'coverUrl': 'gallery/avsar-200/cover.jpg',
  'photoCount': 30,
});

final List<AlbumPhoto> _photos = <AlbumPhoto>[
  for (int i = 0; i < 30; i++)
    AlbumPhoto.fromMap('p$i', <String, Object?>{
      'url': 'gallery/avsar-200/p$i.jpg',
      'order': i,
    }),
];

GoRouter _router(String initialLocation) {
  final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (_, _, StatefulNavigationShell shell) => Scaffold(body: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const Scaffold(
                  body: SingleChildScrollView(child: HomeGalleryPreview()),
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'gallery',
                    builder: (_, _) => const GalleryScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: ':albumId',
                        builder: (_, GoRouterState state) => AlbumScreen(
                          albumId: state.pathParameters['albumId']!,
                        ),
                        routes: <RouteBase>[
                          GoRoute(
                            path: 'photo',
                            parentNavigatorKey: rootKey,
                            builder: (_, GoRouterState state) =>
                                PhotoViewerScreen(
                                  albumId: state.pathParameters['albumId']!,
                                  initialIndex:
                                      int.tryParse(
                                        state.uri.queryParameters['i'] ?? '',
                                      ) ??
                                      0,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/other',
                builder: (_, _) => const Scaffold(
                  body: SingleChildScrollView(child: HomeGalleryPreview()),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<GoRouter> _pumpApp(WidgetTester tester, String location) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    PrefKeys.language: AppLanguage.en.code,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = const Size(390, 844) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final GoRouter router = _router(location);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWith(
          (Ref ref) => Stream<AppConfig>.value(AppConfig.fallback),
        ),
        albumsProvider.overrideWith(
          (Ref ref) =>
              Stream<LiveList<Album>>.value(LiveList<Album>(<Album>[_album])),
        ),
        albumLookupProvider.overrideWith(
          (Ref ref, String id) => Stream<AlbumLookup>.value(
            AlbumLookup(id == _album.id ? _album : null),
          ),
        ),
        albumPhotosProvider.overrideWith(
          (Ref ref, String id) => Stream<LiveList<AlbumPhoto>>.value(
            LiveList<AlbumPhoto>(
              id == _album.id ? _photos : const <AlbumPhoto>[],
            ),
          ),
        ),
        mediaUrlProvider.overrideWith(
          (Ref ref, String raw) => Completer<String>().future,
        ),
        isOnlineProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(AppLanguage.en),
        locale: AppLanguage.en.locale,
        supportedLocales: AppLanguage.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
      ),
    ),
  );
  await _frames(tester);
  return router;
}

Future<void> _frames(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('gallery → album → photo → back', (WidgetTester tester) async {
    final GoRouter router = await _pumpApp(tester, Routes.gallery);
    expect(find.text('Photo Gallery'), findsOneWidget);

    await tester.tap(find.widgetWithText(AlbumCard, 'Avsar 200'));
    await _frames(tester);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.album('avsar-200'),
    );
    expect(find.text('Select'), findsOneWidget);

    await tester.tap(find.byType(PhotoTile).at(3));
    await _frames(tester);
    expect(find.text('4 / 30'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close'));
    await _frames(tester);
    expect(find.text('4 / 30'), findsNothing);
    expect(find.text('Select'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home strip opens the viewer and returns home', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, Routes.home);
    expect(find.text('Avsar 200 Photos'), findsOneWidget);

    await tester.tap(find.byType(PhotoTile).at(1));
    await _frames(tester);
    expect(find.text('2 / 30'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await _frames(tester);
    expect(find.text('Avsar 200 Photos'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('See all').first);
    await _frames(tester);
    expect(find.text('Select'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing twice only closes the viewer', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, Routes.home);
    await tester.tap(find.byType(PhotoTile).at(1));
    await _frames(tester);
    expect(find.text('2 / 30'), findsOneWidget);

    // Two close requests before the next frame (a screen-reader double
    // activation, or a swipe-down ending as the button is pressed). Taps
    // are absorbed by the Navigator, semantic actions are not. The second
    // request must not re-route the app to the album.
    final IconButton close = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close_rounded),
    );
    close.onPressed!();
    close.onPressed!();
    await _frames(tester);
    expect(find.text('2 / 30'), findsNothing);
    expect(find.text('Avsar 200 Photos'), findsOneWidget);
    expect(find.text('Select'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep link to a photo, then back to its album', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, Routes.photo('avsar-200', 4));
    expect(find.text('5 / 30'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await _frames(tester);
    expect(find.text('Select'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back while selecting leaves selection mode first', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, Routes.album('avsar-200'));
    await tester.longPress(find.byType(PhotoTile).first);
    await _frames(tester);
    expect(find.text('1 selected'), findsOneWidget);

    final NavigatorState navigator = tester.state<NavigatorState>(
      find
          .ancestor(
            of: find.byType(AlbumScreen),
            matching: find.byType(Navigator),
          )
          .first,
    );
    await navigator.maybePop();
    await _frames(tester);
    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Select'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
