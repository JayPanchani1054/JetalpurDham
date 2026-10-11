import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/models/localized_text.dart';
import 'package:jetalpur_dham/features/library/domain/book.dart';

void main() {
  group('Book.fromMap', () {
    test('parses a complete document', () {
      final DateTime created = DateTime(2026, 4, 1, 10);
      final Book book = Book.fromMap('vachanamrut', <String, Object?>{
        'title': <String, Object?>{
          'en': 'Shree Vachanamrut',
          'gu': 'શ્રી વચનામૃત',
        },
        'author': 'Bhagwan Shree Swaminarayan',
        'description': <String, Object?>{'en': 'The principal scripture.'},
        'categoryId': 'main',
        'language': 'gu',
        'pdfUrl': 'books/main/vachanamrut.pdf',
        'coverUrl': 'books/main/vachanamrut.jpg',
        'pageCount': 712,
        'sizeBytes': 25000000,
        'order': 1,
        'isActive': true,
        'isFeatured': true,
        'createdAt': Timestamp.fromDate(created),
      });

      expect(book.id, 'vachanamrut');
      expect(book.title.resolve('gu'), 'શ્રી વચનામૃત');
      expect(book.title.resolve('hi'), 'Shree Vachanamrut');
      expect(book.author.resolve('gu'), 'Bhagwan Shree Swaminarayan');
      expect(book.description.resolve('en'), 'The principal scripture.');
      expect(book.categoryId, 'main');
      expect(book.languageCode, BookLanguages.gujarati);
      expect(book.pdfUrl, 'books/main/vachanamrut.pdf');
      expect(book.coverUrl, 'books/main/vachanamrut.jpg');
      expect(book.hasCover, isTrue);
      expect(book.pageCount, 712);
      expect(book.sizeBytes, 25000000);
      expect(book.order, 1);
      expect(book.isActive, isTrue);
      expect(book.isFeatured, isTrue);
      expect(book.createdAt, created);
      expect(book.isReadable, isTrue);
    });

    test('tolerates an empty document', () {
      final Book book = Book.fromMap('empty', const <String, Object?>{});
      expect(book.title.resolve('en'), 'empty');
      expect(book.author.isEmpty, isTrue);
      expect(book.description.isEmpty, isTrue);
      expect(book.pdfUrl, isEmpty);
      expect(book.isReadable, isFalse);
      expect(book.coverUrl, isNull);
      expect(book.hasCover, isFalse);
      expect(book.languageCode, isNull);
      expect(book.pageCount, isNull);
      expect(book.isActive, isTrue, reason: 'missing isActive means active');
      expect(book.isFeatured, isFalse);
    });

    test('tolerates wrongly typed fields', () {
      final Book book = Book.fromMap('odd', <String, Object?>{
        'title': 42,
        'author': <Object?>['not', 'text'],
        'pdfUrl': 'https://example.org/a.pdf',
        'coverUrl': '   ',
        'pageCount': '350',
        'sizeBytes': -5,
        'order': '2',
        'isActive': 'false',
        'isFeatured': 'yes',
        'language': 7,
        'createdAt': 'not a date',
      });
      expect(book.title.resolve('en'), 'a', reason: 'falls back to file name');
      expect(book.author.isEmpty, isTrue);
      expect(book.coverUrl, isNull);
      expect(book.pageCount, 350);
      expect(book.sizeBytes, isNull, reason: 'non-positive sizes are ignored');
      expect(book.order, 2);
      expect(book.isActive, isFalse);
      expect(book.isFeatured, isTrue);
      expect(book.languageCode, isNull);
      expect(book.createdAt, isNull);
    });

    test('derives a title from the PDF file name when missing', () {
      final Book fromPath = Book.fromMap('x', <String, Object?>{
        'pdfUrl': 'books/main/Shree_Shikshapatri-Bhashya.pdf',
      });
      expect(fromPath.title.resolve('en'), 'Shree Shikshapatri Bhashya');

      final Book fromDownloadUrl = Book.fromMap('y', <String, Object?>{
        'pdfUrl': 'https://firebasestorage.googleapis.com/v0/b/app/o/books%2Fmain%2FHarililamrut_Part_1.pdf?alt=media&token=abc',
      });
      expect(fromDownloadUrl.title.resolve('en'), 'Harililamrut Part 1');
    });
  });

  group('normalizeBookLanguage', () {
    test('accepts codes, names and native scripts', () {
      expect(normalizeBookLanguage('gu'), 'gu');
      expect(normalizeBookLanguage('GU'), 'gu');
      expect(normalizeBookLanguage(' Gujarati '), 'gu');
      expect(normalizeBookLanguage('ગુજરાતી'), 'gu');
      expect(normalizeBookLanguage('gu-IN'), 'gu');
      expect(normalizeBookLanguage('Hindi'), 'hi');
      expect(normalizeBookLanguage('हिंदी'), 'hi');
      expect(normalizeBookLanguage('hi_IN'), 'hi');
      expect(normalizeBookLanguage('English'), 'en');
      expect(normalizeBookLanguage('sa'), 'sa');
      expect(normalizeBookLanguage('Sanskrit'), 'sa');
      expect(normalizeBookLanguage('संस्कृत'), 'sa');
    });

    test('returns null for unknown or missing values', () {
      expect(normalizeBookLanguage(null), isNull);
      expect(normalizeBookLanguage(''), isNull);
      expect(normalizeBookLanguage('fr'), isNull);
      expect(normalizeBookLanguage(<String>['gu']), isNull);
    });
  });

  group('Book search and sort', () {
    final Book gujarati = Book(
      id: 'a',
      title: const LocalizedText(<String, String>{
        'en': 'Shikshapatri',
        'gu': 'શિક્ષાપત્રી',
      }),
      author: LocalizedText.single('Shree Swaminarayan'),
      pdfUrl: 'a.pdf',
    );

    test('matches title and author in any language', () {
      expect(gujarati.matches(''), isTrue);
      expect(gujarati.matches('shiksha'), isTrue);
      expect(gujarati.matches('શિક્ષા'), isTrue);
      expect(gujarati.matches('swaminarayan'), isTrue);
      expect(gujarati.matches('vachanamrut'), isFalse);
    });

    test('compare sorts by order, then title, then id', () {
      Book b(String id, String title, [int? order]) => Book(
        id: id,
        title: LocalizedText.single(title),
        pdfUrl: '$id.pdf',
        order: order,
      );
      final List<Book> books = <Book>[
        b('z', 'Zeta'),
        b('c', 'Alpha'),
        b('b', 'Beta', 2),
        b('a', 'Gamma', 1),
        b('d', 'alpha'),
      ]..sort(Book.compare);
      expect(books.map((Book x) => x.id), <String>['a', 'b', 'c', 'd', 'z']);
    });
  });

  group('BookCategory.fromMap', () {
    test('parses and falls back to the id for a missing name', () {
      final BookCategory named = BookCategory.fromMap('main', <String, Object?>{
        'name': <String, Object?>{
          'en': 'Main Shastras',
          'gu': 'મુખ્ય શાસ્ત્રો',
        },
        'order': 1.0,
        'isActive': false,
      });
      expect(named.name.resolve('gu'), 'મુખ્ય શાસ્ત્રો');
      expect(named.order, 1);
      expect(named.isActive, isFalse);

      final BookCategory unnamed = BookCategory.fromMap(
        'kirtan-books',
        const <String, Object?>{},
      );
      expect(unnamed.name.resolve('en'), 'kirtan-books');
      expect(unnamed.isActive, isTrue);
      expect(unnamed.order, isNull);
    });
  });
}
