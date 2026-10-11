import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../data/gallery_repository.dart';
import '../../domain/gallery_models.dart';
import '../../domain/gallery_queries.dart';
import 'gallery_skeletons.dart';
import 'photo_tile.dart';

/// Home section: header + strip of photos from the featured album (Avsar 200).
///
/// Hidden when the album is missing or has no photos; a skeleton is shown
/// only during the very first load.
class HomeGalleryPreview extends ConsumerWidget {
  const HomeGalleryPreview({super.key});

  /// The album shown when `config/app.featuredAlbumId` is not set.
  static const String defaultAlbumId = 'avsar-200';

  static const int maxPhotos = 12;
  static const double tileSize = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String albumId =
        ref.watch(
          appConfigValueProvider.select((AppConfig c) => c.featuredAlbumId),
        ) ??
        defaultAlbumId;
    final AsyncValue<AlbumLookup> lookupAsync = ref.watch(
      albumLookupProvider(albumId),
    );
    final AsyncValue<LiveList<AlbumPhoto>> photosAsync = ref.watch(
      albumPhotosProvider(albumId),
    );
    final AlbumLookup? lookup = lookupAsync.value;
    final LiveList<AlbumPhoto>? photos = photosAsync.value;

    if (lookup == null || photos == null) {
      final bool failed =
          (lookupAsync.hasError && lookup == null) ||
          (photosAsync.hasError && photos == null);
      if (failed) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(title: l10n.homeGalleryTitle),
          const PhotoStripSkeleton(tileSize: tileSize),
        ],
      );
    }
    if (albumViewStatus(lookup, photos) != AlbumViewStatus.ready ||
        photos.isEmpty) {
      return const SizedBox.shrink();
    }

    final Album album = displayAlbum(albumId, lookup);
    final String locale = Localizations.localeOf(context).languageCode;
    // "Avsar 200 Photos" for the default album; the album's own title when
    // the temple features a different one.
    final String title = albumId == defaultAlbumId
        ? l10n.homeGalleryTitle
        : album.titleFor(locale);
    final List<AlbumPhoto> items = photos.items;
    final int shown = items.length < maxPhotos ? items.length : maxPhotos;
    final bool hasMore = items.length > shown;

    void openAlbum() {
      HapticFeedback.selectionClick();
      context.go(Routes.album(albumId));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: title,
          actionLabel: l10n.seeAll,
          onAction: openAlbum,
        ),
        SizedBox(
          height: tileSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.pagePadding,
            itemCount: shown + (hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              if (index >= shown) {
                return _MoreTile(
                  size: tileSize,
                  total: items.length,
                  onTap: openAlbum,
                );
              }
              final AlbumPhoto photo = items[index];
              return SizedBox.square(
                dimension: tileSize,
                child: PhotoTile(
                  albumId: albumId,
                  photo: photo,
                  borderRadius: AppRadius.mdAll,
                  semanticLabel: l10n.galleryPhotoLabel(
                    index + 1,
                    items.length,
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push(Routes.photo(albumId, index));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Last tile of the strip: opens the whole album.
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.size,
    required this.total,
    required this.onTap,
  });

  final double size;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.photo_library_rounded,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.seeAll,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  context.l10n.galleryPhotoCount(total),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
