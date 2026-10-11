import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/kirtan_player_controller.dart';
import '../../application/kirtan_player_state.dart';
import '../../application/kirtan_sleep_timer.dart';
import '../../domain/kirtan.dart';
import 'kirtan_tile.dart';

/// Full lyrics in a draggable sheet, in large, comfortable type.
Future<void> showKirtanLyricsSheet(BuildContext context, Kirtan kirtan) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController controller) =>
          _LyricsSheet(kirtan: kirtan, controller: controller),
    ),
  );
}

class _LyricsSheet extends StatelessWidget {
  const _LyricsSheet({required this.kirtan, required this.controller});

  final Kirtan kirtan;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String lyrics = kirtan.lyrics.of(context);
    final String credits = kirtan.credits(context.appLanguage.code);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text(
          l10n.kirtanLyrics,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(kirtan.title.of(context), style: theme.textTheme.headlineSmall),
        if (credits.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            credits,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (lyrics.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.lyrics_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.kirtanNoLyrics,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          SelectableText(
            lyrics,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 19,
              height: 1.9,
            ),
          ),
      ],
    );
  }
}

/// Sleep timer choices: off, 15–60 minutes or the end of this kirtan.
Future<void> showKirtanSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext context) => const _SleepTimerSheet(),
  );
}

class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final KirtanSleepTimer timer = ref.watch(kirtanSleepTimerProvider);
    final KirtanSleepTimerController controller = ref.read(
      kirtanSleepTimerProvider.notifier,
    );

    void choose(VoidCallback action) {
      unawaited(HapticFeedback.selectionClick());
      action();
      Navigator.of(context).pop();
    }

    return _OptionsSheet(
      title: l10n.sleepTimer,
      children: <Widget>[
        _OptionTile(
          icon: Icons.timer_off_outlined,
          label: l10n.sleepTimerOff,
          selected: !timer.isActive,
          onTap: () => choose(controller.cancel),
        ),
        for (final int minutes in kSleepTimerMinutes)
          _OptionTile(
            icon: Icons.bedtime_outlined,
            label: l10n.sleepTimerMinutes(minutes),
            onTap: () =>
                choose(() => controller.startFor(Duration(minutes: minutes))),
          ),
        _OptionTile(
          icon: Icons.music_off_outlined,
          label: l10n.sleepTimerEndOfTrack,
          selected: timer.endOfKirtan,
          onTap: () => choose(controller.stopAtEndOfKirtan),
        ),
      ],
    );
  }
}

/// Playback speed choices (0.75× – 1.5×).
Future<void> showKirtanSpeedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext context) => const _SpeedSheet(),
  );
}

class _SpeedSheet extends ConsumerWidget {
  const _SpeedSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final double current = ref.watch(kirtanSpeedProvider).value ?? 1.0;
    return _OptionsSheet(
      title: l10n.playbackSpeed,
      children: <Widget>[
        for (final double speed in kKirtanSpeeds)
          _OptionTile(
            icon: Icons.speed_rounded,
            label: speed == 1.0
                ? '${formatKirtanSpeed(speed)} · ${l10n.kirtanSpeedNormal}'
                : formatKirtanSpeed(speed),
            selected: (current - speed).abs() < 0.01,
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(
                ref.read(kirtanPlayerProvider.notifier).setSpeed(speed),
              );
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

/// "Up next": the queue in play order starting with the current kirtan.
Future<void> showKirtanQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController controller) =>
          _QueueSheet(controller: controller),
    ),
  );
}

class _QueueSheet extends ConsumerStatefulWidget {
  const _QueueSheet({required this.controller});

  final ScrollController controller;

  @override
  ConsumerState<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<_QueueSheet> {
  // A snapshot, so rows don't jump around while the sheet is open.
  late final List<Kirtan> _items = ref.read(kirtanPlayerProvider).items;
  late final List<int> _order = ref
      .read(kirtanPlayerProvider.notifier)
      .upcomingOrder();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CustomScrollView(
      controller: widget.controller,
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(
              context.l10n.kirtanQueue,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          sliver: SliverList.builder(
            itemCount: _order.length,
            itemBuilder: (BuildContext context, int i) {
              final int index = _order[i];
              if (index < 0 || index >= _items.length) {
                return const SizedBox.shrink();
              }
              return KirtanTile(
                kirtan: _items[index],
                trailing: const SizedBox(width: AppSpacing.md),
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  unawaited(
                    ref.read(kirtanPlayerProvider.notifier).skipToIndex(index),
                  );
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      selected: selected,
      selectedColor: scheme.onPrimaryContainer,
      selectedTileColor: scheme.primaryContainer,
      leading: Icon(icon),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
