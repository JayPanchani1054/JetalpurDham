import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_spacing.dart';

/// Shimmering placeholder shown while content loads. Wrap a layout made of
/// [SkeletonBox]es in a single [Skeleton] so they shimmer in sync.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHigh,
      highlightColor: scheme.surfaceContainerLowest,
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.smAll,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: borderRadius,
    ),
  );
}

/// Generic list skeleton: [count] rows of thumbnail + two text lines.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 8,
    this.thumbnailSize = 56,
    this.padding = const EdgeInsets.all(AppSpacing.page),
  });

  final int count;
  final double thumbnailSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
        itemBuilder: (_, _) => Row(
          children: <Widget>[
            SkeletonBox(
              width: thumbnailSize,
              height: thumbnailSize,
              borderRadius: AppRadius.mdAll,
            ),
            const SizedBox(width: AppSpacing.lg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonBox(),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 140, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
