import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/l10n/app_language.dart';
import 'package:jetalpur_dham/core/l10n/l10n.dart';
import 'package:jetalpur_dham/core/services/connectivity_service.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/theme/app_theme.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_player_controller.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_player_state.dart';
import 'package:jetalpur_dham/features/kirtan/data/kirtan_repository.dart';
import 'package:jetalpur_dham/features/kirtan/domain/kirtan.dart';
import 'package:jetalpur_dham/features/kirtan/presentation/kirtan_downloads_screen.dart';
import 'package:jetalpur_dham/features/kirtan/presentation/kirtan_screen.dart';
import 'package:jetalpur_dham/features/kirtan/presentation/now_playing_screen.dart';
import 'package:jetalpur_dham/features/kirtan/presentation/widgets/home_featured_kirtans.dart';
import 'package:jetalpur_dham/features/kirtan/presentation/widgets/mini_player.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every kirtan screen with fake player state (no platform audio, no
/// Firebase) to catch layout overflows and build errors, including with large
/// text and Gujarati content.

final List<Kirtan> _kirtans = <Kirtan>[
  for (int i = 0; i < 30; i++)
    Kirtan.fromMap('k$i', <String, Object?>{
      'title': <String, Object?>{
        'en': i.isEven
            ? 'Jay Sadguru Swami Sahajanand Dindayal $i'
            : 'Prem Sakhi $i',
        'gu': 'જય સદગુરુ સ્વામી સહજાનંદ દીનદયાળ $i',
      },
      'poet': 'Premanand Swami',
      'singer': 'Santo',
      'categoryId': i % 3 == 0 ? 'aarti' : 'dhun',
      'audioUrl': 'kirtans/aarti/k$i.mp3',
      'durationSec': 240 + i,
      'lyrics': 'જય સદગુરુ સ્વામી…\nસહજાનંદ દીનદયાળ…',
      'isFeatured': i < 5,
      'order': i,
    }),
];

final List<KirtanCategory> _categories = <KirtanCategory>[
  KirtanCategory.fromMap('aarti', <String, Object?>{
    'name': <String, Object?>{'en': 'Aarti', 'gu': 'આરતી'},
    'order': 1,
  }),
  KirtanCategory.fromMap('dhun', <String, Object?>{
    'name': <String, Object?>{'en': 'Dhun', 'gu': 'ધૂન'},
    'order': 2,
  }),
];

class _FakePlayer extends KirtanPlayerController {
  _FakePlayer(this._initial);

  final KirtanQueue _initial;

  @override
  KirtanQueue build() => _initial;

  @override
  List<int> upcomingOrder() => <int>[
    for (int i = state.index ?? 0; i < state.items.length; i++) i,
  ];
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  KirtanQueue queue = const KirtanQueue(),
  Size size = const Size(390, 844),
  double textScale = 1,
  AppLanguage language = AppLanguage.en,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    PrefKeys.language: language.code,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope per pump, so each case gets its own fake state.
      key: UniqueKey(),
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOnlineProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
        kirtansProvider.overrideWith(
          (Ref ref) => Stream<List<Kirtan>>.value(_kirtans),
        ),
        kirtanCategoriesProvider.overrideWith(
          (Ref ref) => Stream<List<KirtanCategory>>.value(_categories),
        ),
        kirtanPlayerProvider.overrideWith(() => _FakePlayer(queue)),
        kirtanIsPlayingProvider.overrideWithValue(true),
        kirtanIsLoadingProvider.overrideWithValue(false),
        kirtanHasNextProvider.overrideWithValue(true),
        kirtanProgressProvider.overrideWith(
          (Ref ref) => Stream<KirtanProgress>.value(
            const KirtanProgress(
              position: Duration(seconds: 42),
              buffered: Duration(seconds: 120),
              total: Duration(seconds: 250),
            ),
          ),
        ),
        kirtanShuffleProvider.overrideWith(
          (Ref ref) => Stream<bool>.value(false),
        ),
        kirtanLoopModeProvider.overrideWith(
          (Ref ref) => Stream<LoopMode>.value(LoopMode.all),
        ),
        kirtanSpeedProvider.overrideWith(
          (Ref ref) => Stream<double>.value(1.25),
        ),
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
  // Streams deliver, entrance animations run (the equalizer keeps animating,
  // so never pumpAndSettle).
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

KirtanQueue _playing(int index) => KirtanQueue(items: _kirtans, index: index);

void main() {
  testWidgets('Kirtan screen lists kirtans with chips and Play all', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const KirtanScreen(), queue: _playing(1));
    expect(find.text('Prem Sakhi 1'), findsOneWidget);
    expect(find.text('Aarti'), findsOneWidget);
    expect(find.text('Play all'), findsOneWidget);
    expect(find.text('30 kirtans'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Aarti'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('10 kirtans'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'nothing-matches');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No kirtan found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kirtan screen in Gujarati with large text', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const KirtanScreen(),
      queue: _playing(0),
      size: const Size(320, 640),
      textScale: 1.4,
      language: AppLanguage.gu,
    );
    expect(find.text('આરતી'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing fits small and large phones', (
    WidgetTester tester,
  ) async {
    for (final (Size size, double scale) in <(Size, double)>[
      (const Size(320, 568), 1.4),
      (const Size(360, 640), 1.0),
      (const Size(412, 915), 1.3),
    ]) {
      await _pump(
        tester,
        const NowPlayingScreen(),
        queue: _playing(2),
        size: size,
        textScale: scale,
      );
      expect(
        find.text('Jay Sadguru Swami Sahajanand Dindayal 2'),
        findsOneWidget,
      );
      expect(find.text('1.25×'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Now Playing sheets open in dark mode', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const NowPlayingScreen(),
      queue: _playing(4),
      themeMode: ThemeMode.dark,
    );

    Future<void> openAndClose(Finder button, Finder expected) async {
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(expected, findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await openAndClose(find.text('Lyrics'), find.textContaining('સહજાનંદ'));
    await openAndClose(find.text('Sleep timer'), find.text('End of kirtan'));
    await openAndClose(find.text('1.25×'), find.text('1× · Normal'));
    await openAndClose(find.byTooltip('Up next'), find.text('Prem Sakhi 5'));
  });

  testWidgets('Now Playing without a kirtan offers to browse', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const NowPlayingScreen());
    expect(find.text('Browse kirtans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mini player hides when idle and shows the current kirtan', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const Scaffold(body: MiniPlayer()));
    expect(find.byType(InkWell), findsNothing);

    await _pump(
      tester,
      const Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: MiniPlayer()),
      ),
      queue: _playing(3),
      textScale: 1.4,
    );
    expect(find.text('Prem Sakhi 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home featured kirtans render cards', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: HomeFeaturedKirtans())),
      textScale: 1.4,
    );
    expect(find.text('Featured Kirtans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Downloads screen shows its empty state', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const KirtanDownloadsScreen());
    expect(find.text('Browse kirtans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
