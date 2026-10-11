import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/book.dart';
import '../library_labels.dart';
import 'book_cover.dart';

/// Grid geometry shared by the book grid and its skeleton: 2 columns on
/// phones, more on tablets, and an item height that always fits a 3:4 cover
/// plus two title lines and one author line at the user's text size.
@immutable
class BookGridMetrics {
  const BookGridMetrics._({
    required this.columns,
    required this.itemWidth,
    required this.coverHeight,
    required this.itemExtent,
  });

  factory BookGridMetrics.of(BuildContext context, double totalWidth) {
    final double content = math.max(0, totalWidth - AppSpacing.page * 2);
    final int columns = (content / 190).floor().clamp(2, 6);
    final double itemWidth = math.max(
      0,
      (content - spacingValue * (columns - 1)) / columns,
    );
    final double coverHeight = itemWidth * 4 / 3;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextTheme text = Theme.of(context).textTheme;
    double lineHeight(TextStyle? style, double size, double height) =>
        scaler.scale(style?.fontSize ?? size) * (style?.height ?? height);
    final double extent =
        coverHeight +
        AppSpacing.md +
        lineHeight(text.titleSmall, 15, 1.4) * 2 +
        AppSpacing.xxs +
        lineHeight(text.bodySmall, 13, 1.5) +
        AppSpacing.sm; // breathing room for script-specific glyph metrics
    return BookGridMetrics._(
      columns: columns,
      itemWidth: itemWidth,
      coverHeight: coverHeight,
      itemExtent: extent,
    );
  }

  static const double spacingValue = AppSpacing.lg;

  final int columns;
  final double itemWidth;
  final double coverHeight;
  final double itemExtent;

  double get spacing => spacingValue;
  double get runSpacing => AppSpacing.xl;
}

/// The library grid as a sliver (lazy: only visible covers are built).
class SliverBookGrid extends StatelessWidget {
  const SliverBookGrid({
    super.key,
    required this.books,
    required this.downloadedIds,
    required this.onOpen,
  });

  final List<Book> books;
  final Set<String> downloadedIds;
  final ValueChanged<Book> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (BuildContext context, constraints) {
        final BookGridMetrics metrics = BookGridMetrics.of(
          context,
          constraints.crossAxisExtent,
        );
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: metrics.columns,
              mainAxisSpacing: metrics.runSpacing,
              crossAxisSpacing: metrics.spacing,
              mainAxisExtent: metrics.itemExtent,
            ),
            delegate: SliverChildBuilderDelegate((BuildContext context, int i) {
              final Book book = books[i];
              return BookGridCard(
                key: ValueKey<String>(book.id),
                book: book,
                downloaded: downloadedIds.contains(book.id),
                onTap: () => onOpen(book),
              );
            }, childCount: books.length),
          ),
        );
      },
    );
  }
}

/// One book in the grid: cover (with a "downloaded" badge), title, author.
class BookGridCard extends StatelessWidget {
  const BookGridCard({
    super.key,
    required this.book,
    required this.downloaded,
    required this.onTap,
  });

  final Book book;
  final bool downloaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String author = book.author.of(context);
    final String? subtitle = author.isNotEmpty
        ? author
        : bookLanguageLabel(l10n, book.languageCode);
    return MergeSemantics(
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  BookCover(book: book, heroTag: bookCoverHeroTag(book.id)),
                  if (downloaded)
                    const Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: DownloadedBadge(),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                book.title.of(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          // On top so the ripple is visible over the cover image.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(borderRadius: AppRadius.smAll, onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small round check shown on covers of books saved for offline reading.
class DownloadedBadge extends StatelessWidget {
  const DownloadedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.downloaded,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x40000000), blurRadius: 4),
          ],
        ),
        child: Icon(
          Icons.download_done_rounded,
          size: 16,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
