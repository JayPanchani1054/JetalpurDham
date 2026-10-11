import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/place_queries.dart';
import '../../domain/prasadi_place.dart';
import 'place_cards.dart';
import 'place_map_style.dart';
import 'place_ui.dart';

/// Google Map with a saffron pin per place and a swipeable card carousel at
/// the bottom. The two stay in sync: swiping a card flies the camera to that
/// place and opens its info window; tapping a pin brings its card into view.
///
/// If the map itself cannot load (e.g. no Maps API key) the carousel still
/// works on its own, and the list view is one tap away in the app bar.
class PlacesMapView extends ConsumerStatefulWidget {
  const PlacesMapView({super.key, required this.places});

  final List<PrasadiPlace> places;

  @override
  ConsumerState<PlacesMapView> createState() => _PlacesMapViewState();
}

class _PlacesMapViewState extends ConsumerState<PlacesMapView> {
  /// Closest zoom when fitting several places / focusing one place.
  static const double _maxFitZoom = 19;
  static const double _focusZoom = 17;

  GoogleMapController? _map;
  PageController? _pages;
  String? _selectedId;
  bool _syncingFromMap = false;
  MapType _mapType = MapType.normal;
  double _zoom = _focusZoom;
  CameraPosition? _initialCamera;
  Size _mapSize = Size.zero;
  EdgeInsets _mapPadding = EdgeInsets.zero;

  List<PrasadiPlace>? _markerSource;
  String? _markerLanguage;
  Set<Marker> _markers = const <Marker>{};

  List<PrasadiPlace> get _places => widget.places;

  int get _selectedIndex {
    final int index = _places.indexWhere(
      (PrasadiPlace p) => p.id == _selectedId,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(PlacesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedId != null &&
        findPlace(_places, _selectedId!) == null &&
        _places.isNotEmpty) {
      // The selected place was removed by the temple: go back to the first.
      _selectedId = null;
      final PageController? pages = _pages;
      if (pages != null && pages.hasClients) pages.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pages?.dispose();
    // The GoogleMap widget disposes its own controller.
    _map = null;
    super.dispose();
  }

  // ---------------------------------------------------------------- camera

  CameraPosition _fitCamera() {
    final GeoBounds? bounds = GeoBounds.around(
      _places.map((PrasadiPlace p) => p.location).nonNulls,
    );
    if (bounds == null) {
      final AppConfig config = ref.read(appConfigValueProvider);
      return CameraPosition(
        target: LatLng(
          config.latitude ?? AppConfig.fallback.latitude!,
          config.longitude ?? AppConfig.fallback.longitude!,
        ),
        zoom: 16,
      );
    }
    final bool single =
        bounds.south == bounds.north && bounds.west == bounds.east;
    final GeoCoordinate center = bounds.center;
    return CameraPosition(
      target: LatLng(center.latitude, center.longitude),
      zoom: single
          ? _focusZoom
          : fitZoom(
              bounds: bounds,
              width: _mapSize.width - _mapPadding.horizontal,
              height: _mapSize.height - _mapPadding.vertical,
              padding: 56,
              maxZoom: _maxFitZoom,
            ),
    );
  }

  Future<void> _showAll() async {
    unawaited(HapticFeedback.selectionClick());
    final GoogleMapController? map = _map;
    if (map == null) return;
    try {
      await map.animateCamera(CameraUpdate.newCameraPosition(_fitCamera()));
    } catch (error) {
      AppLogger.info('Places map: show all failed: $error');
    }
  }

  Future<void> _focus(PrasadiPlace place) async {
    final GoogleMapController? map = _map;
    final GeoCoordinate? at = place.location;
    if (map == null || at == null) return;
    try {
      await map.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(at.latitude, at.longitude),
          math.max(_zoom, _focusZoom),
        ),
      );
      if (!mounted || _selectedId != place.id || !identical(map, _map)) {
        return;
      }
      await map.showMarkerInfoWindow(MarkerId(place.id));
    } catch (error) {
      // Map not ready, disposed or marker not yet added: nothing to do.
      AppLogger.info('Places map: focus failed: $error');
    }
  }

  void _toggleMapType() {
    unawaited(HapticFeedback.selectionClick());
    setState(
      () => _mapType = _mapType == MapType.normal
          ? MapType.hybrid
          : MapType.normal,
    );
  }

  // ------------------------------------------------------------ sync logic

  void _onPageChanged(int index) {
    if (index < 0 || index >= _places.length) return;
    final PrasadiPlace place = _places[index];
    if (place.id != _selectedId) setState(() => _selectedId = place.id);
    if (!_syncingFromMap) unawaited(_focus(place));
  }

  void _onMarkerTap(String placeId) {
    final int index = _places.indexWhere((PrasadiPlace p) => p.id == placeId);
    if (index < 0) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _selectedId = placeId);
    unawaited(_showCard(index));
  }

  Future<void> _showCard(int index) async {
    final PageController? pages = _pages;
    if (pages == null || !pages.hasClients) return;
    final int current = pages.page?.round() ?? 0;
    if (current == index) return;
    // The map already moved to the tapped pin; don't move it again for
    // every card that passes by during the carousel animation.
    _syncingFromMap = true;
    try {
      if ((current - index).abs() > 2) {
        pages.jumpToPage(index);
      } else {
        await pages.animateToPage(
          index,
          duration: AppDurations.slow,
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _syncingFromMap = false;
    }
  }

  void _open(PrasadiPlace place) {
    unawaited(HapticFeedback.selectionClick());
    context.go(Routes.place(place.id));
  }

  Set<Marker> _markersFor(AppLocalizations l10n, String language) {
    if (identical(_markerSource, _places) && _markerLanguage == language) {
      return _markers;
    }
    _markerSource = _places;
    _markerLanguage = language;
    final BitmapDescriptor icon = BitmapDescriptor.defaultMarkerWithHue(
      kPlaceMarkerHue,
    );
    _markers = <Marker>{
      for (final PrasadiPlace place in _places)
        if (place.location case final GeoCoordinate at)
          Marker(
            markerId: MarkerId(place.id),
            position: LatLng(at.latitude, at.longitude),
            icon: icon,
            infoWindow: InfoWindow(
              title: place.name.resolve(language),
              snippet: l10n.placesTapForMahima,
              onTap: () {
                if (mounted) _open(place);
              },
            ),
            onTap: () => _onMarkerTap(place.id),
          ),
    };
    return _markers;
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String language = Localizations.localeOf(context).languageCode;
    final double cardHeight = placeCarouselCardHeight(context);
    final int selectedIndex = _selectedIndex;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _mapSize = constraints.biggest;
        _mapPadding = EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: cardHeight + AppSpacing.lg * 2,
        );
        _initialCamera ??= _fitCamera();
        _pages ??= PageController(
          viewportFraction: (math.min(440.0, _mapSize.width - 40) /
                  math.max(1.0, _mapSize.width))
              .clamp(0.5, 0.9),
          initialPage: selectedIndex,
        );

        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: _initialCamera!,
                onMapCreated: (GoogleMapController controller) =>
                    _map = controller,
                markers: _markersFor(l10n, language),
                mapType: _mapType,
                style: placeMapStyleFor(context),
                padding: _mapPadding,
                minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
                onCameraMove: (CameraPosition position) =>
                    _zoom = position.zoom,
                // Location is never requested (no permission prompt).
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                // The map owns every gesture over it (e.g. no accidental
                // drawer swipe while panning).
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                },
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Column(
                children: <Widget>[
                  _MapButton(
                    icon: Icons.zoom_out_map_rounded,
                    tooltip: l10n.placesShowAll,
                    onPressed: _showAll,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MapButton(
                    icon: _mapType == MapType.normal
                        ? Icons.satellite_alt_rounded
                        : Icons.map_rounded,
                    tooltip: _mapType == MapType.normal
                        ? l10n.placesSatellite
                        : l10n.placesMapView,
                    onPressed: _toggleMapType,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              height: cardHeight,
              child: PageView.builder(
                controller: _pages,
                itemCount: _places.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (BuildContext context, int index) {
                  final PrasadiPlace place = _places[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs + 2,
                    ),
                    child: PlaceCarouselCard(
                      place: place,
                      selected: index == selectedIndex,
                      onTap: () => _open(place),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Round floating button on top of the map.
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black38,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        color: scheme.onSurface,
        onPressed: onPressed,
      ),
    );
  }
}
