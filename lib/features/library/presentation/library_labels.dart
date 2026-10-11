import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/book.dart';

/// Display name of a book's PDF language, or null when unknown.
String? bookLanguageLabel(AppLocalizations l10n, String? code) =>
    switch (code) {
      BookLanguages.gujarati => l10n.langGujarati,
      BookLanguages.hindi => l10n.langHindi,
      BookLanguages.english => l10n.langEnglish,
      BookLanguages.sanskrit => l10n.langSanskrit,
      _ => null,
    };

/// Locale-aware percentage, e.g. `45%`, for download/preparation progress.
String formatPercent(BuildContext context, double fraction) {
  final double value = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0;
  try {
    return NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);
  } catch (_) {
    return NumberFormat.percentPattern().format(value);
  }
}

/// Hero tag shared by a book's cover in the grid and on its detail page.
String bookCoverHeroTag(String bookId) => 'library-book-cover-$bookId';
