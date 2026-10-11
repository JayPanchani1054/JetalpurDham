import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/ui_feedback.dart';
import '../../data/library_repository.dart';
import '../../domain/book.dart';
import '../library_labels.dart';

/// Downloads [book] for offline reading and confirms the result with a
/// snackbar. Keeps working when the user leaves the screen meanwhile: the
/// download runs in the app-wide [DownloadManager].
Future<void> startBookDownload(
  BuildContext context,
  WidgetRef ref,
  Book book,
) async {
  unawaited(HapticFeedback.selectionClick());
  // Captured up front: the widget may be gone when the download finishes.
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final AppLocalizations l10n = context.l10n;
  final bool offline = !(ref.read(isOnlineProvider).value ?? true);
  final DownloadKey key = bookDownloadKey(book.id);

  final File? file = await container
      .read(downloadManagerProvider.notifier)
      .download(key, book.pdfUrl);
  final DownloadStatus status =
      (container.read(downloadManagerProvider)[key] ?? DownloadState.none)
          .status;
  final String? message = file != null
      ? l10n.libraryDownloadComplete
      : status == DownloadStatus.failed
      ? (offline ? l10n.errorNetwork : l10n.libraryDownloadFailed)
      : null; // cancelled, or already running
  if (message == null || messenger == null || !messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Stops a running download of [bookId].
void cancelBookDownload(WidgetRef ref, String bookId) {
  unawaited(HapticFeedback.selectionClick());
  ref.read(downloadManagerProvider.notifier).cancel(bookDownloadKey(bookId));
}

/// Asks before deleting the offline copy of [bookId].
Future<void> confirmRemoveBookDownload(
  BuildContext context,
  WidgetRef ref,
  String bookId,
) async {
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded),
      title: Text(l10n.libraryRemoveDownload),
      content: Text(l10n.libraryRemoveDownloadConfirm),
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
  unawaited(HapticFeedback.selectionClick());
  try {
    await container
        .read(downloadManagerProvider.notifier)
        .delete(bookDownloadKey(bookId));
  } catch (error, stack) {
    AppLogger.error('Could not remove book $bookId', error, stack);
    if (context.mounted) context.showSnack(l10n.errorGeneric);
  }
}

/// Download / progress / "Available offline" block on the book page.
class BookDownloadSection extends ConsumerStatefulWidget {
  const BookDownloadSection({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<BookDownloadSection> createState() =>
      _BookDownloadSectionState();
}

class _BookDownloadSectionState extends ConsumerState<BookDownloadSection> {
  @override
  void initState() {
    super.initState();
    // Sync with the file system (e.g. after "Remove all" in Settings).
    unawaited(
      ref
          .read(downloadManagerProvider.notifier)
          .localFile(bookDownloadKey(widget.book.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DownloadState download = ref.watch(
      downloadStateProvider(bookDownloadKey(widget.book.id)),
    );
    final Widget child;
    if (download.isDownloading) {
      child = _DownloadingBox(
        key: const ValueKey<String>('downloading'),
        progress: download.progress,
        onCancel: () => cancelBookDownload(ref, widget.book.id),
      );
    } else if (download.isDownloaded) {
      child = _OfflineBox(
        key: const ValueKey<String>('downloaded'),
        onRemove: () => confirmRemoveBookDownload(context, ref, widget.book.id),
      );
    } else {
      final int? size = widget.book.sizeBytes;
      final AppLocalizations l10n = context.l10n;
      child = SizedBox(
        key: const ValueKey<String>('idle'),
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => startBookDownload(context, ref, widget.book),
          icon: const Icon(Icons.download_rounded),
          label: Text(
            size == null
                ? l10n.libraryDownloadForOffline
                : l10n.libraryDownloadWithSize(Formatters.bytes(size)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return AnimatedSwitcher(duration: AppDurations.medium, child: child);
  }
}

class _DownloadingBox extends StatelessWidget {
  const _DownloadingBox({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool known = progress >= 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  known
                      ? l10n.libraryDownloadingProgress(
                          formatPercent(context, progress),
                        )
                      : l10n.downloading,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(
                    value: known ? progress.clamp(0.02, 1.0) : null,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.libraryCancelDownload,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _OfflineBox extends StatelessWidget {
  const _OfflineBox({super.key, required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.offline_pin_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.libraryAvailableOffline,
              style: theme.textTheme.titleSmall,
            ),
          ),
          TextButton(onPressed: onRemove, child: Text(l10n.remove)),
        ],
      ),
    );
  }
}

/// App bar action in the reader: download for offline, progress (tap to
/// cancel), or a check when the book is already saved.
class ReaderDownloadAction extends ConsumerWidget {
  const ReaderDownloadAction({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DownloadState download = ref.watch(
      downloadStateProvider(bookDownloadKey(bookId)),
    );
    if (download.isDownloaded) {
      return IconButton(
        tooltip: l10n.libraryAvailableOffline,
        onPressed: () => context.showSnack(l10n.libraryAvailableOffline),
        icon: Icon(Icons.offline_pin_rounded, color: scheme.primary),
      );
    }
    if (download.isDownloading) {
      final bool known = download.progress >= 0;
      return IconButton(
        tooltip: l10n.libraryCancelDownload,
        onPressed: () => cancelBookDownload(ref, bookId),
        icon: SizedBox.square(
          dimension: 24,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: known ? download.progress.clamp(0.03, 1.0) : null,
                  strokeWidth: 2.5,
                  backgroundColor: scheme.primary.withValues(alpha: 0.15),
                ),
              ),
              Icon(Icons.stop_rounded, size: 13, color: scheme.primary),
            ],
          ),
        ),
      );
    }
    final Book? book = ref.watch(
      bookProvider(bookId).select((AsyncValue<Book?> value) => value.value),
    );
    return IconButton(
      tooltip: l10n.libraryDownloadForOffline,
      onPressed: book == null
          ? null
          : () => startBookDownload(context, ref, book),
      icon: const Icon(Icons.download_for_offline_outlined),
    );
  }
}
