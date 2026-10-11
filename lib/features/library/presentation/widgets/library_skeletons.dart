import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/skeleton.dart';
import 'book_grid.dart';

/// Placeholder for the library while the first snapshot loads: search bar,
/// chips and a grid of book covers.
class LibrarySkeleton extends StatelessWidget {
  const LibrarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final BookGridMetrics metrics = BookGridMetrics.of(
            context,
            constraints.maxWidth,
          );
          return ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.page,
            ),
            children: <Widget>[
              const SkeletonBox(
                height: 52,
                borderRadius: BorderRadius.all(Radius.circular(26)),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, int i) => SkeletonBox(
                    width: i == 0 ? 56 : 92,
                    height: 36,
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: metrics.spacing,
                runSpacing: metrics.runSpacing,
                children: <Widget>[
                  for (int i = 0; i < metrics.columns * 2; i++)
                    SizedBox(
                      width: metrics.itemWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SkeletonBox(height: metrics.coverHeight),
                          const SizedBox(height: AppSpacing.md),
                          const SkeletonBox(height: 14),
                          const SizedBox(height: AppSpacing.sm),
                          SkeletonBox(
                            width: metrics.itemWidth * 0.6,
                            height: 12,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Placeholder for the book page: cover, title lines and buttons.
class BookDetailSkeleton extends StatelessWidget {
  const BookDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final double coverWidth = (MediaQuery.sizeOf(context).width * 0.48).clamp(
      140.0,
      220.0,
    );
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: <Widget>[
          Center(
            child: SkeletonBox(width: coverWidth, height: coverWidth * 4 / 3),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: SkeletonBox(width: 220, height: 22)),
          const SizedBox(height: AppSpacing.md),
          const Center(child: SkeletonBox(width: 140, height: 14)),
          const SizedBox(height: AppSpacing.xxl),
          const SkeletonBox(height: 52, borderRadius: AppRadius.mdAll),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(height: 52, borderRadius: AppRadius.mdAll),
        ],
      ),
    );
  }
}
