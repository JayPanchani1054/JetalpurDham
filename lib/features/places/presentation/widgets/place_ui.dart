import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/prasadi_place.dart';

/// Hero tag shared by place cover images (list/carousel card → detail).
String placeHeroTag(String placeId) => 'place-cover-$placeId';

/// Saffron pin colour used for Google Maps markers (hue 0–360).
const double kPlaceMarkerHue = 25;

extension PlaceCategoryUi on PlaceCategory {
  String label(AppLocalizations l10n) => switch (this) {
    PlaceCategory.temple => l10n.placeCategoryTemple,
    PlaceCategory.yagna => l10n.placeCategoryYagna,
    PlaceCategory.water => l10n.placeCategoryWater,
    PlaceCategory.tree => l10n.placeCategoryTree,
    PlaceCategory.residence => l10n.placeCategoryResidence,
    PlaceCategory.other => l10n.placeCategoryOther,
  };

  IconData get icon => switch (this) {
    PlaceCategory.temple => Icons.temple_hindu_rounded,
    PlaceCategory.yagna => Icons.local_fire_department_rounded,
    PlaceCategory.water => Icons.water_drop_rounded,
    PlaceCategory.tree => Icons.park_rounded,
    PlaceCategory.residence => Icons.home_rounded,
    PlaceCategory.other => Icons.auto_awesome_rounded,
  };
}

/// Small rounded label with the category icon and name.
class PlaceCategoryChip extends StatelessWidget {
  const PlaceCategoryChip({super.key, required this.category});

  final PlaceCategory category;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(category.icon, size: 16, color: scheme.onPrimaryContainer),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text(
                category.label(context.l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "360°" badge shown on top of a place photo when 360° darshan exists.
class Place360Badge extends StatelessWidget {
  const Place360Badge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xB3000000),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs + 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.threesixty_rounded, size: 16, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
            Text(
              context.l10n.places360Badge,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
