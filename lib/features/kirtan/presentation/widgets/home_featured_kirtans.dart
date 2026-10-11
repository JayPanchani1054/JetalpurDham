import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../application/kirtan_player_controller.dart';
import '../../data/kirtan_repository.dart';
import '../../domain/kirtan.dart';
import 'equalizer_indicator.dart';
import 'kirtan_artwork.dart';

/// Home section: header + horizontal list of featured kirtans (tap to play).
/// Hidden entirely when there are no kirtans (or they cannot be loaded).
class HomeFeaturedKirtans extends ConsumerWidget {
  const HomeFeaturedKirtans({super.key});

  static const double _cardWidth = 140;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Kirtan>> featured = ref.watch(
      featuredKirtansProvider,
    );
    return featured.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const _FeaturedSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (List<Kirtan> kirtans) {
        if (kirtans.isEmpty) return const SizedBox.shrink();
        final double height = _listHeight(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(
              title: context.l10n.homeFeaturedKirtans,
              actionLabel: context.l10n.seeAll,
              onAction: () => context.go(Routes.kirtan),
            ),
            SizedBox(
              height: height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.pagePadding,
                itemCount: kirtans.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (BuildContext context, int index) => _FeaturedCard(
                  key: ValueKey<String>(kirtans[index].id),
                  kirtan: kirtans[index],
                  width: _cardWidth,
                  onTap: () => _play(context, ref, kirtans, index),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Artwork + two title lines + one artist line, at the user's text size.
  static double _listHeight(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) =>
        scaler.scale((style?.fontSize ?? 14) * (style?.height ?? 1.4));
    return _cardWidth +
        AppSpacing.sm +
        line(text.titleSmall) * 2 +
        line(text.bodySmall) +
        AppSpacing.sm;
  }

  void _play(BuildContext context, WidgetRef ref, List<Kirtan> list, int i) {
    unawaited(HapticFeedback.selectionClick());
    if (ref.read(currentKirtanProvider)?.id == list[i].id) {
      unawaited(context.push<void>(Routes.player));
      return;
    }
    unawaited(
      ref.read(kirtanPlayerProvider.notifier).playKirtans(list, startIndex: i),
    );
  }
}

class _FeaturedCard extends ConsumerWidget {
  const _FeaturedCard({
    super.key,
    required this.kirtan,
    required this.width,
    required this.onTap,
  });

  final Kirtan kirtan;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCurrent = ref.watch(
      currentKirtanProvider.select((Kirtan? k) => k?.id == kirtan.id),
    );
    final bool isPlaying = isCurrent && ref.watch(kirtanIsPlayingProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String artist = kirtan.artist.of(context);

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: isCurrent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox.square(
                dimension: width,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    KirtanArtwork(kirtan: kirtan, size: width),
                    if (isCurrent)
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0x66000000),
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Center(
                          child: EqualizerIndicator(
                            playing: isPlaying,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      )
                    else
                      Positioned(
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs + 2),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: scheme.onPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                kirtan.title.of(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isCurrent ? scheme.primary : null,
                ),
              ),
              if (artist.isNotEmpty)
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
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

class _FeaturedSkeleton extends StatelessWidget {
  const _FeaturedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xl,
          0,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SkeletonBox(width: 180, height: 22),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: HomeFeaturedKirtans._cardWidth + 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, _) => const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonBox(
                      width: HomeFeaturedKirtans._cardWidth,
                      height: HomeFeaturedKirtans._cardWidth,
                      borderRadius: AppRadius.mdAll,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(width: 110, height: 14),
                    SizedBox(height: AppSpacing.xs),
                    SkeletonBox(width: 80, height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
