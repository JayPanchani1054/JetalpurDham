import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/expandable_text.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../application/reading_progress_controller.dart';
import '../data/library_repository.dart';
import '../domain/book.dart';
import '../domain/reading_progress.dart';
import 'library_labels.dart';
import 'widgets/book_cover.dart';
import 'widgets/book_download_controls.dart';
import 'widgets/library_skeletons.dart';

/// One scripture: cover, title, author, language, pages and size, a large
/// Read / Continue button, download for offline and the description.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Book?> lookup = ref.watch(bookProvider(bookId));
    final Book? book = lookup.value;
    if (book != null) return _BookDetailView(book: book);

    final AppLocalizations l10n = context.l10n;
    void retry() => ref.invalidate(booksProvider);
    final Widget body;
    if (lookup.hasError && !lookup.hasValue) {
      body = ErrorState(onRetry: retry);
    } else if (!lookup.hasValue) {
      body = const BookDetailSkeleton();
    } else if (!(ref.watch(isOnlineProvider).value ?? true)) {
      // Not in the offline cache yet: it may well exist, so don't claim
      // it was removed.
      body = ErrorState(message: l10n.errorNetwork, onRetry: retry);
    } else {
      body = EmptyState(
        icon: Icons.menu_book_outlined,
        title: l10n.libraryBookNotFound,
        action: FilledButton.tonalIcon(
          onPressed: () => context.go(Routes.library),
          icon: const Icon(Icons.auto_stories_rounded),
          label: Text(l10n.libraryTitle),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(actions: const <Widget>[LanguageButton()]),
      body: body,
    );
  }
}

class _BookDetailView extends ConsumerWidget {
  const _BookDetailView({required this.book});

  final Book book;

  void _read(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(context.push(Routes.reader(book.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final (int?, int?) position = ref.watch(
      readingProgressProvider.select(
        (ReadingProgress p) => (p.pageFor(book.id), p.pageCountFor(book.id)),
      ),
    );
    final int? resumePage = position.$1 != null && position.$1! > 1
        ? position.$1
        : null;
    final int? pageCount = book.pageCount ?? position.$2;
    final String author = book.author.of(context);
    final String description = book.description.of(context);
    final String? language = bookLanguageLabel(l10n, book.languageCode);
    final double coverWidth = (MediaQuery.sizeOf(context).width * 0.48).clamp(
      140.0,
      220.0,
    );

    return Scaffold(
      appBar: AppBar(actions: const <Widget>[LanguageButton()]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          Center(
            child: SizedBox(
              width: coverWidth,
              child: BookCover(
                book: book,
                heroTag: bookCoverHeroTag(book.id),
                borderRadius: AppRadius.mdAll,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              book.title.of(context),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          if (author.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              author,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if (language != null)
                _InfoPill(
                  icon: Icons.translate_rounded,
                  label: language,
                  semanticLabel: '${l10n.libraryLanguage}: $language',
                ),
              if (pageCount != null)
                _InfoPill(
                  icon: Icons.description_outlined,
                  label: l10n.libraryPages(pageCount),
                ),
              if (book.sizeBytes != null)
                _InfoPill(
                  icon: Icons.sd_storage_outlined,
                  label: Formatters.bytes(book.sizeBytes),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _read(context),
              icon: const Icon(Icons.auto_stories_rounded),
              label: Text(
                resumePage == null
                    ? l10n.libraryRead
                    : l10n.libraryContinueFromPage(resumePage),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          BookDownloadSection(book: book),
          if (description.isNotEmpty) ...<Widget>[
            SectionHeader(
              title: l10n.libraryAboutBook,
              padding: const EdgeInsets.only(
                top: AppSpacing.xxl,
                bottom: AppSpacing.sm,
              ),
            ),
            ExpandableText(description, collapsedLines: 8),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
