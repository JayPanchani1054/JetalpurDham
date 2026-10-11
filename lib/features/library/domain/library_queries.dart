import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'book.dart';

/// Pure list and reader helpers for the Shastra library. Free of Flutter
/// widgets and Firebase so they are cheap to unit test and safe to run on
/// every rebuild.

/// Active, readable books sorted by `order`, then title.
List<Book> sortActiveBooks(Iterable<Book> books) {
  final List<Book> list =
      books.where((Book b) => b.isActive && b.isReadable).toList()
        ..sort(Book.compare);
  return List<Book>.unmodifiable(list);
}

/// Active categories sorted by `order`, then name.
List<BookCategory> sortActiveBookCategories(Iterable<BookCategory> items) {
  final List<BookCategory> list =
      items.where((BookCategory c) => c.isActive).toList()
        ..sort(BookCategory.compare);
  return List<BookCategory>.unmodifiable(list);
}

/// Categories that contain at least one of [books], so a chip never leads to
/// an empty grid.
List<BookCategory> bookCategoriesInUse(
  List<BookCategory> categories,
  List<Book> books,
) {
  final Set<String> used = <String>{
    for (final Book b in books)
      if (b.categoryId != null) b.categoryId!,
  };
  return categories
      .where((BookCategory c) => used.contains(c.id))
      .toList(growable: false);
}

/// The book with [id], or null when it does not exist or is hidden.
Book? findBook(Iterable<Book> books, String id) {
  for (final Book book in books) {
    if (book.id == id) return book;
  }
  return null;
}

/// What the chip row is filtering by.
@immutable
class LibraryFilter {
  const LibraryFilter._(this.kind, this.categoryId);

  static const LibraryFilter all = LibraryFilter._(LibraryFilterKind.all, null);
  static const LibraryFilter downloaded = LibraryFilter._(
    LibraryFilterKind.downloaded,
    null,
  );

  const LibraryFilter.category(String id)
    : this._(LibraryFilterKind.category, id);

  final LibraryFilterKind kind;
  final String? categoryId;

  bool get isAll => kind == LibraryFilterKind.all;

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      other.kind == kind &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(kind, categoryId);
}

enum LibraryFilterKind { all, downloaded, category }

/// Books matching [filter] whose title or author contains [query] in any
/// language. [downloadedIds] are the ids of books saved on this device.
List<Book> filterBooks(
  List<Book> books, {
  String query = '',
  LibraryFilter filter = LibraryFilter.all,
  Set<String> downloadedIds = const <String>{},
}) {
  final String q = query.trim();
  if (q.isEmpty && filter.isAll) return books;
  bool inFilter(Book b) => switch (filter.kind) {
    LibraryFilterKind.all => true,
    LibraryFilterKind.downloaded => downloadedIds.contains(b.id),
    LibraryFilterKind.category => b.categoryId == filter.categoryId,
  };
  return books
      .where((Book b) => inFilter(b) && b.matches(q))
      .toList(growable: false);
}

/// A category filter whose category disappeared from the console falls back
/// to "All" so the screen never shows a stale, unselectable chip.
LibraryFilter effectiveLibraryFilter(
  LibraryFilter filter,
  List<BookCategory> categories,
) {
  if (filter.kind != LibraryFilterKind.category) return filter;
  return categories.any((BookCategory c) => c.id == filter.categoryId)
      ? filter
      : LibraryFilter.all;
}

/// Parses a page number typed by the reader. Accepts ASCII, Gujarati
/// (૦-૯) and Devanagari (०-९) digits and surrounding spaces. Returns null
/// when the text is not a whole number between 1 and [pageCount].
int? parsePageInput(String input, int pageCount) {
  final String text = input.trim();
  if (text.isEmpty || pageCount < 1) return null;
  final StringBuffer ascii = StringBuffer();
  for (final int rune in text.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      ascii.writeCharCode(rune);
    } else if (rune >= 0x0AE6 && rune <= 0x0AEF) {
      ascii.writeCharCode(0x30 + rune - 0x0AE6); // Gujarati digits
    } else if (rune >= 0x0966 && rune <= 0x096F) {
      ascii.writeCharCode(0x30 + rune - 0x0966); // Devanagari digits
    } else {
      return null;
    }
  }
  final String digits = ascii.toString();
  if (digits.length > 9) return null;
  final int? page = int.tryParse(digits);
  if (page == null || page < 1 || page > pageCount) return null;
  return page;
}

/// Zoom level after a double tap: a page that is zoomed in returns to the
/// fit-width level, otherwise it zooms in for comfortable reading of small
/// print (never beyond [maxZoom]).
double doubleTapZoomTarget({
  required double currentZoom,
  required double fitZoom,
  required double maxZoom,
  double zoomInFactor = 2.5,
}) {
  if (fitZoom <= 0) return currentZoom;
  if (currentZoom > fitZoom * 1.2) return fitZoom;
  return math.max(fitZoom, math.min(fitZoom * zoomInFactor, maxZoom));
}

/// Reading progress 0..1 for "page [page] of [pageCount]", or null when the
/// total is unknown.
double? readingFraction(int page, int? pageCount) {
  if (pageCount == null || pageCount <= 0) return null;
  return (page / pageCount).clamp(0.0, 1.0);
}

/// The ids of books whose PDF is fully downloaded, as one canonical string
/// (sorted, NUL-separated). Used with `select` so widgets rebuild only when
/// the set of downloaded books actually changes, not on every progress tick.
String downloadedIdsSignature(Iterable<String> ids) {
  final List<String> sorted = ids.toSet().toList()..sort();
  return sorted.join('\u0000');
}

/// Inverse of [downloadedIdsSignature].
Set<String> idsFromSignature(String signature) => signature.isEmpty
    ? const <String>{}
    : Set<String>.unmodifiable(signature.split('\u0000'));
