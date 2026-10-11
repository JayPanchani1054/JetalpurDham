import 'dart:async';
import 'dart:math';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/kirtan_player_controller.dart';
import '../application/kirtan_player_state.dart';
import '../application/kirtan_sleep_timer.dart';
import '../domain/kirtan.dart';
import 'widgets/kirtan_artwork.dart';
import 'widgets/kirtan_download_button.dart';
import 'widgets/kirtan_sheets.dart';

/// Full-screen player: large artwork, title, progress, big play/pause and
/// the secondary actions (download, lyrics, sleep timer, speed).
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Kirtan? kirtan = ref.watch(currentKirtanProvider);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final AppBar appBar = AppBar(
      backgroundColor: Colors.transparent,
      centerTitle: true,
      leading: IconButton(
        tooltip: l10n.close,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
        onPressed: () => _close(context),
      ),
      title: Text(l10n.kirtanNowPlaying),
      actions: <Widget>[
        if (kirtan != null)
          IconButton(
            tooltip: l10n.kirtanQueue,
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () => showKirtanQueueSheet(context),
          ),
        const LanguageButton(),
      ],
    );

    if (kirtan == null) {
      return Scaffold(
        appBar: appBar,
        body: EmptyState(
          icon: Icons.music_off_rounded,
          title: l10n.emptyGeneric,
          action: FilledButton.icon(
            onPressed: () => context.go(Routes.kirtan),
            icon: const Icon(Icons.library_music_rounded),
            label: Text(l10n.kirtanBrowse),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        // Opaque colours only: the page covers the app underneath.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(
              scheme.primaryContainer.withValues(alpha: dark ? 0.55 : 0.9),
              scheme.surface,
            ),
            scheme.surface,
          ],
          stops: const <double>[0, 0.7],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final List<Widget> controls = <Widget>[
                const SizedBox(height: AppSpacing.xl),
                _TitleBlock(kirtan: kirtan),
                const SizedBox(height: AppSpacing.lg),
                const _ProgressSection(),
                const SizedBox(height: AppSpacing.sm),
                const _MainControls(),
                const SizedBox(height: AppSpacing.lg),
                _SecondaryActions(kirtan: kirtan),
                const SizedBox(height: AppSpacing.lg),
              ];
              final EdgeInsets padding = EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 360
                    ? AppSpacing.lg
                    : AppSpacing.xl,
              );
              // Very small screens / large text: scroll instead of squeezing.
              if (constraints.maxHeight < 600) {
                return SingleChildScrollView(
                  padding: padding,
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: (constraints.maxWidth * 0.62).clamp(
                          160.0,
                          260.0,
                        ),
                        child: _Artwork(kirtan: kirtan),
                      ),
                      ...controls,
                    ],
                  ),
                );
              }
              return Padding(
                padding: padding,
                child: Column(
                  children: <Widget>[
                    Expanded(child: _Artwork(kirtan: kirtan)),
                    ...controls,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static void _close(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(Routes.kirtan);
    }
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.kirtan});

  final Kirtan kirtan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: AppRadius.xlAll,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Hero(
              tag: kKirtanArtworkHeroTag,
              child: AnimatedSwitcher(
                duration: AppDurations.slow,
                child: KirtanArtwork(
                  key: ValueKey<String>(kirtan.id),
                  kirtan: kirtan,
                  borderRadius: AppRadius.xlAll,
                  useMurtiFallback: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.kirtan});

  final Kirtan kirtan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String credits = kirtan.credits(context.appLanguage.code);
    return Column(
      children: <Widget>[
        Text(
          kirtan.title.of(context),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall,
        ),
        if (credits.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            credits,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressSection extends ConsumerWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final KirtanProgress progress =
        ref.watch(kirtanProgressProvider).value ?? KirtanProgress.zero;
    final ThemeData theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;
    return ProgressBar(
      progress: progress.position,
      buffered: progress.buffered,
      total: progress.total,
      onSeek: (Duration position) =>
          ref.read(kirtanPlayerProvider.notifier).seek(position),
      thumbRadius: 8,
      thumbGlowRadius: 22,
      progressBarColor: primary,
      bufferedBarColor: primary.withValues(alpha: 0.3),
      baseBarColor: primary.withValues(alpha: 0.12),
      thumbColor: primary,
      thumbGlowColor: primary.withValues(alpha: 0.2),
      timeLabelPadding: AppSpacing.xs,
      timeLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

class _MainControls extends ConsumerWidget {
  const _MainControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final KirtanPlayerController controller = ref.read(
      kirtanPlayerProvider.notifier,
    );
    final bool playing = ref.watch(kirtanIsPlayingProvider);
    final bool loading = ref.watch(kirtanIsLoadingProvider);
    final bool hasNext = ref.watch(kirtanHasNextProvider);
    final bool shuffle = ref.watch(kirtanShuffleProvider).value ?? false;
    final LoopMode loop =
        ref.watch(kirtanLoopModeProvider).value ?? LoopMode.off;

    void tap(Future<void> Function() action) {
      unawaited(HapticFeedback.selectionClick());
      unawaited(action());
    }

    final Color idle = scheme.onSurfaceVariant;
    // Scales down (never overflows) on very narrow phones.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: max(constraints.maxWidth, 288),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                tooltip: l10n.kirtanShuffle,
                isSelected: shuffle,
                iconSize: 26,
                color: shuffle ? scheme.primary : idle,
                onPressed: () => tap(controller.toggleShuffle),
                icon: const Icon(Icons.shuffle_rounded),
              ),
              IconButton(
                tooltip: l10n.previous,
                iconSize: 40,
                onPressed: () => tap(controller.skipToPrevious),
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              SizedBox.square(
                dimension: 80,
                child: IconButton.filled(
                  tooltip: playing ? l10n.pause : l10n.play,
                  iconSize: 44,
                  onPressed: () => tap(controller.togglePlayPause),
                  icon: AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: loading
                        ? SizedBox.square(
                            key: const ValueKey<String>('loading'),
                            dimension: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey<bool>(playing),
                          ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.next,
                iconSize: 40,
                onPressed: hasNext ? () => tap(controller.skipToNext) : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              IconButton(
                tooltip: switch (loop) {
                  LoopMode.off => l10n.kirtanRepeatOff,
                  LoopMode.all => l10n.kirtanRepeat,
                  LoopMode.one => l10n.kirtanRepeatOne,
                },
                isSelected: loop != LoopMode.off,
                iconSize: 26,
                color: loop == LoopMode.off ? idle : scheme.primary,
                onPressed: () => tap(controller.cycleRepeat),
                icon: Icon(
                  loop == LoopMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryActions extends ConsumerWidget {
  const _SecondaryActions({required this.kirtan});

  final Kirtan kirtan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final KirtanDownloadView download = watchKirtanDownload(ref, kirtan);
    final double speed = ref.watch(kirtanSpeedProvider).value ?? 1.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _ActionButton(
            icon: KirtanDownloadIcon(
              view: download,
              color: download.isDownloaded ? scheme.primary : scheme.onSurface,
            ),
            label: download.isDownloading
                ? l10n.downloading
                : download.isDownloaded
                ? l10n.downloaded
                : l10n.download,
            tooltip: download.isDownloading
                ? l10n.kirtanCancelDownload
                : download.isDownloaded
                ? l10n.kirtanRemoveDownload
                : l10n.download,
            active: download.isDownloaded,
            onTap: () => onKirtanDownloadTap(context, ref, kirtan, download),
          ),
        ),
        Expanded(
          child: _ActionButton(
            icon: const Icon(Icons.lyrics_outlined),
            label: l10n.kirtanLyrics,
            onTap: () => showKirtanLyricsSheet(context, kirtan),
          ),
        ),
        const Expanded(child: _SleepTimerAction()),
        Expanded(
          child: _ActionButton(
            icon: const Icon(Icons.speed_rounded),
            label: (speed - 1.0).abs() < 0.01
                ? l10n.playbackSpeed
                : formatKirtanSpeed(speed),
            tooltip: l10n.playbackSpeed,
            active: (speed - 1.0).abs() >= 0.01,
            onTap: () => showKirtanSpeedSheet(context),
          ),
        ),
      ],
    );
  }
}

/// Shows the countdown while a timed sleep timer runs.
class _SleepTimerAction extends ConsumerStatefulWidget {
  const _SleepTimerAction();

  @override
  ConsumerState<_SleepTimerAction> createState() => _SleepTimerActionState();
}

class _SleepTimerActionState extends ConsumerState<_SleepTimerAction> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(KirtanSleepTimer timer) {
    if (timer.endsAt != null) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final KirtanSleepTimer timer = ref.watch(kirtanSleepTimerProvider);
    _syncTicker(timer);
    final Duration? remaining = timer.remaining(DateTime.now());
    final String label = remaining != null
        ? Formatters.duration(remaining)
        : timer.endOfKirtan
        ? l10n.sleepTimerEndOfTrack
        : l10n.sleepTimer;
    return _ActionButton(
      icon: Icon(
        timer.isActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
      ),
      label: label,
      tooltip: remaining != null
          ? l10n.kirtanSleepTimerRemaining(Formatters.duration(remaining))
          : l10n.sleepTimer,
      active: timer.isActive,
      onTap: () => showKirtanSleepTimerSheet(context),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final Widget icon;
  final String label;
  final String? tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconTheme.merge(
                  data: IconThemeData(color: color, size: 26),
                  child: icon,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
