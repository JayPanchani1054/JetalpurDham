import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/state_views.dart';
import '../library_labels.dart';

/// Calm "Preparing book…" view with download progress when it is known.
class ReaderPreparing extends StatelessWidget {
  const ReaderPreparing({super.key, this.bytesDownloaded, this.totalBytes});

  final int? bytesDownloaded;
  final int? totalBytes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? total = totalBytes;
    final double? progress =
        total != null && total > 0 && bytesDownloaded != null
        ? (bytesDownloaded! / total).clamp(0.0, 1.0)
        : null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.6,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              context.l10n.readerPreparing,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
            ),
            if (progress != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatPercent(context, progress),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error view for the reader. When the book is not on the device and the
/// phone is offline, it explains that internet is needed instead of a
/// generic error.
class ReaderError extends ConsumerWidget {
  const ReaderError({
    super.key,
    required this.onRetry,
    required this.isDownloaded,
  });

  final VoidCallback onRetry;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool offline = !(ref.watch(isOnlineProvider).value ?? true);
    final AppLocalizations l10n = context.l10n;
    if (offline && !isDownloaded) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: l10n.libraryReaderNeedsInternet,
        action: FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retry),
        ),
      );
    }
    return ErrorState(message: l10n.readerOpenFailed, onRetry: onRetry);
  }
}
