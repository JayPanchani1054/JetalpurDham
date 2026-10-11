import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/prasadi_place.dart';
import 'place_ui.dart';

/// Current text scale (1.0 = default), used to size fixed-height rows so
/// large accessibility text never overflows.
double placesTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16;

/// A place photo inside a [Hero] that keeps one decode size during the
/// flight.
///
/// [AppNetworkImage] decodes at its layout width; inside a Hero flight that
/// width changes every frame, which would reload the photo and flash the
/// placeholder. Here the photo is laid out once at its resting size and the
/// flight only scales it (like `BoxFit.cover`).
class PlaceHeroImage extends StatelessWidget {
  const PlaceHeroImage({
    super.key,
    required this.placeId,
    required this.url,
    required this.placeholderIcon,
  });

  final String placeId;
  final String? url;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 320,
          constraints.hasBoundedHeight ? constraints.maxHeight : 180,
        );
        return Hero(
          tag: placeHeroTag(placeId),
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox.fromSize(
              size: size,
              child: AppNetworkImage(
                url: url,
                placeholderIcon: placeholderIcon,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cover image of a place with an optional Hero and the 360° badge.
class PlaceCoverImage extends StatelessWidget {
  const PlaceCoverImage({
    super.key,
    required this.place,
    this.hero = true,
    this.showBadge = true,
  });

  final PrasadiPlace place;
  final bool hero;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final Widget image = hero
        ? PlaceHeroImage(
            placeId: place.id,
            url: place.coverImage,
            placeholderIcon: place.category.icon,
          )
        : AppNetworkImage(
            url: place.coverImage,
            placeholderIcon: place.category.icon,
          );
    if (!showBadge || !place.hasPanorama) return image;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        image,
        const Positioned(
          left: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: Place360Badge(),
        ),
      ],
    );
  }
}

/// Large card for the list view: 16:9 photo, name, category and a short
/// description.
class PlaceListCard extends StatelessWidget {
  const PlaceListCard({super.key, required this.place, required this.onTap});

  final PrasadiPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String description = place.shortDescription.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PlaceCoverImage(place: place),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    place.name.of(context),
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PlaceCategoryChip(category: place.category),
                  if (description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

/// Height of [PlaceCarouselCard] for the current text scale.
double placeCarouselCardHeight(BuildContext context) =>
    96 + 44 * placesTextScale(context).clamp(1.0, 1.6);

/// Compact horizontal card shown over the map (photo left, text right).
class PlaceCarouselCard extends StatelessWidget {
  const PlaceCarouselCard({
    super.key,
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final PrasadiPlace place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String description = place.shortDescription.of(context);
    return AnimatedScale(
      scale: selected ? 1 : 0.94,
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      child: Card(
        elevation: selected ? 6 : 2,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: selected
                ? scheme.primary.withValues(alpha: 0.7)
                : scheme.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 0.9,
                child: PlaceCoverImage(place: place),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        place.name.of(context),
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          Icon(
                            place.category.icon,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              place.category.label(context.l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
