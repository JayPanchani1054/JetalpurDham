import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/kirtan_player_controller.dart';
import '../../domain/kirtan.dart';
import 'equalizer_indicator.dart';
import 'kirtan_artwork.dart';
import 'kirtan_download_button.dart';

/// `Premanand Swami · 6:12` — artist and (when known) duration.
String kirtanSubtitle(BuildContext context, Kirtan kirtan) {
  final String artist = kirtan.artist.of(context);
  final Duration? duration = kirtan.duration;
  return <String>[
    if (artist.isNotEmpty) artist,
    if (duration != null) Formatters.duration(duration),
  ].join(' · ');
}

/// One kirtan row: artwork, title, poet · duration and a trailing action
/// (download button by default). The playing row is highlighted with an
/// animated equalizer.
class KirtanTile extends ConsumerWidget {
  const KirtanTile({
    super.key,
    required this.kirtan,
    required this.onTap,
    this.trailing,
  });

  final Kirtan kirtan;
  final VoidCallback onTap;

  /// Replaces the download button.
  final Widget? trailing;

  static const double artworkSize = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCurrent = ref.watch(
      currentKirtanProvider.select((Kirtan? k) => k?.id == kirtan.id),
    );
    final bool isPlaying = isCurrent && ref.watch(kirtanIsPlayingProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String subtitle = kirtanSubtitle(context, kirtan);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isCurrent
              ? scheme.primaryContainer.withValues(alpha: 0.55)
              : scheme.primaryContainer.withValues(alpha: 0),
          borderRadius: AppRadius.mdAll,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: onTap,
            child: Semantics(
              selected: isCurrent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: artworkSize,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          KirtanArtwork(kirtan: kirtan, size: artworkSize),
                          if (isCurrent)
                            DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0x73000000),
                                borderRadius: AppRadius.mdAll,
                              ),
                              child: Center(
                                child: Semantics(
                                  label: context.l10n.kirtanNowPlaying,
                                  child: EqualizerIndicator(
                                    playing: isPlaying,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            kirtan.title.of(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isCurrent ? scheme.primary : null,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing ?? KirtanDownloadButton(kirtan: kirtan),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
