import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/gallery_models.dart';
import '../../domain/gallery_queries.dart';
import 'gallery_hero.dart';

/// Album in the gallery grid: square cover, title, photo count and date.
class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).languageCode;
    final String title = album.titleFor(locale);
    final String date = Formatters.date(album.eventDate, locale);
    final int? count = album.photoCount;
    final TextStyle? meta = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: Hero(
                tag: albumCoverHeroTag(album.id),
                flightShuttleBuilder: galleryHeroShuttle,
                child: AppNetworkImage(
                  url: album.coverUrl,
                  placeholderIcon: Icons.photo_library_outlined,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (count != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.l10n.galleryPhotoCount(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                  ],
                  if (date.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
