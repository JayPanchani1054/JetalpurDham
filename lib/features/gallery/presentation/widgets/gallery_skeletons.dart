import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/skeleton.dart';

/// Number of grid columns for album cards at [width].
int albumGridColumns(double width) => width >= 900
    ? 4
    : width >= 600
    ? 3
    : 2;

/// Number of grid columns for photo thumbnails at [width].
int photoGridColumns(double width) => width >= 900
    ? 6
    : width >= 600
    ? 4
    : 3;

/// Spacing between photo thumbnails.
const double kPhotoGridSpacing = AppSpacing.xs;

/// Loading placeholder for the album list.
class AlbumGridSkeleton extends StatelessWidget {
  const AlbumGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final int columns = albumGridColumns(MediaQuery.sizeOf(context).width);
    return Skeleton(
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.page),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: columns * 3,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (_, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SkeletonBox(
                height: double.infinity,
                borderRadius: AppRadius.mdAll,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(width: 120),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 72, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder for a block of photo thumbnails, as a sliver.
class SliverPhotoGridSkeleton extends StatelessWidget {
  const SliverPhotoGridSkeleton({super.key, this.count = 18});

  final int count;

  @override
  Widget build(BuildContext context) {
    final int columns = photoGridColumns(MediaQuery.sizeOf(context).width);
    // One shimmer for the whole block so every box shimmers in sync.
    return SliverToBoxAdapter(
      child: Skeleton(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: kPhotoGridSpacing,
            crossAxisSpacing: kPhotoGridSpacing,
          ),
          itemBuilder: (_, _) => const SkeletonBox(height: double.infinity),
        ),
      ),
    );
  }
}

/// Full-page placeholder for an album that is still loading.
class AlbumPageSkeleton extends StatelessWidget {
  const AlbumPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: NeverScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Skeleton(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonBox(height: 200, borderRadius: AppRadius.lgAll),
                  SizedBox(height: AppSpacing.lg),
                  SkeletonBox(width: 200, height: 22),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 140, height: 14),
                ],
              ),
            ),
          ),
        ),
        SliverPhotoGridSkeleton(count: 12),
      ],
    );
  }
}

/// Loading placeholder for the home photo strip.
class PhotoStripSkeleton extends StatelessWidget {
  const PhotoStripSkeleton({super.key, required this.tileSize});

  final double tileSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileSize,
      child: Skeleton(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: AppSpacing.pagePadding,
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, _) => SkeletonBox(
            width: tileSize,
            height: tileSize,
            borderRadius: AppRadius.mdAll,
          ),
        ),
      ),
    );
  }
}
