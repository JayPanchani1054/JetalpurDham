import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/features/library/application/reading_progress_controller.dart';
import 'package:jetalpur_dham/features/library/domain/reading_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LibraryPrefKeys', () {
    test('all keys live under the library namespace', () {
      expect(LibraryPrefKeys.lastBookId, startsWith('library.'));
      expect(LibraryPrefKeys.lastPage('abc'), 'library.lastPage.abc');
      expect(
        LibraryPrefKeys.lastPage('abc'),
        startsWith(PrefKeys.libraryLastPagePrefix),
      );
      expect(LibraryPrefKeys.pageCount('abc'), 'library.pageCount.abc');
    });
  });

  group('ReadingProgress.fromEntries', () {
    test('reads the last book, pages and page counts', () {
      final ReadingProgress progress = ReadingProgress.fromEntries(
        <String, Object?>{
          'library.lastBookId': 'vach',
          'library.lastPage.vach': 42,
          'library.lastPage.shiksha': 3,
          'library.pageCount.vach': 712,
          'library.downloadsIndex': '{}',
          'app.language': 'gu',
        },
      );
      expect(progress.lastBookId, 'vach');
      expect(progress.pageFor('vach'), 42);
      expect(progress.pageFor('shiksha'), 3);
      expect(progress.pageFor('other'), isNull);
      expect(progress.pageCountFor('vach'), 712);
      expect(progress.pageCountFor('shiksha'), isNull);
      expect(progress.canResume('vach'), isTrue);
      expect(progress.canResume('other'), isFalse);
    });

    test('ignores malformed values', () {
      final ReadingProgress progress = ReadingProgress.fromEntries(
        <String, Object?>{
          'library.lastBookId': '   ',
          'library.lastPage.': 4,
          'library.lastPage.a': 0,
          'library.lastPage.b': 'nope',
          'library.lastPage.c': '7',
          'library.pageCount.a': -1,
        },
      );
      expect(progress.lastBookId, isNull);
      expect(progress.pages, <String, int>{'c': 7});
      expect(progress.pageCounts, isEmpty);
    });

    test('withPage and withLastBook return updated copies', () {
      const ReadingProgress empty = ReadingProgress();
      final ReadingProgress next = empty
          .withLastBook('a')
          .withPage('a', 5, pageCount: 100)
          .withPage('a', 6);
      expect(next.lastBookId, 'a');
      expect(next.pageFor('a'), 6);
      expect(next.pageCountFor('a'), 100);
      expect(empty.pageFor('a'), isNull);
      expect(
        next,
        const ReadingProgress(
          lastBookId: 'a',
          pages: <String, int>{'a': 6},
          pageCounts: <String, int>{'a': 100},
        ),
      );
    });
  });

  group('ReadingProgressController', () {
    late SharedPreferences prefs;

    Future<ProviderContainer> container(Map<String, Object> initial) async {
      SharedPreferences.setMockInitialValues(initial);
      prefs = await SharedPreferences.getInstance();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('loads saved progress on start', () async {
      final ProviderContainer c = await container(<String, Object>{
        'library.lastBookId': 'vach',
        'library.lastPage.vach': 12,
        'library.pageCount.vach': 300,
      });
      final ReadingProgress progress = c.read(readingProgressProvider);
      expect(progress.lastBookId, 'vach');
      expect(progress.pageFor('vach'), 12);
      expect(progress.pageCountFor('vach'), 300);
    });

    test('markOpened and savePage update state and persist', () async {
      final ProviderContainer c = await container(<String, Object>{});
      final ReadingProgressController controller = c.read(
        readingProgressProvider.notifier,
      );

      await controller.markOpened('shiksha');
      await controller.savePage('shiksha', 9, pageCount: 40);

      expect(c.read(readingProgressProvider).lastBookId, 'shiksha');
      expect(c.read(readingProgressProvider).pageFor('shiksha'), 9);
      expect(prefs.getString('library.lastBookId'), 'shiksha');
      expect(prefs.getInt('library.lastPage.shiksha'), 9);
      expect(prefs.getInt('library.pageCount.shiksha'), 40);

      // A fresh container (app restart) sees the same progress.
      final ProviderContainer restarted = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(restarted.dispose);
      expect(restarted.read(readingProgressProvider).pageFor('shiksha'), 9);
    });

    test('ignores invalid pages and unchanged values', () async {
      final ProviderContainer c = await container(<String, Object>{
        'library.lastPage.a': 3,
      });
      final ReadingProgressController controller = c.read(
        readingProgressProvider.notifier,
      );
      final ReadingProgress before = c.read(readingProgressProvider);

      await controller.savePage('a', 0);
      await controller.savePage('', 5);
      await controller.savePage('a', 3);
      expect(identical(c.read(readingProgressProvider), before), isTrue);
      expect(prefs.getInt('library.lastPage.a'), 3);
    });
  });
}
