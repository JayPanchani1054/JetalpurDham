import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jetalpur_dham/core/firebase/media_url.dart';
import 'package:jetalpur_dham/core/l10n/app_language.dart';
import 'package:jetalpur_dham/core/l10n/l10n.dart';
import 'package:jetalpur_dham/core/router/routes.dart';
import 'package:jetalpur_dham/core/services/connectivity_service.dart';
import 'package:jetalpur_dham/core/services/download_service.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/theme/app_theme.dart';
import 'package:jetalpur_dham/features/library/data/library_repository.dart';
import 'package:jetalpur_dham/features/library/domain/book.dart';
import 'package:jetalpur_dham/features/library/presentation/book_detail_screen.dart';
import 'package:jetalpur_dham/features/library/presentation/library_screen.dart';
import 'package:jetalpur_dham/features/library/presentation/pdf_reader_screen.dart';
import 'package:jetalpur_dham/features/library/presentation/widgets/book_cover.dart';
import 'package:jetalpur_dham/features/library/presentation/widgets/book_grid.dart';
import 'package:jetalpur_dham/features/library/presentation/widgets/continue_reading_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the Shastra screens with fake data (no Firebase, no network, no
/// PDF engine) to catch build errors and layout overflows, including
/// Gujarati content, the largest text size and dark mode.

final List<Book> _books = <Book>[
  Book.fromMap('vachanamrut', <String, Object?>{
    'title': <String, Object?>{
      'en': 'Shree Vachanamrut',
      'gu': 'શ્રી વચનામૃત',
      'hi': 'श्री वचनामृत',
    },
    'author': <String, Object?>{
      'en': 'Bhagwan Shree Swaminarayan',
      'gu': 'ભગવાન શ્રી સ્વામિનારાયણ',
    },
    'description': List<String>.filled(
      30,
      'The words of Shree Swaminarayan Bhagwan, compiled by four senior sadhus.',
    ).join(' '),
    'categoryId': 'main',
    'language': 'gu',
    'pdfUrl': 'books/main/vachanamrut.pdf',
    'coverUrl': 'books/main/vachanamrut.jpg',
    'pageCount': 712,
    'sizeBytes': 25 * 1024 * 1024,
    'order': 1,
  }),
  Book.fromMap('shikshapatri', <String, Object?>{
    'title': <String, Object?>{
      'en': 'Shikshapatri with a very long commentary title that wraps',
      'gu': 'શિક્ષાપત્રી ભાષ્ય સહિત – અત્યંત લાંબુ શીર્ષક',
    },
    'categoryId': 'main',
    'language': 'sa',
    'pdfUrl': 'books/main/shikshapatri.pdf',
    'order': 2,
  }),
  Book.fromMap('kirtan-muktavali', <String, Object?>{
    'title': 'Kirtan Muktavali',
    'author': 'Premanand Swami',
    'categoryId': 'kirtan',
    'pdfUrl': 'books/kirtan/muktavali.pdf',
    'order': 3,
  }),
];

final List<BookCategory> _categories = <BookCategory>[
  BookCategory.fromMap('main', <String, Object?>{
    'name': <String, Object?>{'en': 'Main Shastras', 'gu': 'મુખ્ય શાસ્ત્રો'},
    'order': 1,
  }),
  BookCategory.fromMap('kirtan', <String, Object?>{
    'name': <String, Object?>{'en': 'Kirtan Books', 'gu': 'કીર્તન ગ્રંથો'},
    'order': 2,
  }),
  BookCategory.fromMap('unused', <String, Object?>{'name': 'Unused'}),
];

/// Resolver that is always "offline", so Storage paths fail gracefully.
class _OfflineResolver implements MediaUrlResolver {
  @override
  Future<String> resolve(String raw) =>
      Future<String>.error(StateError('offline in tests'));
}

/// Keeps offline files in a temp folder instead of the app documents dir.
class _TempDownloadService extends DownloadService {
  _TempDownloadService(this.root);

  final Directory root;

  @override
  Future<Directory> directory(String folder) async {
    final Directory dir = Directory(p.join(root.path, folder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}

const List<LocalizationsDelegate<dynamic>> _delegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Map<String, Object> prefsValues = const <String, Object>{},
  Set<String> downloadedIds = const <String>{},
  List<Book>? books,
  bool online = true,
  Size size = const Size(390, 844),
  double textScale = 1,
  AppLanguage language = AppLanguage.en,
  ThemeMode themeMode = ThemeMode.light,
  GoRouter? router,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    PrefKeys.language: language.code,
    ...prefsValues,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final Directory root = Directory.systemTemp.createTempSync('library_test');
  addTearDown(() => root.deleteSync(recursive: true));
  final Directory booksDir = Directory(p.join(root.path, DownloadFolders.books))
    ..createSync(recursive: true);
  for (final String id in downloadedIds) {
    File(p.join(booksDir.path, '$id.pdf')).writeAsStringSync('%PDF-1.4');
  }

  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOnlineProvider.overrideWith((Ref ref) => Stream<bool>.value(online)),
        booksProvider.overrideWith(
          (Ref ref) => Stream<List<Book>>.value(books ?? _books),
        ),
        bookCategoriesProvider.overrideWith(
          (Ref ref) => Stream<List<BookCategory>>.value(_categories),
        ),
        mediaUrlResolverProvider.overrideWithValue(_OfflineResolver()),
        downloadServiceProvider.overrideWithValue(_TempDownloadService(root)),
      ],
      child: router == null
          ? MaterialApp(
              theme: AppTheme.light(language),
              darkTheme: AppTheme.dark(language),
              themeMode: themeMode,
              locale: language.locale,
              supportedLocales: AppLanguage.supportedLocales,
              localizationsDelegates: _delegates,
              builder: (BuildContext context, Widget? child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child ?? const SizedBox.shrink(),
              ),
              home: child,
            )
          : MaterialApp.router(
              theme: AppTheme.light(language),
              locale: language.locale,
              supportedLocales: AppLanguage.supportedLocales,
              localizationsDelegates: _delegates,
              routerConfig: router,
            ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Library shows chips, continue card and the book grid', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const LibraryScreen(),
      prefsValues: <String, Object>{
        'library.lastBookId': 'vachanamrut',
        'library.lastPage.vachanamrut': 120,
      },
    );

    expect(find.text('Shastra Library'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Main Shastras'), findsOneWidget);
    expect(find.text('Kirtan Books', skipOffstage: false), findsOneWidget);
    expect(find.text('Unused'), findsNothing, reason: 'category without books');

    expect(find.byType(ContinueReadingCard), findsOneWidget);
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Page 120 of 712'), findsOneWidget);

    expect(find.byType(BookGridCard), findsNWidgets(3));
    // Two books have no cover image and Vachanamrut's cover cannot be
    // resolved offline: all three grid covers (plus the continue-reading
    // card's) show the generated cover, never a blank or generic icon.
    expect(find.byType(GeneratedBookCover), findsNWidgets(4));
    expect(find.text('Premanand Swami'), findsOneWidget);
    expect(find.text('Sanskrit'), findsOneWidget, reason: 'no author');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search filters the grid and shows a friendly empty state', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const LibraryScreen());

    await tester.enterText(find.byType(EditableText), 'muktavali');
    await tester.pump(const Duration(milliseconds: 300));
    await _settle(tester);
    expect(find.byType(BookGridCard), findsOneWidget);
    expect(find.text('Kirtan Muktavali'), findsWidgets);

    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await _settle(tester);
    expect(find.byType(BookGridCard), findsNothing);
    expect(find.text('No scripture found'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await _settle(tester);
    expect(find.byType(BookGridCard), findsNWidgets(3));
  });

  testWidgets('Downloaded books get a badge and their own filter', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const LibraryScreen(),
      downloadedIds: <String>{'kirtan-muktavali'},
    );
    // The file check runs asynchronously on real IO.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(find.byType(DownloadedBadge), findsOneWidget);

    await tester.tap(find.text('Downloaded'));
    await _settle(tester);
    expect(find.byType(BookGridCard), findsOneWidget);
    // Title on the generated cover and below it.
    expect(find.text('Kirtan Muktavali'), findsWidgets);
    expect(find.text('Premanand Swami'), findsOneWidget);
  });

  testWidgets('Empty downloaded filter explains how to save books', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const LibraryScreen());
    await tester.tap(find.text('Downloaded'));
    await _settle(tester);
    expect(find.byType(BookGridCard), findsNothing);
    expect(
      find.text(
        'Books you download will appear here, ready to read without internet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Empty library shows the coming-soon message', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const LibraryScreen(), books: const <Book>[]);
    expect(find.text('Scriptures will be added soon.'), findsOneWidget);
  });

  testWidgets('Gujarati, large text, dark mode and a narrow phone', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const LibraryScreen(),
      language: AppLanguage.gu,
      textScale: 1.4,
      themeMode: ThemeMode.dark,
      size: const Size(320, 640),
      prefsValues: <String, Object>{
        'library.lastBookId': 'shikshapatri',
        'library.lastPage.shikshapatri': 3,
      },
    );
    expect(find.text('શ્રી વચનામૃત'), findsWidgets);
    expect(find.byType(ContinueReadingCard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Book page shows details, resume and download actions', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const BookDetailScreen(bookId: 'vachanamrut'),
      prefsValues: <String, Object>{'library.lastPage.vachanamrut': 12},
    );
    // Heading plus the generated cover shown because the cover image
    // cannot be resolved offline.
    expect(find.text('Shree Vachanamrut'), findsNWidgets(2));
    expect(find.byType(GeneratedBookCover), findsOneWidget);
    expect(find.text('Bhagwan Shree Swaminarayan'), findsOneWidget);
    expect(find.text('Gujarati'), findsOneWidget);
    expect(find.text('712 pages'), findsOneWidget);
    expect(find.text('25 MB'), findsOneWidget);
    expect(find.text('Continue reading · Page 12'), findsOneWidget);
    expect(find.text('Download for offline · 25 MB'), findsOneWidget);
    expect(find.text('About this scripture'), findsOneWidget);
    expect(find.text('Read more'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Book page in Hindi with large text fits on a narrow phone', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const BookDetailScreen(bookId: 'shikshapatri'),
      language: AppLanguage.hi,
      textScale: 1.4,
      themeMode: ThemeMode.dark,
      size: const Size(320, 640),
    );
    expect(find.text('पढ़ें', skipOffstage: false), findsOneWidget);
    expect(find.byType(GeneratedBookCover), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Downloaded book offers removal instead of download', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const BookDetailScreen(bookId: 'kirtan-muktavali'),
      downloadedIds: <String>{'kirtan-muktavali'},
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(find.text('Available offline'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('Unknown book shows the not-found state', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const BookDetailScreen(bookId: 'missing'));
    expect(find.text('This book is no longer available.'), findsOneWidget);
  });

  testWidgets('Reader explains when a book no longer exists', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PdfReaderScreen(bookId: 'missing'),
      prefsValues: <String, Object>{'library.lastBookId': 'vachanamrut'},
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(find.text('This book is no longer available.'), findsOneWidget);
    expect(find.text('Shastra Library'), findsWidgets);
    expect(tester.takeException(), isNull);
    // A book that never opened must not replace "Continue reading".
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('library.lastBookId'), 'vachanamrut');
  });

  testWidgets('Reader asks for internet when offline and not downloaded', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PdfReaderScreen(bookId: 'vachanamrut'),
      books: const <Book>[],
      online: false,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(
      find.text(
        "This book isn't downloaded yet. Please connect to the internet to "
        'read it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reader opened from a notification goes back to the book page', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: Routes.reader('vachanamrut'),
      routes: <RouteBase>[
        GoRoute(
          path: '/reader/:bookId',
          builder: (_, GoRouterState state) =>
              PdfReaderScreen(bookId: state.pathParameters['bookId']!),
        ),
        GoRoute(
          path: '/library/:bookId',
          builder: (_, GoRouterState state) =>
              Text('book:${state.pathParameters['bookId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pump(tester, const SizedBox.shrink(), router: router);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);

    // Nothing underneath on the navigator: a back arrow is still offered.
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    expect(find.text('book:vachanamrut'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('System back in a deep-linked reader opens the book page', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: Routes.reader('vachanamrut'),
      routes: <RouteBase>[
        GoRoute(
          path: '/reader/:bookId',
          builder: (_, GoRouterState state) =>
              PdfReaderScreen(bookId: state.pathParameters['bookId']!),
        ),
        GoRoute(
          path: '/library/:bookId',
          builder: (_, GoRouterState state) =>
              Text('book:${state.pathParameters['bookId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pump(tester, const SizedBox.shrink(), router: router);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);

    // Android back must not close the app from here.
    final bool handled = await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(handled, isTrue);
    expect(find.text('book:vachanamrut'), findsOneWidget);
  });

  testWidgets('Reader pushed from the book page simply pops back', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PdfReaderScreen(bookId: 'missing'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(find.byType(PdfReaderScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    expect(find.byType(PdfReaderScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
