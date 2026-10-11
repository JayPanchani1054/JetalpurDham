import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/services/download_service.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/book.dart';
import '../domain/library_queries.dart';

/// Live, offline-cached shastra categories (active only, sorted on device).
final StreamProvider<List<BookCategory>> bookCategoriesProvider =
    StreamProvider<List<BookCategory>>((Ref ref) {
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.bookCategories)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                sortActiveBookCategories(
                  _parse(snapshot, BookCategory.fromMap, 'book category'),
                ),
          );
    });

/// Live, offline-cached books: active and readable, sorted by `order` then
/// title. No server-side ordering/filtering, so a missing field can never make
/// a book vanish and no composite index is required.
final StreamProvider<List<Book>> booksProvider = StreamProvider<List<Book>>((
  Ref ref,
) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.books)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snapshot) =>
            sortActiveBooks(_parse(snapshot, Book.fromMap, 'book')),
      );
});

/// One book by id, derived from [booksProvider] (the collection is small and
/// already cached, and this keeps detail, reader and list in sync).
/// `data(null)` means the book does not exist or is hidden.
final ProviderFamily<AsyncValue<Book?>, String> bookProvider =
    Provider.family<AsyncValue<Book?>, String>(
      (Ref ref, String id) => ref
          .watch(booksProvider)
          .whenData((List<Book> books) => findBook(books, id)),
    );

/// The offline file of a book: `books/<id>.pdf` in the app documents folder.
DownloadKey bookDownloadKey(String bookId) =>
    DownloadKey(folder: DownloadFolders.books, id: bookId, extension: '.pdf');

/// Syncs the "downloaded" state of [bookIds] with the files on disk (for
/// example after "Remove all" in Settings). Never throws: a storage hiccup
/// must not surface as an unhandled error.
Future<void> syncBookDownloads(
  DownloadManager manager,
  Iterable<String> bookIds,
) async {
  try {
    await manager.refresh(bookIds.map(bookDownloadKey).toList());
  } catch (error, stack) {
    AppLogger.error('Could not check downloaded books', error, stack);
  }
}

/// Ids of the books whose PDF is saved on this device. Rebuilds only when the
/// set changes (not on every progress tick of a running download).
final Provider<Set<String>> downloadedBookIdsProvider = Provider<Set<String>>((
  Ref ref,
) {
  final String signature = ref.watch(
    downloadManagerProvider.select(
      (Map<DownloadKey, DownloadState> states) =>
          downloadedIdsSignature(<String>[
            for (final MapEntry<DownloadKey, DownloadState> e in states.entries)
              if (e.key.folder == DownloadFolders.books && e.value.isDownloaded)
                e.key.id,
          ]),
    ),
  );
  return idsFromSignature(signature);
});

List<T> _parse<T>(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  T Function(String id, Map<String, Object?> data) parse,
  String label,
) {
  final List<T> items = <T>[];
  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
    try {
      items.add(parse(doc.id, doc.data()));
    } catch (error, stack) {
      // One malformed document must never hide the rest of the library.
      AppLogger.error('Skipping malformed $label ${doc.id}', error, stack);
    }
  }
  return items;
}
