import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/gallery_models.dart';
import '../../domain/gallery_queries.dart';
import 'gallery_hero.dart';

/// Square photo thumbnail used in the album grid and the home strip.
///
/// The image is decoded at the tile's size (smooth scrolling through
/// hundreds of photos) and shares a [Hero] with the full-screen viewer.
/// In selection mode a check badge shows whether the photo is selected.
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.albumId,
    required this.photo,
    required this.semanticLabel,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.borderRadius = AppRadius.smAll,
  });

  final String albumId;
  final AlbumPhoto photo;
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isSelected = selectionMode && selected;
    // One clean node for screen readers ("Photo 3 of 40", selected state),
    // with the tap / long-press actions re-attached here.
    return Semantics(
      button: true,
      selected: selectionMode ? selected : null,
      label: semanticLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: borderRadius,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Scaling (not padding) keeps the decode size constant, so
            // selecting never re-decodes the image.
            AnimatedScale(
              scale: isSelected ? 0.84 : 1,
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Hero(
                  tag: photoHeroTag(albumId, photo.id),
                  flightShuttleBuilder: galleryHeroShuttle,
                  child: AppNetworkImage(
                    url: photo.previewUrl,
                    placeholderIcon: Icons.photo_outlined,
                  ),
                ),
              ),
            ),
            if (selectionMode)
              PositionedDirectional(
                top: AppSpacing.xs + 2,
                end: AppSpacing.xs + 2,
                child: _SelectionBadge(selected: selected),
              ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Drawn on top of photos, so the unselected state is a light ring on
        // a soft shadow that stays visible on bright and dark images.
        color: selected ? scheme.primary : const Color(0x33000000),
        border: Border.all(
          color: selected ? scheme.onPrimary : Colors.white,
          width: 2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x40000000), blurRadius: 4),
        ],
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
          : null,
    );
  }
}
