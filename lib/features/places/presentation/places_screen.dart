import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/menu_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/places_view_mode.dart';
import '../data/places_repository.dart';
import '../domain/prasadi_place.dart';
import 'widgets/places_list_view.dart';
import 'widgets/places_map_view.dart';
import 'widgets/places_skeletons.dart';

/// Prasadi tab: the sacred places on a map (default) or as a list.
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool mapEnabled = ref.watch(placesMapEnabledProvider);
    final bool showMap =
        mapEnabled &&
        ref.watch(placesViewModeProvider) == PlacesViewMode.map;
    final AsyncValue<List<PrasadiPlace>> places = ref.watch(placesProvider);
    final bool offline = !(ref.watch(isOnlineProvider).value ?? true);

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: Text(l10n.placesTitle),
        actions: <Widget>[
          if (mapEnabled)
            IconButton(
              tooltip: showMap ? l10n.placesListView : l10n.placesMapView,
              icon: Icon(
                showMap ? Icons.view_agenda_outlined : Icons.map_outlined,
              ),
              onPressed: () {
                unawaited(HapticFeedback.selectionClick());
                ref.read(placesViewModeProvider.notifier).toggle();
              },
            ),
          const LanguageButton(),
        ],
      ),
      body: AsyncValueView<List<PrasadiPlace>>(
        value: places,
        onRetry: () => ref.invalidate(placesProvider),
        loading: showMap
            ? const PlacesMapSkeleton()
            : const PlacesListSkeleton(),
        isEmpty: (List<PrasadiPlace> list) => list.isEmpty,
        // Never loaded and offline: say so instead of "coming soon".
        empty: offline
            ? EmptyState(
                icon: Icons.wifi_off_rounded,
                title: l10n.errorNetwork,
                action: FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(placesProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
              )
            : EmptyState(
                icon: Icons.temple_hindu_outlined,
                title: l10n.placesEmpty,
                message: l10n.placesSubtitle,
              ),
        data: (List<PrasadiPlace> list) => showMap
            ? PlacesMapView(places: list)
            : PlacesListView(places: list),
      ),
    );
  }
}
