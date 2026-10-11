import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/models/localized_text.dart';

/// A shastra category (`book_categories/{id}`), e.g. Vachanamrut, Shikshapatri.
@immutable
class BookCategory {
  const BookCategory({
    required this.id,
    required this.name,
    this.order,
    this.isActive = true,
  });

  /// Parses a Firestore document. Never throws.
  factory BookCategory.fromMap(String id, Map<String, Object?> map) {
    final LocalizedText name = LocalizedText.fromValue(map['name']);
    return BookCategory(
      id: id,
      name: name.isEmpty ? LocalizedText.single(id) : name,
      order: Fs.integerOrNull(map['order']),
      isActive: Fs.boolean(map['isActive'], fallback: true),
    );
  }

  final String id;
  final LocalizedText name;
  final int? order;
  final bool isActive;

  /// Sort: ascending `order` (missing last), then English name, then id.
  static int compare(BookCategory a, BookCategory b) {
    final int byOrder = compareByOrder(a.order, b.order);
    if (byOrder != 0) return byOrder;
    final int byName = a.name
        .resolve('en')
        .toLowerCase()
        .compareTo(b.name.resolve('en').toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  @override
  bool operator ==(Object other) =>
      other is BookCategory &&
      other.id == id &&
      other.name == name &&
      other.order == order &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(id, name, order, isActive);
}

/// One scripture (`books/{id}`). See docs/DATA_MODEL.md.
@immutable
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.pdfUrl,
    this.author = const LocalizedText.empty(),
    this.description = const LocalizedText.empty(),
    this.categoryId,
    this.languageCode,
    this.coverUrl,
    this.pageCount,
    this.sizeBytes,
    this.order,
    this.isActive = true,
    this.isFeatured = false,
    this.createdAt,
  });

  /// Parses a Firestore document. Tolerates missing and wrongly typed fields,
  /// so content hand-edited in the console can never crash the library.
  factory Book.fromMap(String id, Map<String, Object?> map) {
    final String pdfUrl = Fs.string(map['pdfUrl']);
    final LocalizedText title = LocalizedText.fromValue(map['title']);
    final String fallbackTitle = bookTitleFromPdfRef(pdfUrl);
    return Book(
      id: id,
      title: title.isNotEmpty
          ? title
          : LocalizedText.single(fallbackTitle.isEmpty ? id : fallbackTitle),
      pdfUrl: pdfUrl,
      author: LocalizedText.fromValue(map['author']),
      description: LocalizedText.fromValue(map['description']),
      categoryId: Fs.stringOrNull(map['categoryId']),
      languageCode: normalizeBookLanguage(map['language']),
      coverUrl: Fs.stringOrNull(map['coverUrl']),
      pageCount: _positiveOrNull(Fs.integerOrNull(map['pageCount'])),
      sizeBytes: _positiveOrNull(Fs.integerOrNull(map['sizeBytes'])),
      order: Fs.integerOrNull(map['order']),
      isActive: Fs.boolean(map['isActive'], fallback: true),
      isFeatured: Fs.boolean(map['isFeatured'], fallback: false),
      createdAt: Fs.dateTime(map['createdAt']),
    );
  }

  final String id;
  final LocalizedText title;
  final LocalizedText author;
  final LocalizedText description;
  final String? categoryId;

  /// Language of the PDF itself: `gu`, `hi`, `en` or `sa` (null if unknown).
  final String? languageCode;

  /// Media reference: https URL, `gs://` URL or a Storage path.
  final String pdfUrl;
  final String? coverUrl;
  final int? pageCount;
  final int? sizeBytes;
  final int? order;
  final bool isActive;
  final bool isFeatured;
  final DateTime? createdAt;

  /// True when there is a PDF to open.
  bool get isReadable => pdfUrl.isNotEmpty;

  bool get hasCover => coverUrl != null && coverUrl!.isNotEmpty;

  /// True if the title or author contains [query] in any language, so a
  /// devotee finds a scripture whichever script they type in.
  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    return title.matches(query) || author.matches(query);
  }

  /// Sort: ascending `order` (missing last), then English title, then id.
  static int compare(Book a, Book b) {
    final int byOrder = compareByOrder(a.order, b.order);
    if (byOrder != 0) return byOrder;
    final int byTitle = a.title
        .resolve('en')
        .toLowerCase()
        .compareTo(b.title.resolve('en').toLowerCase());
    return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
  }

  @override
  bool operator ==(Object other) =>
      other is Book &&
      other.id == id &&
      other.title == title &&
      other.author == author &&
      other.description == description &&
      other.categoryId == categoryId &&
      other.languageCode == languageCode &&
      other.pdfUrl == pdfUrl &&
      other.coverUrl == coverUrl &&
      other.pageCount == pageCount &&
      other.sizeBytes == sizeBytes &&
      other.order == order &&
      other.isActive == isActive &&
      other.isFeatured == isFeatured &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    description,
    categoryId,
    languageCode,
    pdfUrl,
    coverUrl,
    pageCount,
    sizeBytes,
    order,
    isActive,
    isFeatured,
    createdAt,
  );

  @override
  String toString() => 'Book($id, ${title.resolve('en')})';
}

int? _positiveOrNull(int? value) => value != null && value > 0 ? value : null;

/// Book language codes understood by the app.
abstract final class BookLanguages {
  static const String gujarati = 'gu';
  static const String hindi = 'hi';
  static const String english = 'en';
  static const String sanskrit = 'sa';
}

const Map<String, String> _languageAliases = <String, String>{
  'gu': BookLanguages.gujarati,
  'guj': BookLanguages.gujarati,
  'gujarati': BookLanguages.gujarati,
  'gujrati': BookLanguages.gujarati,
  'ગુજરાતી': BookLanguages.gujarati,
  'hi': BookLanguages.hindi,
  'hin': BookLanguages.hindi,
  'hindi': BookLanguages.hindi,
  'हिन्दी': BookLanguages.hindi,
  'हिंदी': BookLanguages.hindi,
  'en': BookLanguages.english,
  'eng': BookLanguages.english,
  'english': BookLanguages.english,
  'sa': BookLanguages.sanskrit,
  'san': BookLanguages.sanskrit,
  'sanskrit': BookLanguages.sanskrit,
  'संस्कृत': BookLanguages.sanskrit,
  'સંસ્કૃત': BookLanguages.sanskrit,
};

/// Normalises the `language` field typed in the console (`gu`, `Gujarati`,
/// `GU`, `ગુજરાતી`, `gu-IN`…) to one of [BookLanguages], or null.
String? normalizeBookLanguage(Object? value) {
  final String raw = Fs.string(value).toLowerCase();
  if (raw.isEmpty) return null;
  final String? direct = _languageAliases[raw];
  if (direct != null) return direct;
  // Locale-style codes such as `gu-IN` or `hi_IN`.
  final String base = raw.split(RegExp(r'[-_\s]')).first;
  return _languageAliases[base];
}

/// Human title derived from a PDF file name, used when an auto-created
/// document has no title yet: `books/vachanamrut/Shree_Vachanamrut.pdf` →
/// `Shree Vachanamrut`.
String bookTitleFromPdfRef(String pdfRef) {
  String name = _lastPathSegment(pdfRef);
  final int dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  return name
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Last path segment of an https/gs URL or a Storage path, percent-decoded
/// (Firebase download URLs encode the object path as `books%2Fa%2Fb.pdf`).
String _lastPathSegment(String ref) {
  String path = ref.trim();
  if (path.isEmpty) return '';
  final Uri? uri = Uri.tryParse(path);
  if (uri != null && uri.hasScheme) path = uri.path;
  try {
    path = Uri.decodeComponent(path);
  } catch (_) {
    // Malformed escapes: keep the raw text.
  }
  final int slash = path.lastIndexOf('/');
  return slash >= 0 ? path.substring(slash + 1) : path;
}
