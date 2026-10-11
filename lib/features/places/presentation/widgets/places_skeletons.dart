import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/skeleton.dart';
import 'place_cards.dart';

/// Loading placeholder matching [PlaceListCard]s.
class PlacesListSkeleton extends StatelessWidget {
  const PlacesListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.page),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
        itemBuilder: (_, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonBox(
                height: double.infinity,
                borderRadius: AppRadius.lgAll,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(width: 220, height: 20),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 110, height: 24, borderRadius: AppRadius.lgAll),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 14),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder for the map view: a calm surface with a card at the
/// bottom where the carousel will appear.
class PlacesMapSkeleton extends StatelessWidget {
  const PlacesMapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const SkeletonBox(
            height: double.infinity,
            borderRadius: BorderRadius.zero,
          ),
          Positioned(
            left: AppSpacing.page,
            right: AppSpacing.page,
            bottom: AppSpacing.lg,
            child: SkeletonBox(
              height: placeCarouselCardHeight(context),
              borderRadius: AppRadius.lgAll,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of card placeholders (home preview).
class PlacesRowSkeleton extends StatelessWidget {
  const PlacesRowSkeleton({
    super.key,
    required this.height,
    required this.cardWidth,
  });

  final double height;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Skeleton(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.pagePadding,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (_, _) => SkeletonBox(
            width: cardWidth,
            height: height,
            borderRadius: AppRadius.lgAll,
          ),
        ),
      ),
    );
  }
}
