import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/models/localized_text.dart';
import 'package:jetalpur_dham/features/library/domain/book.dart';
import 'package:jetalpur_dham/features/library/domain/library_queries.dart';

Book _book(
  String id, {
  String? title,
  String? author,
  String? categoryId,
  int? order,
  bool isActive = true,
  String pdfUrl = 'books/x.pdf',
}) => Book(
  id: id,
  title: LocalizedText.single(title ?? id),
  author: author == null
      ? const LocalizedText.empty()
      : LocalizedText.single(author),
  categoryId: categoryId,
  order: order,
  isActive: isActive,
  pdfUrl: pdfUrl,
);

BookCategory _category(String id, {int? order, bool isActive = true}) =>
    BookCategory(
      id: id,
      name: LocalizedText.single(id),
      order: order,
      isActive: isActive,
    );

void main() {
  group('sortActiveBooks', () {
    test('drops hidden and unreadable books and sorts the rest', () {
      final List<Book> sorted = sortActiveBooks(<Book>[
        _book('b', order: 2),
        _book('hidden', order: 0, isActive: false),
        _book('no-pdf', order: 0, pdfUrl: ''),
        _book('a', order: 1),
        _book('c'),
      ]);
      expect(sorted.map((Book b) => b.id), <String>['a', 'b', 'c']);
      expect(() => sorted.add(_book('x')), throwsUnsupportedError);
    });
  });

  group('categories', () {
    test('sortActiveBookCategories keeps active ones in order', () {
      final List<BookCategory> sorted = sortActiveBookCategories(<BookCategory>[
        _category('z'),
        _category('off', order: 0, isActive: false),
        _category('b', order: 2),
        _category('a', order: 1),
      ]);
      expect(sorted.map((BookCategory c) => c.id), <String>['a', 'b', 'z']);
    });

    test('bookCategoriesInUse hides categories without books', () {
      final List<BookCategory> used = bookCategoriesInUse(
        <BookCategory>[_category('main'), _category('empty'), _category('k')],
        <Book>[
          _book('1', categoryId: 'main'),
          _book('2', categoryId: 'k'),
          _book('3'),
        ],
      );
      expect(used.map((BookCategory c) => c.id), <String>['main', 'k']);
    });
  });

  group('filterBooks', () {
    final List<Book> books = <Book>[
      _book('vach', title: 'Vachanamrut', author: 'Shriji', categoryId: 'm'),
      _book('shiksha', title: 'Shikshapatri', categoryId: 'm'),
      _book('kirtan', title: 'Kirtan Muktavali', categoryId: 'k'),
    ];

    test('returns the same list when nothing filters', () {
      expect(identical(filterBooks(books), books), isTrue);
      expect(identical(filterBooks(books, query: '   '), books), isTrue);
    });

    test('filters by category and query (title or author)', () {
      expect(
        filterBooks(
          books,
          filter: const LibraryFilter.category('m'),
        ).map((Book b) => b.id),
        <String>['vach', 'shiksha'],
      );
      expect(
        filterBooks(books, query: 'shriji').map((Book b) => b.id),
        <String>['vach'],
      );
      expect(
        filterBooks(
          books,
          query: 'kirtan',
          filter: const LibraryFilter.category('m'),
        ),
        isEmpty,
      );
    });

    test('downloaded filter keeps only saved books', () {
      expect(
        filterBooks(
          books,
          filter: LibraryFilter.downloaded,
          downloadedIds: <String>{'kirtan', 'gone'},
        ).map((Book b) => b.id),
        <String>['kirtan'],
      );
      expect(filterBooks(books, filter: LibraryFilter.downloaded), isEmpty);
    });

    test(
      'effectiveLibraryFilter falls back to All for a vanished category',
      () {
        final List<BookCategory> categories = <BookCategory>[_category('m')];
        expect(
          effectiveLibraryFilter(const LibraryFilter.category('m'), categories),
          const LibraryFilter.category('m'),
        );
        expect(
          effectiveLibraryFilter(const LibraryFilter.category('x'), categories),
          LibraryFilter.all,
        );
        expect(
          effectiveLibraryFilter(LibraryFilter.downloaded, categories),
          LibraryFilter.downloaded,
        );
      },
    );
  });

  test('findBook', () {
    final List<Book> books = <Book>[_book('a'), _book('b')];
    expect(findBook(books, 'b')?.id, 'b');
    expect(findBook(books, 'missing'), isNull);
  });

  group('parsePageInput', () {
    test('accepts valid pages in ASCII, Gujarati and Devanagari digits', () {
      expect(parsePageInput('1', 120), 1);
      expect(parsePageInput(' 45 ', 120), 45);
      expect(parsePageInput('120', 120), 120);
      expect(parsePageInput('૪૫', 120), 45);
      expect(parsePageInput('१२०', 120), 120);
    });

    test('rejects out-of-range and non-numeric input', () {
      expect(parsePageInput('', 120), isNull);
      expect(parsePageInput('0', 120), isNull);
      expect(parsePageInput('121', 120), isNull);
      expect(parsePageInput('-3', 120), isNull);
      expect(parsePageInput('4.5', 120), isNull);
      expect(parsePageInput('abc', 120), isNull);
      expect(parsePageInput('99999999999999', 120), isNull);
      expect(parsePageInput('1', 0), isNull);
    });
  });

  group('doubleTapZoomTarget', () {
    test('zooms in from fit width, capped at the maximum', () {
      expect(doubleTapZoomTarget(currentZoom: 1, fitZoom: 1, maxZoom: 8), 2.5);
      expect(doubleTapZoomTarget(currentZoom: 1, fitZoom: 1, maxZoom: 2), 2);
    });

    test('returns to fit width when already zoomed in', () {
      expect(doubleTapZoomTarget(currentZoom: 2.5, fitZoom: 1, maxZoom: 8), 1);
    });

    test('never zooms out below fit and ignores a bad fit value', () {
      expect(
        doubleTapZoomTarget(currentZoom: 0.5, fitZoom: 1, maxZoom: 0.8),
        1,
      );
      expect(
        doubleTapZoomTarget(currentZoom: 1.3, fitZoom: 0, maxZoom: 8),
        1.3,
      );
    });
  });

  test('readingFraction', () {
    expect(readingFraction(50, 200), 0.25);
    expect(readingFraction(300, 200), 1);
    expect(readingFraction(5, null), isNull);
    expect(readingFraction(5, 0), isNull);
  });

  test('downloaded ids signature round-trips and is order independent', () {
    final String a = downloadedIdsSignature(<String>['b', 'a', 'b']);
    final String b = downloadedIdsSignature(<String>['a', 'b']);
    expect(a, b);
    expect(idsFromSignature(a), <String>{'a', 'b'});
    expect(downloadedIdsSignature(const <String>[]), isEmpty);
    expect(idsFromSignature(''), isEmpty);
  });
}
