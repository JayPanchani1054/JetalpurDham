import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/reading_progress.dart';

/// The last book opened and the page reached in each book, persisted in
/// SharedPreferences so "Continue reading" survives app restarts and works
/// fully offline.
final NotifierProvider<ReadingProgressController, ReadingProgress>
readingProgressProvider =
    NotifierProvider<ReadingProgressController, ReadingProgress>(
      ReadingProgressController.new,
    );

class ReadingProgressController extends Notifier<ReadingProgress> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ReadingProgress build() {
    final SharedPreferences prefs = _prefs;
    final Map<String, Object?> entries = <String, Object?>{};
    for (final String key in prefs.getKeys()) {
      if (key.startsWith('library.')) entries[key] = prefs.get(key);
    }
    return ReadingProgress.fromEntries(entries);
  }

  /// Remembers [bookId] as the book to continue reading.
  Future<void> markOpened(String bookId) async {
    if (!ref.mounted || bookId.isEmpty) return;
    if (state.lastBookId != bookId) state = state.withLastBook(bookId);
    await _write(
      () => _prefs.setString(LibraryPrefKeys.lastBookId, bookId),
      'last book',
    );
  }

  /// Saves the page reached in [bookId] (and its page count when known).
  /// Cheap to call often: unchanged values are not written again.
  Future<void> savePage(String bookId, int page, {int? pageCount}) async {
    if (!ref.mounted || bookId.isEmpty || page < 1) return;
    final ReadingProgress current = state;
    final bool pageChanged = current.pageFor(bookId) != page;
    final bool countChanged =
        pageCount != null &&
        pageCount > 0 &&
        current.pageCountFor(bookId) != pageCount;
    if (!pageChanged && !countChanged) return;
    state = current.withPage(
      bookId,
      page,
      pageCount: countChanged ? pageCount : null,
    );
    final SharedPreferences prefs = _prefs;
    if (pageChanged) {
      await _write(
        () => prefs.setInt(LibraryPrefKeys.lastPage(bookId), page),
        'page',
      );
    }
    if (countChanged) {
      await _write(
        () => prefs.setInt(LibraryPrefKeys.pageCount(bookId), pageCount),
        'page count',
      );
    }
  }

  Future<void> _write(Future<bool> Function() write, String what) async {
    try {
      await write();
    } catch (error, stack) {
      // Losing a bookmark must never interrupt reading.
      AppLogger.error('Could not save library $what', error, stack);
    }
  }
}
