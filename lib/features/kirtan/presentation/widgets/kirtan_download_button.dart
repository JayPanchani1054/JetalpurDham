import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/kirtan_downloads_controller.dart';
import '../../data/kirtan_downloads_index.dart';
import '../../domain/kirtan.dart';

/// What the download control should show for a kirtan.
@immutable
class KirtanDownloadView {
  const KirtanDownloadView.idle()
    : status = DownloadStatus.notDownloaded,
      progress = 0;
  const KirtanDownloadView.downloading(this.progress)
    : status = DownloadStatus.downloading;
  const KirtanDownloadView.downloaded()
    : status = DownloadStatus.downloaded,
      progress = 1;

  /// Combines the live file state with the offline index. An indexed kirtan
  /// counts as downloaded until the file check says otherwise (no flicker on
  /// launch); a failed download offers the download icon again.
  factory KirtanDownloadView.from(
    DownloadState state, {
    required bool indexed,
  }) {
    if (state.isDownloading) {
      return KirtanDownloadView.downloading(state.progress);
    }
    if (state.isDownloaded) return const KirtanDownloadView.downloaded();
    if (indexed && state.status == DownloadStatus.notDownloaded) {
      return const KirtanDownloadView.downloaded();
    }
    return const KirtanDownloadView.idle();
  }

  final DownloadStatus status;

  /// 0..1, or negative when the size is unknown.
  final double progress;

  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isDownloaded => status == DownloadStatus.downloaded;
}

/// Watches the download state of [kirtan] (rebuilds only for that kirtan).
KirtanDownloadView watchKirtanDownload(WidgetRef ref, Kirtan kirtan) {
  final String? extension = ref.watch(
    kirtanDownloadsProvider.select(
      (KirtanDownloadsIndex index) => index[kirtan.id]?.extension,
    ),
  );
  final DownloadKey key = kirtanDownloadKey(
    kirtan.id,
    extension ?? kirtanAudioExtension(kirtan.audioUrl),
  );
  return KirtanDownloadView.from(
    ref.watch(downloadStateProvider(key)),
    indexed: extension != null,
  );
}

/// Download → progress (tap to cancel) → downloaded (tap to remove).
Future<void> onKirtanDownloadTap(
  BuildContext context,
  WidgetRef ref,
  Kirtan kirtan,
  KirtanDownloadView view,
) async {
  final KirtanDownloadsController controller = ref.read(
    kirtanDownloadsProvider.notifier,
  );
  if (view.isDownloaded) {
    await confirmRemoveKirtanDownload(context, ref, kirtan);
    return;
  }
  HapticFeedback.selectionClick().ignore();
  if (view.isDownloading) {
    controller.cancel(kirtan);
    return;
  }
  // Captured now: the row may scroll away before the download finishes.
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final AppLocalizations l10n = context.l10n;
  final bool offline = !(ref.read(isOnlineProvider).value ?? true);
  final KirtanDownloadResult result = await controller.download(kirtan);
  final String? message = switch (result) {
    KirtanDownloadResult.saved => l10n.kirtanDownloadComplete,
    KirtanDownloadResult.failed =>
      offline ? l10n.errorNetwork : l10n.kirtanDownloadFailed,
    KirtanDownloadResult.cancelled => null,
  };
  if (message == null || messenger == null || !messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks before deleting an offline kirtan.
Future<void> confirmRemoveKirtanDownload(
  BuildContext context,
  WidgetRef ref,
  Kirtan kirtan,
) async {
  final KirtanDownloadsController controller = ref.read(
    kirtanDownloadsProvider.notifier,
  );
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded),
      title: Text(l10n.kirtanRemoveDownload),
      content: Text(l10n.kirtanRemoveDownloadConfirm),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.remove),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false)) return;
  await HapticFeedback.selectionClick();
  await controller.remove(kirtan);
}

/// Compact icon button for list rows.
class KirtanDownloadButton extends ConsumerWidget {
  const KirtanDownloadButton({super.key, required this.kirtan});

  final Kirtan kirtan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final KirtanDownloadView view = watchKirtanDownload(ref, kirtan);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: view.isDownloading
          ? l10n.kirtanCancelDownload
          : view.isDownloaded
          ? l10n.kirtanAvailableOffline
          : l10n.download,
      onPressed: () => onKirtanDownloadTap(context, ref, kirtan, view),
      icon: AnimatedSwitcher(
        duration: AppDurations.medium,
        child: KirtanDownloadIcon(
          key: ValueKey<DownloadStatus>(view.status),
          view: view,
          color: view.isDownloaded ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The icon for a [KirtanDownloadView]: download arrow, a progress ring with
/// a stop mark, or a check.
class KirtanDownloadIcon extends StatelessWidget {
  const KirtanDownloadIcon({
    super.key,
    required this.view,
    required this.color,
    this.size = 24,
  });

  final KirtanDownloadView view;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (view.isDownloaded) {
      return Icon(Icons.download_done_rounded, color: color, size: size);
    }
    if (!view.isDownloading) {
      return Icon(Icons.download_rounded, color: color, size: size);
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: CircularProgressIndicator(
              value: view.progress < 0 ? null : view.progress.clamp(0.03, 1.0),
              strokeWidth: 2.5,
              color: scheme.primary,
              backgroundColor: scheme.primary.withValues(alpha: 0.15),
            ),
          ),
          Icon(Icons.stop_rounded, size: size * 0.55, color: scheme.primary),
        ],
      ),
    );
  }
}
