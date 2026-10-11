import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/state_views.dart';
import '../data/gallery_repository.dart';
import '../domain/gallery_models.dart';
import 'widgets/album_card.dart';
import 'widgets/gallery_skeletons.dart';

/// All photo albums (Avsar 200 and other utsav albums), featured first.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<LiveList<Album>> albums = ref.watch(albumsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.galleryTitle),
        actions: const <Widget>[LanguageButton()],
      ),
      body: AsyncValueView<LiveList<Album>>(
        value: albums,
        loading: const AlbumGridSkeleton(),
        onRetry: () => ref.invalidate(albumsProvider),
        isEmpty: (LiveList<Album> list) => list.isEmpty,
        empty: albums.value?.isUnavailableOffline ?? false
            ? EmptyState(icon: Icons.wifi_off_rounded, title: l10n.errorNetwork)
            : EmptyState(
                icon: Icons.photo_library_outlined,
                title: l10n.galleryEmpty,
              ),
        data: (LiveList<Album> list) => _AlbumGrid(albums: list.items),
      ),
    );
  }
}

/// Albums in equal-height rows of cards (2 columns on phones).
class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = albumGridColumns(constraints.maxWidth);
        final int rows = (albums.length / columns).ceil();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          itemCount: rows,
          itemBuilder: (BuildContext context, int row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              // Rows size to their tallest card so titles of different
              // lengths (and large text) never overflow or look ragged.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int c = 0; c < columns; c++) ...<Widget>[
                      if (c > 0) const SizedBox(width: AppSpacing.md),
                      Expanded(child: _cell(context, row * columns + c)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _cell(BuildContext context, int index) {
    if (index >= albums.length) return const SizedBox.shrink();
    final Album album = albums[index];
    return AlbumCard(
      album: album,
      onTap: () {
        HapticFeedback.selectionClick();
        context.go(Routes.album(album.id));
      },
    );
  }
}
