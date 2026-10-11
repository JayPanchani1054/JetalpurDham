import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/ui_feedback.dart';
import '../../application/kirtan_player_controller.dart';
import '../../application/kirtan_player_state.dart';
import '../../application/kirtan_sleep_timer.dart';
import '../../domain/kirtan.dart';
import 'kirtan_actions.dart';
import 'kirtan_artwork.dart';

/// Persistent mini player shown above the bottom navigation bar while a
/// kirtan is loaded. Renders `SizedBox.shrink()` when nothing is loaded.
///
/// Tap to open Now Playing; swipe sideways to stop and close. It also shows
/// the app-wide message when a kirtan cannot be played.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(
      kirtanPlayerProvider.select((KirtanQueue q) => q.errorCount),
      (int? previous, int next) {
        if (previous == null || next <= previous) return;
        final bool offline = !(ref.read(isOnlineProvider).value ?? true);
        context.showSnack(
          offline
              ? context.l10n.kirtanOfflineUnavailable
              : context.l10n.kirtanPlaybackError,
        );
      },
    );
    final Kirtan? kirtan = ref.watch(currentKirtanProvider);
    if (kirtan == null) return const SizedBox.shrink();
    return _MiniPlayerBar(kirtan: kirtan);
  }
}

class _MiniPlayerBar extends ConsumerStatefulWidget {
  const _MiniPlayerBar({required this.kirtan});

  final Kirtan kirtan;

  @override
  ConsumerState<_MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<_MiniPlayerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppDurations.slow,
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _openPlayer() {
    HapticFeedback.selectionClick().ignore();
    openKirtanPlayer(context);
  }

  @override
  Widget build(BuildContext context) {
    final Kirtan kirtan = widget.kirtan;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
    final String artist = kirtan.artist.of(context);

    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _curve,
        child: Dismissible(
          key: const ValueKey<String>('kirtan-mini-player'),
          onDismissed: (_) {
            ref.read(kirtanSleepTimerProvider.notifier).cancel();
            unawaited(ref.read(kirtanPlayerProvider.notifier).stop());
          },
          child: Material(
            color: dark
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLowest,
            shape: Border(top: BorderSide(color: scheme.outlineVariant)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _MiniProgressLine(),
                InkWell(
                  onTap: _openPlayer,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: <Widget>[
                          Hero(
                            tag: kKirtanArtworkHeroTag,
                            child: KirtanArtwork(
                              kirtan: kirtan,
                              size: 46,
                              borderRadius: AppRadius.smAll,
                              useMurtiFallback: true,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Semantics(
                              button: true,
                              hint: context.l10n.kirtanNowPlaying,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    kirtan.title.of(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  if (artist.isNotEmpty)
                                    Text(
                                      artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const _MiniPlayPauseButton(),
                          const _MiniNextButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProgressLine extends ConsumerWidget {
  const _MiniProgressLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While a new kirtan loads, the player still reports the previous one.
    final bool preparing = ref.watch(
      kirtanPlayerProvider.select((KirtanQueue q) => q.isPreparing),
    );
    final double fraction = preparing
        ? 0
        : ref.watch(
            kirtanProgressProvider.select(
              (AsyncValue<KirtanProgress> p) => p.value?.fraction ?? 0,
            ),
          );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LinearProgressIndicator(
      value: fraction,
      minHeight: 2.5,
      color: scheme.primary,
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
    );
  }
}

class _MiniPlayPauseButton extends ConsumerWidget {
  const _MiniPlayPauseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool playing = ref.watch(kirtanIsPlayingProvider);
    final bool loading = ref.watch(kirtanIsLoadingProvider);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: playing ? l10n.pause : l10n.play,
      iconSize: 32,
      color: scheme.primary,
      onPressed: () {
        HapticFeedback.selectionClick().ignore();
        unawaited(ref.read(kirtanPlayerProvider.notifier).togglePlayPause());
      },
      icon: loading
          ? SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            )
          : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}

class _MiniNextButton extends ConsumerWidget {
  const _MiniNextButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasNext = ref.watch(kirtanHasNextProvider);
    return IconButton(
      tooltip: context.l10n.next,
      iconSize: 28,
      onPressed: hasNext
          ? () {
              HapticFeedback.selectionClick().ignore();
              unawaited(ref.read(kirtanPlayerProvider.notifier).skipToNext());
            }
          : null,
      icon: const Icon(Icons.skip_next_rounded),
    );
  }
}
