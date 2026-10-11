import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/expandable_text.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/bulk_save.dart';
import '../application/photo_saver.dart';
import '../data/gallery_repository.dart';
import '../domain/gallery_models.dart';
import '../domain/gallery_queries.dart';
import 'widgets/gallery_hero.dart';
import 'widgets/gallery_skeletons.dart';
import 'widgets/photo_tile.dart';

/// One album: cover header, title and description, then a grid of every
/// photo. Tap a photo to view it full screen; long-press (or "Select") to
/// pick photos and save them to the phone's gallery in one go.
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key, required this.albumId});

  final String albumId;

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  /// Messages are shown through this screen's own [ScaffoldMessenger] so
  /// they appear above the selection bar instead of covering it.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _selecting = false;
  Set<String> _selected = const <String>{};
  BulkSaveJob? _job;
  BulkSaveProgress? _progress;

  bool get _saving => _job != null;

  @override
  void dispose() {
    _job?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Selection

  void _startSelection([String? photoId]) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selecting = true;
      _selected = <String>{?photoId};
    });
  }

  void _exitSelection() {
    if (_saving) return;
    setState(() {
      _selecting = false;
      _selected = const <String>{};
    });
  }

  void _toggle(String photoId) {
    if (_saving) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      final Set<String> next = Set<String>.of(_selected);
      if (!next.remove(photoId)) next.add(photoId);
      _selected = next;
    });
  }

  void _toggleAll(List<AlbumPhoto> photos) {
    if (_saving) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selected = _selected.length == photos.length
          ? const <String>{}
          : photos.map((AlbumPhoto p) => p.id).toSet();
    });
  }

  void _openPhoto(int index) {
    unawaited(HapticFeedback.selectionClick());
    context.push(Routes.photo(widget.albumId, index));
  }

  // ---------------------------------------------------------------------------
  // Saving

  void _snack(String message) {
    final BuildContext? target = _scaffoldKey.currentContext;
    if (target != null && target.mounted) target.showSnack(message);
  }

  Future<void> _saveSelected(List<AlbumPhoto> photos) async {
    if (_saving) return;
    final List<AlbumPhoto> chosen = selectedPhotosInOrder(photos, _selected);
    if (chosen.isEmpty) return;
    final AppLocalizations l10n = context.l10n;
    unawaited(HapticFeedback.selectionClick());
    final PhotoSaver saver = ref.read(photoSaverProvider);

    SaveAccess? access;
    try {
      access = await saver.requestAccess();
    } catch (error, stack) {
      AppLogger.error('Photo library permission check failed', error, stack);
      if (mounted) _snack(l10n.gallerySaveFailed);
      return;
    }
    if (!mounted) return;
    if (access == null) {
      _snack(l10n.galleryPermissionDenied);
      return;
    }

    final SaveAccess target = access;
    final BulkSaveJob job = BulkSaveJob(
      photos: chosen,
      save: (AlbumPhoto photo) =>
          saver.save(photo, albumId: widget.albumId, access: target),
    );
    setState(() {
      _job = job;
      _progress = BulkSaveProgress(total: chosen.length);
    });
    final BulkSaveProgress result = await job.run(
      onProgress: (BulkSaveProgress progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    setState(() {
      _job = null;
      _progress = null;
      if (!result.denied) {
        _selecting = false;
        _selected = const <String>{};
      }
    });

    if (result.denied) {
      _snack(l10n.galleryPermissionDenied);
      return;
    }
    final int notSaved = result.cancelled ? 0 : result.total - result.saved;
    final List<String> parts = <String>[
      if (result.saved > 0) l10n.gallerySavedCount(result.saved),
      if (notSaved > 0) l10n.galleryNotSavedCount(notSaved),
    ];
    if (parts.isEmpty) return; // cancelled before anything was saved
    if (result.saved > 0) unawaited(HapticFeedback.mediumImpact());
    _snack(result.saved == 0 ? l10n.gallerySaveFailed : parts.join(' · '));
  }

  void _cancelSave() {
    _job?.cancel();
    setState(() {}); // shows the "stopping" state immediately
  }

  void _retry() {
    ref
      ..invalidate(albumLookupProvider(widget.albumId))
      ..invalidate(albumPhotosProvider(widget.albumId));
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final String albumId = widget.albumId;
    final AsyncValue<AlbumLookup> lookupAsync = ref.watch(
      albumLookupProvider(albumId),
    );
    final AsyncValue<LiveList<AlbumPhoto>> photosAsync = ref.watch(
      albumPhotosProvider(albumId),
    );
    // The album list is usually loaded already (we came from it), which lets
    // the header — and its cover hero animation — appear on the first frame.
    final Album? listed = ref.watch(
      albumsProvider.select(
        (AsyncValue<LiveList<Album>> value) =>
            _findAlbum(value.value?.items, albumId),
      ),
    );

    // Photos removed while selecting drop out of the selection.
    ref.listen<AsyncValue<LiveList<AlbumPhoto>>>(albumPhotosProvider(albumId), (
      AsyncValue<LiveList<AlbumPhoto>>? previous,
      AsyncValue<LiveList<AlbumPhoto>> next,
    ) {
      final LiveList<AlbumPhoto>? photos = next.value;
      if (photos == null || _selected.isEmpty) return;
      final Set<String> kept = retainExistingSelection(_selected, photos.items);
      if (kept.length != _selected.length) setState(() => _selected = kept);
    });

    final AlbumLookup? lookup = lookupAsync.value;
    final LiveList<AlbumPhoto>? photos = photosAsync.value;

    if (lookup != null && photos != null) {
      switch (albumViewStatus(lookup, photos)) {
        case AlbumViewStatus.notFound:
          return _message(
            EmptyState(
              icon: Icons.photo_library_outlined,
              title: context.l10n.galleryAlbumNotFound,
              action: FilledButton.tonalIcon(
                onPressed: () => context.go(Routes.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(context.l10n.galleryTitle),
              ),
            ),
          );
        case AlbumViewStatus.offline:
          return _message(
            EmptyState(
              icon: Icons.wifi_off_rounded,
              title: context.l10n.errorNetwork,
            ),
          );
        case AlbumViewStatus.ready:
          return _content(displayAlbum(albumId, lookup), photos);
      }
    }

    final Album? known = lookup != null ? lookup.album : listed;
    if (known != null) {
      if (!known.isActive) {
        return _message(
          EmptyState(
            icon: Icons.photo_library_outlined,
            title: context.l10n.galleryAlbumNotFound,
          ),
        );
      }
      if (!photosAsync.hasError || photos != null) {
        return _content(known, photos);
      }
    }
    if ((lookupAsync.hasError && lookup == null) ||
        (photosAsync.hasError && photos == null)) {
      return _message(ErrorState(onRetry: _retry));
    }
    return _message(const AlbumPageSkeleton());
  }

  /// Simple page (loading, error, not found) with the standard app bar.
  Widget _message(Widget body) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.galleryTitle),
        actions: const <Widget>[LanguageButton()],
      ),
      body: body,
    );
  }

  Widget _content(Album album, LiveList<AlbumPhoto>? photoList) {
    final AppLocalizations l10n = context.l10n;
    final List<AlbumPhoto> photos = photoList?.items ?? const <AlbumPhoto>[];
    final String locale = Localizations.localeOf(context).languageCode;
    final String title = album.titleFor(locale);
    final String? cover = albumCoverUrl(album, photos);
    final int columns = photoGridColumns(MediaQuery.sizeOf(context).width);

    final List<Widget> slivers = <Widget>[
      _appBar(album: album, title: title, cover: cover, photos: photos),
      SliverToBoxAdapter(
        child: _AlbumInfo(
          album: album,
          title: title,
          photoCount: photoList == null ? album.photoCount : photos.length,
        ),
      ),
      if (photoList == null)
        const SliverPhotoGridSkeleton()
      else if (photos.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: photoList.isUnavailableOffline
              ? EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: l10n.errorNetwork,
                )
              : EmptyState(
                  icon: Icons.photo_camera_back_outlined,
                  title: l10n.galleryEmpty,
                ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: kPhotoGridSpacing,
              crossAxisSpacing: kPhotoGridSpacing,
            ),
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final AlbumPhoto photo = photos[index];
              return PhotoTile(
                key: ValueKey<String>(photo.id),
                albumId: album.id,
                photo: photo,
                semanticLabel: l10n.galleryPhotoLabel(index + 1, photos.length),
                selectionMode: _selecting,
                selected: _selected.contains(photo.id),
                onTap: () => _selecting ? _toggle(photo.id) : _openPhoto(index),
                onLongPress: _saving
                    ? null
                    : () => _selecting
                          ? _toggle(photo.id)
                          : _startSelection(photo.id),
              );
            }, childCount: photos.length),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
    ];

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) return;
        if (_saving) {
          _cancelSave();
        } else {
          _exitSelection();
        }
      },
      child: ScaffoldMessenger(
        child: Scaffold(
          key: _scaffoldKey,
          body: CustomScrollView(slivers: slivers),
          bottomNavigationBar: AnimatedSize(
            duration: AppDurations.medium,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _selecting
                ? _SelectionBar(
                    selectedCount: _selected.length,
                    progress: _progress,
                    stopping: _job?.isCancelled ?? false,
                    onSave: () => _saveSelected(photos),
                    onCancelSave: _cancelSave,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ),
    );
  }

  Widget _appBar({
    required Album album,
    required String title,
    required String? cover,
    required List<AlbumPhoto> photos,
  }) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool hasCover = cover != null;
    final bool hasPhotos = photos.isNotEmpty;
    final Color foreground = hasCover
        ? Colors.white
        : theme.colorScheme.onSurface;
    final bool allSelected = hasPhotos && _selected.length == photos.length;

    final Widget? leading = _selecting
        ? IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close_rounded),
            onPressed: _saving ? _cancelSave : _exitSelection,
          )
        : null;
    final List<Widget> actions = <Widget>[
      // A compact icon while selecting keeps the bar uncluttered next to the
      // "N selected" title, even on small phones with large text.
      if (hasPhotos && _selecting)
        IconButton(
          tooltip: allSelected
              ? l10n.galleryClearSelection
              : l10n.gallerySelectAll,
          color: foreground,
          icon: Icon(
            allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          ),
          onPressed: _saving ? null : () => _toggleAll(photos),
        )
      else if (hasPhotos)
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: foreground,
            minimumSize: const Size(48, AppSpacing.minTouchTarget),
            textStyle: theme.textTheme.titleSmall,
          ),
          onPressed: _saving ? null : _startSelection,
          child: Text(l10n.gallerySelect),
        ),
      LanguageButton(foregroundColor: hasCover ? Colors.white : null),
    ];
    final Widget barTitle = Text(
      _selecting ? l10n.gallerySelectedCount(_selected.length) : title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (!hasCover) {
      return SliverAppBar(
        pinned: true,
        leading: leading,
        title: barTitle,
        actions: actions,
      );
    }

    final double expandedHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(220.0, 340.0);
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      leading: leading,
      title: barTitle,
      actions: actions,
      backgroundColor: AppColors.saffron,
      foregroundColor: Colors.white,
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Hero(
              tag: albumCoverHeroTag(album.id),
              flightShuttleBuilder: galleryHeroShuttle,
              child: AppNetworkImage(
                url: cover,
                placeholderIcon: Icons.photo_library_outlined,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.imageScrim),
            ),
            // Keeps the toolbar title and icons readable over bright photos.
            const Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x8C000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Album? _findAlbum(List<Album>? albums, String id) {
  if (albums == null) return null;
  for (final Album album in albums) {
    if (album.id == id) return album;
  }
  return null;
}

/// Title, date, photo count and description below the header.
class _AlbumInfo extends StatelessWidget {
  const _AlbumInfo({
    required this.album,
    required this.title,
    required this.photoCount,
  });

  final Album album;
  final String title;
  final int? photoCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).languageCode;
    final String date = Formatters.longDate(album.eventDate, locale);
    final String description = album.description.of(context);
    final int? count = photoCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineSmall),
          ),
          if (date.isNotEmpty || count != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (date.isNotEmpty)
                  _Meta(icon: Icons.event_rounded, text: date),
                if (count != null)
                  _Meta(
                    icon: Icons.photo_library_outlined,
                    text: context.l10n.galleryPhotoCount(count),
                  ),
              ],
            ),
          ],
          if (description.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ExpandableText(description, collapsedLines: 3),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom bar in selection mode: a hint, the "Save N photos" button, or the
/// saving progress with a cancel button.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.progress,
    required this.stopping,
    required this.onSave,
    required this.onCancelSave,
  });

  final int selectedCount;
  final BulkSaveProgress? progress;
  final bool stopping;
  final VoidCallback onSave;
  final VoidCallback onCancelSave;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final BulkSaveProgress? saving = progress;

    final Widget child;
    if (saving != null) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    stopping
                        ? l10n.gallerySaving
                        : l10n.gallerySavingProgress(
                            (saving.done + 1).clamp(1, saving.total),
                            saving.total,
                          ),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, AppSpacing.minTouchTarget),
                ),
                onPressed: stopping ? null : onCancelSave,
                child: Text(l10n.cancel),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: LinearProgressIndicator(
              value: saving.fraction,
              minHeight: 6,
            ),
          ),
        ],
      );
    } else if (selectedCount == 0) {
      child = SizedBox(
        height: AppSpacing.minTouchTarget + 4,
        child: Center(
          child: Text(
            l10n.gallerySelectHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      child = FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: theme.textTheme.titleMedium,
        ),
        onPressed: onSave,
        icon: const Icon(Icons.download_rounded),
        label: Text(l10n.gallerySaveSelected(selectedCount)),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            child: KeyedSubtree(
              key: ValueKey<int>(
                saving != null
                    ? 2
                    : selectedCount == 0
                    ? 0
                    : 1,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
