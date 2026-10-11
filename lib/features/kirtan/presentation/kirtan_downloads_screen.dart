import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/kirtan_downloads_controller.dart';
import '../application/kirtan_player_controller.dart';
import '../data/kirtan_downloads_index.dart';
import '../data/kirtan_repository.dart';
import '../domain/kirtan.dart';
import 'kirtan_screen.dart';
import 'widgets/kirtan_download_button.dart';
import 'widgets/kirtan_tile.dart';

/// Kirtans saved on this phone. Works fully offline: everything shown comes
/// from the local downloads index (refreshed with live titles when online).
class KirtanDownloadsScreen extends ConsumerStatefulWidget {
  const KirtanDownloadsScreen({super.key});

  @override
  ConsumerState<KirtanDownloadsScreen> createState() =>
      _KirtanDownloadsScreenState();
}

class _KirtanDownloadsScreenState extends ConsumerState<KirtanDownloadsScreen> {
  @override
  void initState() {
    super.initState();
    // Files may have been removed elsewhere (e.g. Settings → Remove all).
    unawaited(
      Future<void>.microtask(() async {
        if (mounted) await ref.read(kirtanDownloadsProvider.notifier).prune();
      }),
    );
  }

  void _play(List<Kirtan> list, int index) {
    unawaited(HapticFeedback.selectionClick());
    if (ref.read(currentKirtanProvider)?.id == list[index].id) {
      unawaited(context.push<void>(Routes.player));
      return;
    }
    unawaited(
      ref
          .read(kirtanPlayerProvider.notifier)
          .playKirtans(list, startIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final KirtanDownloadsIndex index = ref.watch(kirtanDownloadsProvider);
    final List<Kirtan>? live = ref.watch(kirtansProvider).value;
    final Map<String, Kirtan> liveById = <String, Kirtan>{
      for (final Kirtan k in live ?? const <Kirtan>[]) k.id: k,
    };
    // Prefer the latest titles/lyrics from Firestore when available.
    final List<Kirtan> kirtans = <Kirtan>[
      for (final DownloadedKirtan d in index.items)
        liveById[d.kirtan.id] ?? d.kirtan,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kirtanDownloads),
        actions: const <Widget>[LanguageButton()],
      ),
      body: kirtans.isEmpty
          ? EmptyState(
              icon: Icons.download_for_offline_outlined,
              title: l10n.kirtanDownloadsEmpty,
              action: FilledButton.tonalIcon(
                onPressed: () => context.go(Routes.kirtan),
                icon: const Icon(Icons.library_music_rounded),
                label: Text(l10n.kirtanBrowse),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              itemCount: kirtans.length + 1,
              itemBuilder: (BuildContext context, int i) {
                if (i == 0) {
                  return KirtanPlayAllHeader(
                    icon: Icons.offline_pin_outlined,
                    label:
                        '${l10n.kirtanCount(kirtans.length)} · '
                        '${Formatters.bytes(index.totalBytes)}',
                    onPlayAll: () => ref
                        .read(kirtanPlayerProvider.notifier)
                        .playAll(kirtans),
                    onShuffle: () => ref
                        .read(kirtanPlayerProvider.notifier)
                        .playAll(kirtans, shuffle: true),
                  );
                }
                final Kirtan kirtan = kirtans[i - 1];
                return KirtanTile(
                  key: ValueKey<String>(kirtan.id),
                  kirtan: kirtan,
                  onTap: () => _play(kirtans, i - 1),
                  trailing: IconButton(
                    tooltip: l10n.kirtanRemoveDownload,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () =>
                        confirmRemoveKirtanDownload(context, ref, kirtan),
                  ),
                );
              },
            ),
    );
  }
}
