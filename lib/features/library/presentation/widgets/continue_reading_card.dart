import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/book.dart';
import '../../domain/library_queries.dart';
import 'book_cover.dart';

/// "Continue reading" card for the book opened most recently: cover, title,
/// the page reached and a slim progress bar. Tapping reopens the reader at
/// that page.
class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    required this.book,
    required this.page,
    required this.pageCount,
    required this.onTap,
  });

  final Book book;
  final int page;
  final int? pageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final double? fraction = readingFraction(page, pageCount);
    final String pageLabel = pageCount == null
        ? l10n.libraryPageNumber(page)
        : l10n.readerPageOf(page, pageCount!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Card(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 60,
                  child: BookCover(book: book, elevated: false),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.libraryContinueReading,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        book.title.of(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        pageLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (fraction != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(3),
                          ),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 5,
                            backgroundColor: scheme.surface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: AppSpacing.minTouchTarget,
                  height: AppSpacing.minTouchTarget,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: scheme.onPrimary,
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
