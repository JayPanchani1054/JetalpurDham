import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/services/preferences.dart';

/// SharedPreferences keys used by the library. All start with `library.` so
/// they never collide with other features.
abstract final class LibraryPrefKeys {
  /// Id of the book opened most recently ("Continue reading").
  static const String lastBookId = 'library.lastBookId';

  /// `library.lastPage.<bookId>` → last page read (1-based).
  static const String lastPagePrefix = PrefKeys.libraryLastPagePrefix;

  /// `library.pageCount.<bookId>` → page count seen when the PDF was opened.
  static const String pageCountPrefix = 'library.pageCount.';

  static String lastPage(String bookId) => '$lastPagePrefix$bookId';
  static String pageCount(String bookId) => '$pageCountPrefix$bookId';
}

/// Where the devotee stopped in each book, plus the last book opened.
@immutable
class ReadingProgress {
  const ReadingProgress({
    this.lastBookId,
    this.pages = const <String, int>{},
    this.pageCounts = const <String, int>{},
  });

  /// Builds the progress from raw preference entries (key → value). Unknown
  /// keys and malformed values are ignored. Never throws.
  factory ReadingProgress.fromEntries(Map<String, Object?> entries) {
    String? lastBookId;
    final Map<String, int> pages = <String, int>{};
    final Map<String, int> counts = <String, int>{};
    entries.forEach((String key, Object? value) {
      if (key == LibraryPrefKeys.lastBookId) {
        lastBookId = Fs.stringOrNull(value);
      } else if (key.startsWith(LibraryPrefKeys.lastPagePrefix)) {
        final String id = key.substring(LibraryPrefKeys.lastPagePrefix.length);
        final int? page = Fs.integerOrNull(value);
        if (id.isNotEmpty && page != null && page > 0) pages[id] = page;
      } else if (key.startsWith(LibraryPrefKeys.pageCountPrefix)) {
        final String id = key.substring(LibraryPrefKeys.pageCountPrefix.length);
        final int? count = Fs.integerOrNull(value);
        if (id.isNotEmpty && count != null && count > 0) counts[id] = count;
      }
    });
    return ReadingProgress(
      lastBookId: lastBookId,
      pages: Map<String, int>.unmodifiable(pages),
      pageCounts: Map<String, int>.unmodifiable(counts),
    );
  }

  final String? lastBookId;
  final Map<String, int> pages;
  final Map<String, int> pageCounts;

  /// Last page read in [bookId] (1-based), or null if never opened.
  int? pageFor(String bookId) => pages[bookId];

  /// Page count recorded when [bookId] was last opened.
  int? pageCountFor(String bookId) => pageCounts[bookId];

  /// True when the reader should offer "Continue from page N" (page > 1).
  bool canResume(String bookId) => (pages[bookId] ?? 1) > 1;

  ReadingProgress withLastBook(String bookId) =>
      ReadingProgress(lastBookId: bookId, pages: pages, pageCounts: pageCounts);

  ReadingProgress withPage(String bookId, int page, {int? pageCount}) =>
      ReadingProgress(
        lastBookId: lastBookId,
        pages: Map<String, int>.unmodifiable(<String, int>{
          ...pages,
          bookId: page,
        }),
        pageCounts: pageCount == null || pageCount <= 0
            ? pageCounts
            : Map<String, int>.unmodifiable(<String, int>{
                ...pageCounts,
                bookId: pageCount,
              }),
      );

  @override
  bool operator ==(Object other) =>
      other is ReadingProgress &&
      other.lastBookId == lastBookId &&
      mapEquals(other.pages, pages) &&
      mapEquals(other.pageCounts, pageCounts);

  @override
  int get hashCode => Object.hash(
    lastBookId,
    Object.hashAllUnordered(
      pages.entries.map(
        (MapEntry<String, int> e) => Object.hash(e.key, e.value),
      ),
    ),
    Object.hashAllUnordered(
      pageCounts.entries.map(
        (MapEntry<String, int> e) => Object.hash(e.key, e.value),
      ),
    ),
  );
}
