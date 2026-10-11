import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../application/places_view_mode.dart';
import '../data/places_repository.dart';
import '../domain/place_queries.dart';
import '../domain/prasadi_place.dart';
import 'place_photo_viewer.dart';
import 'widgets/place_cards.dart';
import 'widgets/place_map_style.dart';
import 'widgets/place_ui.dart';

/// One prasadi place: photos, 360° darshan / Street View / Directions, the
/// full mahima, the address and a small map.
class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PrasadiPlace?> place = ref.watch(placeProvider(placeId));
    return place.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (PrasadiPlace? place) =>
          place == null ? const _NotFound() : _PlaceDetailView(place: place),
      loading: () => const _DetailSkeleton(),
      error: (_, _) => Scaffold(
        appBar: AppBar(actions: const <Widget>[LanguageButton()]),
        body: ErrorState(onRetry: () => ref.invalidate(placesProvider)),
      ),
    );
  }
}

class _PlaceDetailView extends ConsumerStatefulWidget {
  const _PlaceDetailView({required this.place});

  final PrasadiPlace place;

  @override
  ConsumerState<_PlaceDetailView> createState() => _PlaceDetailViewState();
}

class _PlaceDetailViewState extends ConsumerState<_PlaceDetailView> {
  final ScrollController _scroll = ScrollController();

  /// True once the photo header has scrolled away (app bar turns solid).
  final ValueNotifier<bool> _collapsed = ValueNotifier<bool>(false);
  double _collapseAt = 200;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _collapsed.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients) _collapsed.value = _scroll.offset > _collapseAt;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PrasadiPlace place = widget.place;
    final bool mapEnabled = ref.watch(placesMapEnabledProvider);
    final double headerHeight = (MediaQuery.sizeOf(context).width * 0.75).clamp(
      240.0,
      420.0,
    );
    _collapseAt = headerHeight - kToolbarHeight - AppSpacing.lg;

    final String mahima = place.mahima.of(context);
    final String address = place.address.of(context);

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: _collapsed,
            builder: (BuildContext context, bool collapsed, Widget? _) =>
                _HeaderAppBar(
                  place: place,
                  expandedHeight: headerHeight,
                  collapsed: collapsed,
                ),
          ),
          SliverToBoxAdapter(child: _Intro(place: place)),
          SliverToBoxAdapter(child: _Actions(place: place)),
          if (mahima.isNotEmpty)
            SliverToBoxAdapter(
              child: _Section(
                icon: Icons.auto_stories_rounded,
                title: l10n.placeMahima,
                child: SelectableText(
                  mahima,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    height: 1.8,
                  ),
                ),
              ),
            ),
          if (address.isNotEmpty || place.hasLocation)
            SliverToBoxAdapter(
              child: _Section(
                icon: Icons.location_on_rounded,
                title: l10n.placeAddress,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (address.isNotEmpty)
                      SelectableText(address, style: theme.textTheme.bodyLarge),
                    if (place.location case final GeoCoordinate at) ...<Widget>[
                      if (address.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),
                      _MapPreview(
                        place: place,
                        at: at,
                        interactiveMap: mapEnabled,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ header

class _HeaderAppBar extends StatelessWidget {
  const _HeaderAppBar({
    required this.place,
    required this.expandedHeight,
    required this.collapsed,
  });

  final PrasadiPlace place;
  final double expandedHeight;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
    final Color foreground = collapsed ? scheme.onSurface : Colors.white;
    final SystemUiOverlayStyle overlay = (collapsed && !dark)
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: foreground,
      iconTheme: IconThemeData(color: foreground),
      actionsIconTheme: IconThemeData(color: foreground),
      systemOverlayStyle: overlay.copyWith(statusBarColor: Colors.transparent),
      title: AnimatedOpacity(
        opacity: collapsed ? 1 : 0,
        duration: AppDurations.fast,
        child: Text(
          place.name.of(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      actions: <Widget>[
        Builder(
          builder: (BuildContext buttonContext) => IconButton(
            tooltip: context.l10n.share,
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _sharePlace(buttonContext, place),
          ),
        ),
        LanguageButton(foregroundColor: collapsed ? null : Colors.white),
      ],
      flexibleSpace: FlexibleSpaceBar(background: _HeaderMedia(place: place)),
    );
  }
}

/// Swipeable photos with page dots; tapping opens the zoomable viewer.
class _HeaderMedia extends StatefulWidget {
  const _HeaderMedia({required this.place});

  final PrasadiPlace place;

  @override
  State<_HeaderMedia> createState() => _HeaderMediaState();
}

class _HeaderMediaState extends State<_HeaderMedia> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = widget.place.images;
    final AppLocalizations l10n = context.l10n;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (images.isEmpty)
          Hero(
            tag: placeHeroTag(widget.place.id),
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: Center(
                child: Icon(
                  widget.place.category.icon,
                  size: 72,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          )
        else
          PageView.builder(
            controller: _pages,
            itemCount: images.length,
            onPageChanged: (int i) => setState(() => _page = i),
            itemBuilder: (BuildContext context, int i) {
              final Widget image = i == 0
                  // Only the visible first photo flies back to the card.
                  ? HeroMode(
                      enabled: _page == 0,
                      child: PlaceHeroImage(
                        placeId: widget.place.id,
                        url: images[i],
                        placeholderIcon: widget.place.category.icon,
                      ),
                    )
                  : AppNetworkImage(
                      url: images[i],
                      placeholderIcon: widget.place.category.icon,
                    );
              return Semantics(
                button: true,
                label: l10n.placePhotos,
                child: GestureDetector(
                  onTap: () => openPlacePhotoViewer(
                    context,
                    images: images,
                    initialIndex: i,
                  ),
                  child: image,
                ),
              );
            },
          ),
        // Keeps the back/share icons readable over bright photos.
        const IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x80000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.md,
            child: IgnorePointer(
              child: Center(
                child: _PageIndicator(count: images.length, index: _page),
              ),
            ),
          ),
        if (widget.place.hasPanorama)
          const Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: IgnorePointer(child: Place360Badge()),
          ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0x66000000),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        child: count > 8
            ? Text(
                '${index + 1} / $count',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: AppDurations.medium,
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == index ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == index ? Colors.white : Colors.white54,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ----------------------------------------------------------------- content

class _Intro extends StatelessWidget {
  const _Intro({required this.place});

  final PrasadiPlace place;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String short = place.shortDescription.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              place.name.of(context),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PlaceCategoryChip(category: place.category),
          if (short.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              short,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The three big actions: 360° Darshan, Street View and Directions.
class _Actions extends StatelessWidget {
  const _Actions({required this.place});

  final PrasadiPlace place;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final StreetViewTarget? streetView = place.streetViewTarget;
    final GeoCoordinate? location = place.location;

    final List<Widget> tiles = <Widget>[
      if (place.hasPanorama)
        _ActionTile(
          icon: Icons.threesixty_rounded,
          label: l10n.placeView360,
          primary: true,
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push(Routes.panorama(place.id)));
          },
        ),
      if (streetView != null)
        _ActionTile(
          icon: Icons.streetview_rounded,
          label: l10n.placeStreetView,
          primary: !place.hasPanorama,
          onTap: () => _launch(
            context,
            () => Launcher.streetView(
              streetView.coordinate.latitude,
              streetView.coordinate.longitude,
              heading: streetView.heading,
              pitch: streetView.pitch,
            ),
          ),
        ),
      if (location != null)
        _ActionTile(
          icon: Icons.directions_rounded,
          label: l10n.placeDirections,
          onTap: () => _launch(
            context,
            () => Launcher.directions(location.latitude, location.longitude),
          ),
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        0,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color background = primary ? scheme.primary : scheme.primaryContainer;
    final Color foreground = primary
        ? scheme.onPrimary
        : scheme.onPrimaryContainer;
    return Semantics(
      button: true,
      child: Material(
        color: background,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs + 2,
                vertical: AppSpacing.md,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 30, color: foreground),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xxl,
        AppSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Small static map with the place's pin; tapping opens Google Maps.
class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.place,
    required this.at,
    required this.interactiveMap,
  });

  final PrasadiPlace place;
  final GeoCoordinate at;
  final bool interactiveMap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final LatLng target = LatLng(at.latitude, at.longitude);
    return Semantics(
      button: true,
      label: l10n.placeOpenInMaps,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (interactiveMap)
                IgnorePointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: target,
                      zoom: 16.5,
                    ),
                    liteModeEnabled: true,
                    style: placeMapStyleFor(context),
                    markers: <Marker>{
                      Marker(
                        markerId: MarkerId(place.id),
                        position: target,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          kPlaceMarkerHue,
                        ),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                )
              else
                ColoredBox(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  child: Center(
                    child: Icon(
                      Icons.map_rounded,
                      size: 56,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => _launch(
                    context,
                    () => Launcher.mapLocation(
                      at.latitude,
                      at.longitude,
                      label: place.name.of(context),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: IgnorePointer(
                  child: Material(
                    color: scheme.surfaceContainerLowest,
                    elevation: 2,
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs + 2),
                          Text(
                            l10n.placeOpenInMaps,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ other states

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(actions: const <Widget>[LanguageButton()]),
      body: EmptyState(
        icon: Icons.wrong_location_outlined,
        title: l10n.placeNotFound,
        action: FilledButton.icon(
          onPressed: () => context.go(Routes.places),
          icon: const Icon(Icons.place_rounded),
          label: Text(l10n.placesTitle),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const <Widget>[LanguageButton()]),
      body: Skeleton(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: const <Widget>[
            SkeletonBox(height: 240, borderRadius: BorderRadius.zero),
            Padding(
              padding: EdgeInsets.all(AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonBox(width: 240, height: 26),
                  SizedBox(height: AppSpacing.md),
                  SkeletonBox(
                    width: 110,
                    height: 26,
                    borderRadius: AppRadius.lgAll,
                  ),
                  SizedBox(height: AppSpacing.xl),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SkeletonBox(
                          height: 88,
                          borderRadius: AppRadius.lgAll,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SkeletonBox(
                          height: 88,
                          borderRadius: AppRadius.lgAll,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SkeletonBox(
                          height: 88,
                          borderRadius: AppRadius.lgAll,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xxl),
                  SkeletonBox(width: 120, height: 20),
                  SizedBox(height: AppSpacing.md),
                  SkeletonBox(),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- helpers

Future<void> _launch(
  BuildContext context,
  Future<bool> Function() action,
) async {
  unawaited(HapticFeedback.selectionClick());
  final bool opened = await action();
  if (!opened && context.mounted) context.showOpenLinkError();
}

Future<void> _sharePlace(BuildContext context, PrasadiPlace place) async {
  unawaited(HapticFeedback.selectionClick());
  final AppLocalizations l10n = context.l10n;
  final String name = place.name.of(context);
  final String mahima = place.mahima.of(context);
  final GeoCoordinate? at = place.location;
  final String text = buildPlaceShareText(
    header: l10n.placesShareMessage(name),
    body: mahima.isNotEmpty ? mahima : place.shortDescription.of(context),
    link: at == null ? null : googleMapsLink(at),
  );
  // iPad needs an anchor for the share popover.
  final RenderObject? box = context.findRenderObject();
  final Rect? origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: name, sharePositionOrigin: origin),
    );
  } catch (error, stack) {
    AppLogger.error('Share place failed', error, stack);
    if (context.mounted) context.showSnack(l10n.errorGeneric);
  }
}
