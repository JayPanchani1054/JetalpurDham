import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/book.dart';

/// A book cover at 3:4 with rounded corners and a soft shadow. Uses the cover
/// image from Firestore when there is one, otherwise an elegant generated
/// cover, so a newly uploaded PDF looks good from the first minute.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.heroTag,
    this.borderRadius = AppRadius.smAll,
    this.elevated = true,
  });

  final Book book;
  final Object? heroTag;
  final BorderRadius borderRadius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Widget generated = GeneratedBookCover(title: book.title.of(context));
    Widget cover = ClipRRect(
      borderRadius: borderRadius,
      // A broken or unreachable cover image falls back to the generated
      // cover instead of a generic icon.
      child: book.hasCover
          ? AppNetworkImage(
              url: book.coverUrl,
              placeholderIcon: Icons.menu_book_rounded,
              fallback: generated,
            )
          : generated,
    );
    cover = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.45 : 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: cover,
    );
    if (heroTag != null) cover = Hero(tag: heroTag!, child: cover);
    return AspectRatio(aspectRatio: 3 / 4, child: cover);
  }
}

/// Saffron-to-maroon cover with the title in large type inside a thin gold
/// double frame, used when a book has no cover image.
class GeneratedBookCover extends StatelessWidget {
  const GeneratedBookCover({super.key, required this.title});

  final String title;

  static const LinearGradient _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      AppColors.saffronBright,
      AppColors.saffron,
      AppColors.maroon,
    ],
    stops: <double>[0, 0.45, 1],
  );

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        Theme.of(context).textTheme.titleLarge ?? const TextStyle();
    // Purely decorative: the title is always shown as text next to the cover.
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _gradient),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : 120;
            final bool compact = width < 80;
            final double inset = (width * 0.055).clamp(3.0, 14.0);
            final double padding2 = compact ? 2 : inset * 0.5;
            final double padding3 = compact ? 2 : inset;
            final double textWidth = math.max(
              8,
              width - 2 * (inset + padding2 + padding3) - 4,
            );
            // Never break a word: shrink until the longest word fits.
            final double fontSize = _fitFontSize(
              title,
              base.copyWith(fontWeight: FontWeight.w700),
              textWidth,
              (width * 0.11).clamp(8.0, 30.0),
            );
            final Color gold = AppColors.goldLight.withValues(alpha: 0.85);
            return Padding(
              padding: EdgeInsets.all(inset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: gold, width: compact ? 0.8 : 1.2),
                  borderRadius: BorderRadius.circular(inset * 0.6),
                ),
                child: Padding(
                  padding: EdgeInsets.all(padding2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.goldLight.withValues(alpha: 0.4),
                        width: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(inset * 0.4),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: padding3,
                        vertical: compact ? 2 : inset * 1.2,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          if (!compact) ...<Widget>[
                            Icon(
                              Icons.spa_rounded,
                              color: AppColors.goldLight,
                              size: (width * 0.13).clamp(12.0, 32.0),
                            ),
                            SizedBox(height: inset),
                          ],
                          Flexible(
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: compact ? 3 : 5,
                              overflow: TextOverflow.ellipsis,
                              // Sized to the cover, independent of the
                              // accessibility text size (the title is also
                              // shown as regular, scalable text).
                              textScaler: TextScaler.noScaling,
                              style: base.copyWith(
                                color: Colors.white,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                shadows: const <Shadow>[
                                  Shadow(
                                    color: Color(0x40000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!compact) ...<Widget>[
                            SizedBox(height: inset),
                            Container(
                              width: width * 0.22,
                              height: 1.2,
                              color: gold,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Largest font size (<= [start]) at which the longest word of [text] fits in
/// [maxWidth], so cover titles wrap between words, never inside one.
double _fitFontSize(
  String text,
  TextStyle style,
  double maxWidth,
  double start,
) {
  final List<String> words = text
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return start;
  double size = start;
  final TextPainter painter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  try {
    while (size > 8) {
      double widest = 0;
      for (final String word in words) {
        painter
          ..text = TextSpan(
            text: word,
            style: style.copyWith(fontSize: size),
          )
          ..layout();
        widest = math.max(widest, painter.width);
      }
      if (widest <= maxWidth) break;
      size -= 1;
    }
  } finally {
    painter.dispose();
  }
  return size;
}
