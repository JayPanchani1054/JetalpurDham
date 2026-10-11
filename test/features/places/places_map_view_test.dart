import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// The fake map below implements the platform interface google_maps_flutter is
// built on (a dev dependency); it is not re-exported by google_maps_flutter.
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:jetalpur_dham/core/config/app_config.dart';
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
import 'package:jetalpur_dham/features/places/presentation/place_detail_screen.dart';
import 'package:jetalpur_dham/features/places/presentation/places_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises the interactive map (normally a native view) against a fake
/// Google Maps platform: markers, card ↔ pin syncing, camera moves, the
/// info window link, the map type switch and the map/list toggle.

const LatLng _sarovar = LatLng(22.88915, 72.59595);
const LatLng _yagnashala = LatLng(22.88975, 72.59585);

final List<PrasadiPlace> _places = <PrasadiPlace>[
  PrasadiPlace.fromMap('dev-sarovar', <String, Object?>{
    'name': 'Dev Sarovar',
    'shortDescription': 'The sacred lake',
    'mahima': 'Shreeji Maharaj bathed here with the sants.',
    'location': GeoPoint(_sarovar.latitude, _sarovar.longitude),
    'category': 'water',
    'order': 1,
  }),
  PrasadiPlace.fromMap('yagnashala', <String, Object?>{
    'name': 'Yagnashala',
    'location': GeoPoint(_yagnashala.latitude, _yagnashala.longitude),
    'category': 'yagna',
    'order': 2,
  }),
  // No location: shown in the carousel, but without a pin.
  PrasadiPlace.fromMap('prasadi-vastu', <String, Object?>{
    'name': 'Prasadi Vastu',
    'order': 3,
  }),
];

class _OfflineResolver implements MediaUrlResolver {
  @override
  Future<String> resolve(String raw) =>
      Future<String>.error(StateError('offline in tests'));
}

/// Records what the app asks the native map to do and lets the test send
/// native events (marker / info window taps).
class _FakeMapsPlatform extends GoogleMapsFlutterPlatform {
  final StreamController<MapEvent<Object?>> _events =
      StreamController<MapEvent<Object?>>.broadcast();

  final List<int> mapIds = <int>[];
  final Map<int, Set<Marker>> initialMarkers = <int, Set<Marker>>{};
  final List<CameraUpdate> cameraUpdates = <CameraUpdate>[];
  final List<MarkerId> shownInfoWindows = <MarkerId>[];
  final List<MapConfiguration> configurationUpdates = <MapConfiguration>[];

  int get firstMapId => mapIds.first;

  void send(MapEvent<Object?> event) => _events.add(event);

  Future<void> close() => _events.close();

  Stream<T> _on<T>() =>
      _events.stream.where((MapEvent<Object?> e) => e is T).cast<T>();

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapObjects mapObjects = const MapObjects(),
    MapConfiguration mapConfiguration = const MapConfiguration(),
  }) {
    if (!mapIds.contains(creationId)) {
      mapIds.add(creationId);
      initialMarkers[creationId] = mapObjects.markers;
      onPlatformViewCreated(creationId);
    }
    return const ColoredBox(color: Color(0xFFDDEEDD));
  }

  @override
  Future<void> init(int mapId) async {}

  @override
  void dispose({required int mapId}) {}

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async => configurationUpdates.add(configuration);

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async => cameraUpdates.add(cameraUpdate);

  @override
  Future<void> animateCameraWithConfiguration(
    CameraUpdate cameraUpdate,
    CameraUpdateAnimationConfiguration configuration, {
    required int mapId,
  }) async => cameraUpdates.add(cameraUpdate);

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async => cameraUpdates.add(cameraUpdate);

  @override
  Future<void> showMarkerInfoWindow(
    MarkerId markerId, {
    required int mapId,
  }) async => shownInfoWindows.add(markerId);

  @override
  Future<void> hideMarkerInfoWindow(
    MarkerId markerId, {
    required int mapId,
  }) async {}

  @override
  Future<bool> isMarkerInfoWindowShown(
    MarkerId markerId, {
    required int mapId,
  }) async => false;

  @override
  Future<double> getZoomLevel({required int mapId}) async => 17;

  @override
  Future<Uint8List?> takeSnapshot({required int mapId}) async => null;

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      _on<CameraMoveStartedEvent>();

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) =>
      _on<CameraMoveEvent>();

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      _on<CameraIdleEvent>();

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      _on<MarkerTapEvent>();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      _on<InfoWindowTapEvent>();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      _on<MarkerDragStartEvent>();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      _on<MarkerDragEvent>();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      _on<MarkerDragEndEvent>();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      _on<PolylineTapEvent>();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      _on<PolygonTapEvent>();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      _on<CircleTapEvent>();

  @override
  Stream<PointOfInterestTapEvent> onPointOfInterestTap({required int mapId}) =>
      _on<PointOfInterestTapEvent>();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => _on<MapTapEvent>();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      _on<MapLongPressEvent>();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      _on<ClusterTapEvent>();

  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) =>
      _on<GroundOverlayTapEvent>();
}

Future<_FakeMapsPlatform> _pumpPlacesTab(WidgetTester tester) async {
  final GoogleMapsFlutterPlatform original = GoogleMapsFlutterPlatform.instance;
  final _FakeMapsPlatform fake = _FakeMapsPlatform();
  GoogleMapsFlutterPlatform.instance = fake;
  addTearDown(() async {
    GoogleMapsFlutterPlatform.instance = original;
    await fake.close();
  });

  SharedPreferences.setMockInitialValues(<String, Object>{
    PrefKeys.language: AppLanguage.en.code,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = const Size(390, 844) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final GoRouter router = GoRouter(
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
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOnlineProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
        placesProvider.overrideWith(
          (Ref ref) => Stream<List<PrasadiPlace>>.value(_places),
        ),
        placesMapEnabledProvider.overrideWithValue(true),
        appConfigValueProvider.overrideWithValue(AppConfig.fallback),
        mediaUrlResolverProvider.overrideWithValue(_OfflineResolver()),
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
  await _settle(tester);
  return fake;
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

double _carouselPage(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!;

void main() {
  testWidgets('map shows a saffron pin per located place, framed to fit', (
    WidgetTester tester,
  ) async {
    final _FakeMapsPlatform fake = await _pumpPlacesTab(tester);

    expect(fake.mapIds, hasLength(1));
    final Set<Marker> markers = fake.initialMarkers[fake.firstMapId]!;
    expect(
      markers.map((Marker m) => m.markerId.value),
      unorderedEquals(<String>['dev-sarovar', 'yagnashala']),
    );
    final Marker sarovar = markers.firstWhere(
      (Marker m) => m.markerId.value == 'dev-sarovar',
    );
    expect(sarovar.position, _sarovar);
    expect(sarovar.infoWindow.title, 'Dev Sarovar');
    expect(sarovar.infoWindow.snippet, 'Tap to read the mahima');

    // The carousel lists every place, including the one without a pin.
    expect(find.text('Dev Sarovar'), findsOneWidget);
    expect(find.byTooltip('Show all places'), findsOneWidget);
    expect(find.byTooltip('List'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping a card flies to its pin and opens the info window', (
    WidgetTester tester,
  ) async {
    final _FakeMapsPlatform fake = await _pumpPlacesTab(tester);
    expect(fake.cameraUpdates, isEmpty);

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await _settle(tester);

    expect(_carouselPage(tester), 1);
    final CameraUpdate update = fake.cameraUpdates.last;
    expect(update, isA<CameraUpdateNewLatLngZoom>());
    expect((update as CameraUpdateNewLatLngZoom).latLng, _yagnashala);
    expect(update.zoom, greaterThanOrEqualTo(17));
    expect(fake.shownInfoWindows.last, const MarkerId('yagnashala'));

    // A place without a location keeps the camera where it is.
    final int moves = fake.cameraUpdates.length;
    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await _settle(tester);
    expect(_carouselPage(tester), 2);
    expect(find.text('Prasadi Vastu'), findsOneWidget);
    expect(fake.cameraUpdates, hasLength(moves));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a pin brings its card into view without a 2nd move', (
    WidgetTester tester,
  ) async {
    final _FakeMapsPlatform fake = await _pumpPlacesTab(tester);

    fake.send(MarkerTapEvent(fake.firstMapId, const MarkerId('yagnashala')));
    await _settle(tester);
    expect(_carouselPage(tester), 1);
    // Google Maps itself centres a tapped pin; the carousel must not move
    // the camera again.
    expect(fake.cameraUpdates, isEmpty);

    // Info window tap opens the place.
    fake.send(
      InfoWindowTapEvent(fake.firstMapId, const MarkerId('yagnashala')),
    );
    await _settle(tester);
    expect(find.text('Directions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('show all, satellite switch, and map/list toggle', (
    WidgetTester tester,
  ) async {
    final _FakeMapsPlatform fake = await _pumpPlacesTab(tester);

    await tester.tap(find.byTooltip('Show all places'));
    await _settle(tester);
    expect(fake.cameraUpdates.last, isA<CameraUpdateNewCameraPosition>());

    await tester.tap(find.byTooltip('Satellite'));
    await _settle(tester);
    expect(fake.configurationUpdates.last.mapType, MapType.hybrid);
    expect(find.byTooltip('Map'), findsWidgets);

    // List view, then back to the map.
    await tester.tap(find.byTooltip('List'));
    await _settle(tester);
    expect(
      find.text('Places blessed by Shree Swaminarayan Bhagwan'),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsNothing);

    await tester.tap(find.byTooltip('Map').first);
    await _settle(tester);
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a card opens the detail with the map preview', (
    WidgetTester tester,
  ) async {
    final _FakeMapsPlatform fake = await _pumpPlacesTab(tester);

    await tester.tap(find.text('Dev Sarovar'));
    await _settle(tester);
    expect(find.text('Mahima'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Open in Google Maps'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // The detail page created its own small (lite) map with one pin.
    expect(fake.mapIds, hasLength(2));
    expect(fake.initialMarkers[fake.mapIds.last]!.single.position, _sarovar);
    expect(tester.takeException(), isNull);
  });
}
