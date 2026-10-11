import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time switch for the interactive Google Map. The map needs a Maps
/// API key on each platform (see docs/FIREBASE_SETUP.md); a build without one
/// can pass `--dart-define=PLACES_MAP=false` and the Prasadi tab then shows
/// the list, while Directions / Street View still open Google Maps.
const bool kPlacesMapEnabled = bool.fromEnvironment(
  'PLACES_MAP',
  defaultValue: true,
);

/// Whether in-app Google Maps widgets may be shown (overridden in tests).
final Provider<bool> placesMapEnabledProvider = Provider<bool>(
  (Ref ref) => kPlacesMapEnabled,
);

enum PlacesViewMode { map, list }

/// Map / list choice on the Prasadi tab. Kept for the app session so the tab
/// looks the same when the devotee comes back to it.
class PlacesViewModeNotifier extends Notifier<PlacesViewMode> {
  @override
  PlacesViewMode build() => ref.watch(placesMapEnabledProvider)
      ? PlacesViewMode.map
      : PlacesViewMode.list;

  void toggle() => state = state == PlacesViewMode.map
      ? PlacesViewMode.list
      : PlacesViewMode.map;
}

final NotifierProvider<PlacesViewModeNotifier, PlacesViewMode>
placesViewModeProvider =
    NotifierProvider<PlacesViewModeNotifier, PlacesViewMode>(
      PlacesViewModeNotifier.new,
    );
