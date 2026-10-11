import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jetalpur_dham/core/config/app_config.dart';
import 'package:jetalpur_dham/core/firebase/media_url.dart';
import 'package:jetalpur_dham/core/l10n/app_language.dart';
import 'package:jetalpur_dham/core/l10n/l10n.dart';
import 'package:jetalpur_dham/core/services/connectivity_service.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/theme/app_theme.dart';
import 'package:jetalpur_dham/features/gallery/application/photo_saver.dart';
import 'package:jetalpur_dham/features/gallery/data/gallery_repository.dart';
import 'package:jetalpur_dham/features/gallery/domain/gallery_models.dart';
import 'package:jetalpur_dham/features/gallery/presentation/album_screen.dart';
import 'package:jetalpur_dham/features/gallery/presentation/gallery_screen.dart';
import 'package:jetalpur_dham/features/gallery/presentation/photo_viewer_screen.dart';
import 'package:jetalpur_dham/features/gallery/presentation/widgets/home_gallery_preview.dart';
import 'package:jetalpur_dham/features/gallery/presentation/widgets/photo_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the gallery screens with fake Firestore data and no network:
/// images are Storage paths whose URLs never resolve, so placeholders are
/// shown. Catches build errors and overflows (incl. Gujarati, large text,
/// dark mode) and exercises selection + saving with a fake saver.

final Album _avsar = Album.fromMap('avsar-200', <String, Object?>{
  'title': <String, Object?>{
    'en': 'Avsar 200 – Bicentenary Mahotsav of Shree Jetalpur Dham',
    'gu': 'અવસર ૨૦૦ – શ્રી જેતલપુર ધામનો દ્વિશતાબ્દી મહોત્સવ',
  },
  'description': <String, Object?>{
    'en':
        'Divine moments from the grand Avsar 200 celebrations. '
        'Thousands of devotees took darshan of Shree Revati Baldevji '
        'Harikrushna Maharaj during the five-day mahotsav.',
    'gu': 'અવસર ૨૦૦ મહોત્સવની દિવ્ય ક્ષણો.',
  },
  'coverUrl': 'gallery/avsar-200/cover.jpg',
  'eventDate': Timestamp.fromDate(DateTime(2025, 9, 2)),
  'isFeatured': true,
  'photoCount': 40,
});

final Album _diwali = Album.fromMap('diwali-2025', <String, Object?>{
  'title': 'Diwali & Annakut',
  'coverUrl': 'gallery/diwali-2025/cover.jpg',
  'eventDate': Timestamp.fromDate(DateTime(2025, 10, 21)),
  'photoCount': 1,
});

final Album _sharad = Album.fromMap('sharad-purnima', <String, Object?>{
  'title': 'Sharad Purnima',
});

final List<AlbumPhoto> _avsarPhotos = <AlbumPhoto>[
  for (int i = 0; i < 40; i++)
    AlbumPhoto.fromMap('p$i', <String, Object?>{
      'url': 'gallery/avsar-200/p$i.jpg',
      'order': i,
      if (i == 2)
        'caption': <String, Object?>{
          'en': 'Shree Harikrushna Maharaj shangar darshan',
          'gu': 'શ્રી હરિકૃષ્ણ મહારાજ શણગાર દર્શન',
        },
    }),
];

class _FakeSaver extends PhotoSaver {
  _FakeSaver({
    this.access = const SaveAccess.album(PhotoSaver.albumName),
    this.outcome = PhotoSaveOutcome.saved,
    this.failIds = const <String>{},
  }) : super(resolveUrl: (String raw) async => raw);

  final SaveAccess? access;
  final PhotoSaveOutcome outcome;

  /// Photos that fail to save even though [outcome] is `saved`.
  final Set<String> failIds;
  final List<String> saved = <String>[];
  final List<String> failed = <String>[];
  final List<String> shared = <String>[];

  @override
  Future<SaveAccess?> requestAccess() async => access;

  @override
  Future<PhotoSaveOutcome> save(
    AlbumPhoto photo, {
    required String albumId,
    SaveAccess? access,
  }) async {
    if ((access ?? this.access) == null) return PhotoSaveOutcome.denied;
    final PhotoSaveOutcome result = failIds.contains(photo.id)
        ? PhotoSaveOutcome.failed
        : outcome;
    (result == PhotoSaveOutcome.saved ? saved : failed).add(photo.id);
    return result;
  }

  @override
  Future<bool> share(
    AlbumPhoto photo, {
    required String albumId,
    String? text,
    Rect? origin,
  }) async {
    shared.add(photo.id);
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LiveList<Album>? albums,
  Map<String, AlbumLookup>? lookups,
  Map<String, LiveList<AlbumPhoto>>? photos,
  PhotoSaver? saver,
  Size size = const Size(390, 844),
  double textScale = 1,
  AppLanguage language = AppLanguage.en,
  ThemeMode themeMode = ThemeMode.light,
  bool online = true,
  Future<String> Function(String raw)? resolveUrl,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    PrefKeys.language: language.code,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final LiveList<Album> albumList =
      albums ?? LiveList<Album>(<Album>[_avsar, _diwali, _sharad]);
  final Map<String, AlbumLookup> lookupMap =
      lookups ??
      <String, AlbumLookup>{
        'avsar-200': AlbumLookup(_avsar),
        'diwali-2025': AlbumLookup(_diwali),
      };
  final Map<String, LiveList<AlbumPhoto>> photoMap =
      photos ??
      <String, LiveList<AlbumPhoto>>{
        'avsar-200': LiveList<AlbumPhoto>(_avsarPhotos),
      };

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWith(
          (Ref ref) => Stream<AppConfig>.value(AppConfig.fallback),
        ),
        albumsProvider.overrideWith(
          (Ref ref) => Stream<LiveList<Album>>.value(albumList),
        ),
        albumLookupProvider.overrideWith(
          (Ref ref, String id) => Stream<AlbumLookup>.value(
            lookupMap[id] ?? const AlbumLookup(null),
          ),
        ),
        albumPhotosProvider.overrideWith(
          (Ref ref, String id) => Stream<LiveList<AlbumPhoto>>.value(
            photoMap[id] ?? const LiveList<AlbumPhoto>(<AlbumPhoto>[]),
          ),
        ),
        // No network in tests: Storage links never resolve.
        mediaUrlProvider.overrideWith(
          (Ref ref, String raw) =>
              resolveUrl?.call(raw) ?? Completer<String>().future,
        ),
        isOnlineProvider.overrideWith((Ref ref) => Stream<bool>.value(online)),
        photoSaverProvider.overrideWithValue(saver ?? _FakeSaver()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(language),
        darkTheme: AppTheme.dark(language),
        themeMode: themeMode,
        locale: language.locale,
        supportedLocales: AppLanguage.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  // Shimmer placeholders animate forever, so pump a fixed time instead of
  // pumpAndSettle.
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(initializeDateFormatting);

  group('GalleryScreen', () {
    testWidgets('lists albums with title, photo count and date', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const GalleryScreen());
      expect(find.text('Photo Gallery'), findsOneWidget);
      expect(
        find.text('Avsar 200 – Bicentenary Mahotsav of Shree Jetalpur Dham'),
        findsOneWidget,
      );
      expect(find.text('40 photos'), findsOneWidget);
      expect(find.text('Diwali & Annakut'), findsOneWidget);
      expect(find.text('1 photo'), findsOneWidget);
      expect(find.text('Sharad Purnima'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty and offline states', (WidgetTester tester) async {
      await _pump(
        tester,
        const GalleryScreen(),
        albums: const LiveList<Album>(<Album>[]),
      );
      expect(find.text('Photos will be added soon.'), findsOneWidget);

      await _pump(
        tester,
        const GalleryScreen(),
        albums: const LiveList<Album>(<Album>[], isFromCache: true),
      );
      expect(
        find.text('No internet connection. Please check your network.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Gujarati, large text, small phone, dark', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const GalleryScreen(),
        size: const Size(320, 568),
        textScale: 1.4,
        language: AppLanguage.gu,
        themeMode: ThemeMode.dark,
      );
      expect(find.text('ફોટો ગેલેરી'), findsOneWidget);
      expect(
        find.text('અવસર ૨૦૦ – શ્રી જેતલપુર ધામનો દ્વિશતાબ્દી મહોત્સવ'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AlbumScreen', () {
    testWidgets('shows header, details and the photo grid', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const AlbumScreen(albumId: 'avsar-200'));
      expect(
        find.text('Avsar 200 – Bicentenary Mahotsav of Shree Jetalpur Dham'),
        findsWidgets,
      );
      expect(find.text('40 photos'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.byType(PhotoTile), findsWidgets);
      expect(find.bySemanticsLabel('Photo 1 of 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('select photos and save them to the gallery', (
      WidgetTester tester,
    ) async {
      final _FakeSaver saver = _FakeSaver();
      await _pump(
        tester,
        const AlbumScreen(albumId: 'avsar-200'),
        saver: saver,
      );

      await tester.longPress(find.byType(PhotoTile).first);
      await _settle(tester);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Save 1 photo'), findsOneWidget);

      await tester.tap(find.byType(PhotoTile).at(1));
      await _settle(tester);
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byType(PhotoTile).at(1));
      await _settle(tester);
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Select all'));
      await _settle(tester);
      expect(find.text('40 selected'), findsOneWidget);
      expect(find.byTooltip('Clear selection'), findsOneWidget);

      await tester.tap(find.text('Save 40 photos'));
      await _settle(tester);
      expect(saver.saved, hasLength(40));
      expect(saver.saved.first, 'p0');
      expect(find.text('40 photos saved'), findsOneWidget);
      // Selection mode ends after saving.
      expect(find.text('Select'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('permission denied keeps the selection', (
      WidgetTester tester,
    ) async {
      final _FakeSaver saver = _FakeSaver(access: null);
      await _pump(
        tester,
        const AlbumScreen(albumId: 'avsar-200'),
        saver: saver,
      );
      await tester.tap(find.text('Select'));
      await _settle(tester);
      expect(find.text('Tap photos to select them'), findsOneWidget);
      await tester.tap(find.byType(PhotoTile).first);
      await _settle(tester);
      await tester.tap(find.text('Save 1 photo'));
      await _settle(tester);
      expect(saver.saved, isEmpty);
      expect(
        find.text('Please allow photo access in Settings to save images.'),
        findsOneWidget,
      );
      expect(find.text('1 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('photos that failed stay selected for another try', (
      WidgetTester tester,
    ) async {
      final _FakeSaver saver = _FakeSaver(failIds: <String>{'p1', 'p3'});
      await _pump(
        tester,
        const AlbumScreen(albumId: 'avsar-200'),
        saver: saver,
      );
      await tester.longPress(find.byType(PhotoTile).first);
      await _settle(tester);
      await tester.tap(find.byTooltip('Select all'));
      await _settle(tester);
      await tester.tap(find.text('Save 40 photos'));
      await _settle(tester);
      expect(saver.saved, hasLength(38));
      expect(saver.failed, <String>['p1', 'p3']);
      expect(
        find.text("38 photos saved · 2 photos couldn't be saved"),
        findsOneWidget,
      );
      expect(find.text('2 selected'), findsOneWidget);

      // One tap retries just those two.
      await tester.tap(find.text('Save 2 photos'));
      await _settle(tester);
      expect(saver.failed, <String>['p1', 'p3', 'p1', 'p3']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('saving while offline explains why photos were not saved', (
      WidgetTester tester,
    ) async {
      final _FakeSaver saver = _FakeSaver(outcome: PhotoSaveOutcome.failed);
      await _pump(
        tester,
        const AlbumScreen(albumId: 'avsar-200'),
        saver: saver,
        online: false,
      );
      await tester.longPress(find.byType(PhotoTile).first);
      await _settle(tester);
      await tester.tap(find.byTooltip('Select all'));
      await _settle(tester);
      await tester.tap(find.text('Save 40 photos'));
      await _settle(tester);
      // Stops after 5 failures in a row instead of trying all 40.
      expect(saver.failed, hasLength(5));
      expect(
        find.text(
          "40 photos couldn't be saved · "
          'No internet connection. Please check your network.',
        ),
        findsOneWidget,
      );
      // The selection stays so the devotee can try again later.
      expect(find.text('40 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing, hidden and offline albums', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const AlbumScreen(albumId: 'unknown'));
      expect(find.text('This album is no longer available.'), findsOneWidget);

      await _pump(
        tester,
        const AlbumScreen(albumId: 'hidden'),
        albums: const LiveList<Album>(<Album>[]),
        lookups: <String, AlbumLookup>{
          'hidden': AlbumLookup(
            Album.fromMap('hidden', const <String, Object?>{'isActive': false}),
          ),
        },
        photos: <String, LiveList<AlbumPhoto>>{
          'hidden': LiveList<AlbumPhoto>(_avsarPhotos),
        },
      );
      expect(find.text('This album is no longer available.'), findsOneWidget);

      await _pump(
        tester,
        const AlbumScreen(albumId: 'offline'),
        albums: const LiveList<Album>(<Album>[]),
        lookups: <String, AlbumLookup>{
          'offline': const AlbumLookup(null, isFromCache: true),
        },
      );
      expect(
        find.text('No internet connection. Please check your network.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('album without photos says photos are coming', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const AlbumScreen(albumId: 'diwali-2025'));
      expect(find.text('Diwali & Annakut'), findsWidgets);
      expect(find.text('Photos will be added soon.'), findsOneWidget);
      expect(find.text('Select'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('photos without an album document still show', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const AlbumScreen(albumId: 'avsar-200'),
        albums: const LiveList<Album>(<Album>[]),
        lookups: const <String, AlbumLookup>{},
      );
      expect(find.text('Avsar 200'), findsWidgets);
      expect(find.byType(PhotoTile), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Gujarati, large text, small phone, dark, selecting', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const AlbumScreen(albumId: 'avsar-200'),
        size: const Size(320, 568),
        textScale: 1.4,
        language: AppLanguage.gu,
        themeMode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      // The header and description fill a small screen; scroll to the grid.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await _settle(tester);
      await tester.longPress(find.byType(PhotoTile).first);
      await _settle(tester);
      expect(find.text('1 તસવીર સાચવો'), findsOneWidget);
      expect(find.text('1 પસંદ કરી'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeGalleryPreview', () {
    testWidgets('shows the first 12 photos and a see-all tile', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: HomeGalleryPreview()),
        ),
      );
      expect(find.text('Avsar 200 Photos'), findsOneWidget);
      expect(find.text('See all'), findsWidgets);
      final int built = tester
          .widgetList(find.byType(PhotoTile, skipOffstage: false))
          .length;
      expect(built, inInclusiveRange(1, 12));
      expect(tester.takeException(), isNull);
    });

    testWidgets('see-all tile fits in Gujarati with large text, dark', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: HomeGalleryPreview()),
        ),
        size: const Size(320, 568),
        textScale: 1.4,
        language: AppLanguage.gu,
        themeMode: ThemeMode.dark,
      );
      expect(find.text('અવસર ૨૦૦ તસવીરો'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(-3000, 0));
      await _settle(tester);
      expect(find.text('40 તસવીરો'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden when the album is empty or missing', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: HomeGalleryPreview()),
        ),
        photos: const <String, LiveList<AlbumPhoto>>{},
      );
      expect(find.text('Avsar 200 Photos'), findsNothing);
      expect(find.byType(PhotoTile), findsNothing);

      await _pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: HomeGalleryPreview()),
        ),
        lookups: const <String, AlbumLookup>{},
        photos: const <String, LiveList<AlbumPhoto>>{},
      );
      expect(find.text('Avsar 200 Photos'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('PhotoViewerScreen', () {
    testWidgets('shows position, caption and actions; saves and shares', (
      WidgetTester tester,
    ) async {
      final _FakeSaver saver = _FakeSaver();
      await _pump(
        tester,
        const PhotoViewerScreen(albumId: 'avsar-200', initialIndex: 2),
        saver: saver,
      );
      expect(find.text('3 / 40'), findsOneWidget);
      expect(
        find.text('Shree Harikrushna Maharaj shangar darshan'),
        findsOneWidget,
      );
      expect(find.text('Save to Gallery'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      await tester.tap(find.text('Save to Gallery'));
      await _settle(tester);
      expect(saver.saved, <String>['p2']);
      expect(find.text('Saved to your gallery'), findsOneWidget);

      await tester.tap(find.text('Share'));
      await _settle(tester);
      expect(saver.shared, <String>['p2']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Gujarati, large text, small phone', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const PhotoViewerScreen(albumId: 'avsar-200', initialIndex: 2),
        size: const Size(320, 568),
        textScale: 1.4,
        language: AppLanguage.gu,
      );
      expect(find.text('3 / 40'), findsOneWidget);
      expect(find.text('શ્રી હરિકૃષ્ણ મહારાજ શણગાર દર્શન'), findsOneWidget);
      expect(find.text('ગેલેરીમાં સાચવો'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a page hides and shows the controls', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const PhotoViewerScreen(albumId: 'avsar-200'));
      Finder visibleOpacity() => find.ancestor(
        of: find.text('Save to Gallery'),
        matching: find.byWidgetPredicate(
          (Widget w) => w is AnimatedOpacity && w.opacity == 1,
        ),
      );
      expect(visibleOpacity(), findsOneWidget);
      await tester.tapAt(const Offset(195, 400));
      await _settle(tester);
      expect(visibleOpacity(), findsNothing);
      await tester.tapAt(const Offset(195, 400));
      await _settle(tester);
      expect(visibleOpacity(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping moves to the next photo', (WidgetTester tester) async {
      await _pump(
        tester,
        const PhotoViewerScreen(albumId: 'avsar-200', initialIndex: 5),
      );
      expect(find.text('6 / 40'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
      await _settle(tester);
      expect(find.text('7 / 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new index for the same screen moves to that photo', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<int> index = ValueNotifier<int>(2);
      addTearDown(index.dispose);
      await _pump(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (BuildContext context, int i, Widget? child) =>
              PhotoViewerScreen(albumId: 'avsar-200', initialIndex: i),
        ),
      );
      expect(find.text('3 / 40'), findsOneWidget);
      index.value = 7;
      await _settle(tester);
      expect(find.text('8 / 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('out-of-range index is clamped', (WidgetTester tester) async {
      await _pump(
        tester,
        const PhotoViewerScreen(albumId: 'avsar-200', initialIndex: 999),
      );
      expect(find.text('40 / 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('saving one photo offline says there is no internet', (
      WidgetTester tester,
    ) async {
      final _FakeSaver saver = _FakeSaver(outcome: PhotoSaveOutcome.failed);
      await _pump(
        tester,
        const PhotoViewerScreen(albumId: 'avsar-200'),
        saver: saver,
        online: false,
      );
      await tester.tap(find.text('Save to Gallery'));
      await _settle(tester);
      expect(saver.failed, <String>['p0']);
      expect(
        find.text('No internet connection. Please check your network.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a photo that fails to load offers Retry', (
      WidgetTester tester,
    ) async {
      final List<String> requests = <String>[];
      await _pump(
        tester,
        const PhotoViewerScreen(albumId: 'avsar-200'),
        resolveUrl: (String raw) {
          requests.add(raw);
          // The first lookup fails (e.g. no internet), later ones hang.
          return requests.length == 1
              ? Future<String>.error(StateError('offline'))
              : Completer<String>().future;
        },
      );
      expect(find.text("Couldn't load this photo"), findsOneWidget);
      final int before = requests
          .where((String r) => r == _avsarPhotos.first.url)
          .length;

      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(find.text("Couldn't load this photo"), findsNothing);
      expect(
        requests.where((String r) => r == _avsarPhotos.first.url).length,
        before + 1,
      );
      // Tapping the page still shows/hides the controls while loading.
      final Finder visible = find.ancestor(
        of: find.text('Save to Gallery'),
        matching: find.byWidgetPredicate(
          (Widget w) => w is AnimatedOpacity && w.opacity == 1,
        ),
      );
      expect(visible, findsOneWidget);
      await tester.tapAt(const Offset(195, 400));
      await _settle(tester);
      expect(visible, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a hidden album is not shown from an old link', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const PhotoViewerScreen(albumId: 'hidden', initialIndex: 3),
        lookups: <String, AlbumLookup>{
          'hidden': AlbumLookup(
            Album.fromMap('hidden', const <String, Object?>{'isActive': false}),
          ),
        },
        photos: <String, LiveList<AlbumPhoto>>{
          'hidden': LiveList<AlbumPhoto>(_avsarPhotos),
        },
      );
      expect(find.text('This album is no longer available.'), findsOneWidget);
      expect(find.text('Save to Gallery'), findsNothing);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty album shows a friendly message', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const PhotoViewerScreen(albumId: 'diwali-2025'),
        language: AppLanguage.hi,
      );
      expect(find.text('तस्वीरें जल्द ही जोड़ी जाएँगी।'), findsOneWidget);
      expect(find.byTooltip('बंद करें'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
