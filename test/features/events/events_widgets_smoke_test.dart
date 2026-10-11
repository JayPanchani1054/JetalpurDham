import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jetalpur_dham/core/l10n/app_language.dart';
import 'package:jetalpur_dham/core/l10n/l10n.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/theme/app_theme.dart';
import 'package:jetalpur_dham/features/events/data/events_repository.dart';
import 'package:jetalpur_dham/features/events/domain/temple_event.dart';
import 'package:jetalpur_dham/features/events/domain/temple_time.dart';
import 'package:jetalpur_dham/features/events/presentation/event_detail_screen.dart';
import 'package:jetalpur_dham/features/events/presentation/events_screen.dart';
import 'package:jetalpur_dham/features/events/presentation/widgets/home_upcoming_events.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the events screens with fake Firestore data (no Firebase, no
/// network: banners are left empty so the built-in artwork is used) to catch
/// build errors and layout overflows, including Gujarati and large text.

final DateTime _today = DateTime(2026, 10, 11);

/// Timestamp for an India (IST) wall-clock time, as entered by temple staff.
Timestamp _ts(int month, int day, [int hour = 0, int minute = 0]) =>
    Timestamp.fromDate(
      DateTime.utc(
        2026,
        month,
        day,
        hour,
        minute,
      ).subtract(TempleTime.utcOffset),
    );

final List<TempleEvent> _events = <TempleEvent>[
  TempleEvent.fromMap('sharad-purnima', <String, Object?>{
    'title': <String, Object?>{
      'en': 'Sharad Purnima Mahotsav with Raas Utsav and Doodh-Poha Prasad',
      'gu': 'શરદ પૂર્ણિમા મહોત્સવ - રાસ ઉત્સવ અને દૂધ-પૌંઆ પ્રસાદ',
    },
    'shortDescription': <String, Object?>{
      'en': 'Join the grand raas and darshan under the full moon.',
      'gu': 'પૂર્ણિમાની ચાંદનીમાં ભવ્ય રાસ અને દર્શનનો લાભ લો.',
    },
    'description': 'Full description of the utsav.\nSecond paragraph.',
    'location': 'Sabha Mandap, Jetalpur Dham',
    'startAt': _ts(10, 11, 19, 30),
    'endAt': _ts(10, 11, 22),
    'type': 'utsav',
    'albumId': 'avsar-200',
    'liveUrl': 'https://youtube.com/live/abc',
  }),
  TempleEvent.fromMap('katha', <String, Object?>{
    'title': 'Shrimad Bhagwat Katha',
    'startAt': _ts(10, 9),
    'endAt': _ts(10, 15),
    'type': 'katha',
  }),
  TempleEvent.fromMap('notice', <String, Object?>{
    'title': 'Darshan timings change',
    'startAt': _ts(10, 12),
    'type': 'announcement',
  }),
  TempleEvent.fromMap('annakut', <String, Object?>{
    'title': 'Annakut',
    'startAt': _ts(10, 21, 7),
    'type': 'utsav',
  }),
  TempleEvent.fromMap('avsar-200', <String, Object?>{
    'title': 'Avsar 200',
    'shortDescription': 'Bicentenary celebration',
    'startAt': _ts(9, 1, 8),
    'endAt': _ts(9, 3, 20),
    'albumId': 'avsar-200',
    'liveUrl': 'https://youtube.com/live/old',
    'type': 'utsav',
  }),
  TempleEvent.fromMap('hidden', <String, Object?>{
    'title': 'Hidden event',
    'startAt': _ts(10, 13),
    'isActive': false,
  }),
];

class _FixedToday extends EventsToday {
  @override
  DateTime build() => _today;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<TempleEvent>? events,
  Map<String, EventLookup> lookups = const <String, EventLookup>{},
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

  final List<TempleEvent> all = events ?? _events;
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        eventsTodayProvider.overrideWith(_FixedToday.new),
        eventsProvider.overrideWith(
          (Ref ref) => Stream<List<TempleEvent>>.value(
            all.where((TempleEvent e) => e.isActive).toList(),
          ),
        ),
        eventLookupProvider.overrideWith((Ref ref, String id) {
          final EventLookup? lookup = lookups[id];
          if (lookup != null) return Stream<EventLookup>.value(lookup);
          final Iterable<TempleEvent> match = all.where(
            (TempleEvent e) => e.id == id && e.isActive,
          );
          return Stream<EventLookup>.value(
            EventLookup(match.isEmpty ? null : match.first),
          );
        }),
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
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('Events tab lists upcoming then past events', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const EventsScreen());
    expect(find.text('Utsav & Events'), findsOneWidget);
    expect(
      find.text(
        'Sharad Purnima Mahotsav with Raas Utsav and Doodh-Poha Prasad',
      ),
      findsOneWidget,
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Ongoing'), findsOneWidget);
    expect(find.text('Hidden event'), findsNothing);
    expect(find.text('Avsar 200'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Past'));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Avsar 200'), findsOneWidget);
    expect(find.text('Bicentenary celebration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Events tab shows friendly empty states', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const EventsScreen(), events: const <TempleEvent>[]);
    expect(
      find.text("No upcoming utsav right now. We'll notify you!"),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Events tab in Gujarati, large text, small phone, dark', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const EventsScreen(),
      size: const Size(320, 568),
      textScale: 1.4,
      language: AppLanguage.gu,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('ઉત્સવ અને કાર્યક્રમો'), findsOneWidget);
    expect(find.text('આજે'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Event detail shows info, actions and description', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const EventDetailScreen(eventId: 'sharad-purnima'));
    expect(find.text('Watch Live'), findsOneWidget);
    expect(find.text('View Photos'), findsOneWidget);
    // Below the fold on a phone, but built.
    expect(find.text('Share', skipOffstage: false), findsOneWidget);
    expect(find.text('Venue'), findsOneWidget);
    expect(find.text('Sabha Mandap, Jetalpur Dham'), findsOneWidget);
    expect(find.text('Sunday, October 11, 2026'), findsOneWidget);
    // intl may use a narrow no-break space before "PM". Phones outside
    // India (like the test machine) also get an "(India time)" hint.
    final String indiaHint = TempleTime.isDeviceOutsideIndia()
        ? r' \(India time\)'
        : '';
    expect(
      find.textContaining(RegExp('^7:30\\sPM – 10:00\\sPM$indiaHint\$')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // The description sits below the fold; scrolling must stay smooth and
    // flip the app bar to its collapsed style without errors.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Past event hides Watch Live; multi-day shows the range', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const EventDetailScreen(eventId: 'avsar-200'));
    expect(find.text('Watch Live'), findsNothing);
    expect(find.text('View Photos'), findsOneWidget);
    expect(
      find.text('Tuesday, September 1, 2026 –\nThursday, September 3, 2026'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Event detail in Hindi with large text and dark mode', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const EventDetailScreen(eventId: 'katha'),
      size: const Size(320, 568),
      textScale: 1.4,
      language: AppLanguage.hi,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('जारी है'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Missing event shows not-found with a way back', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const EventDetailScreen(eventId: 'deleted'));
    expect(find.text('This event is no longer available.'), findsOneWidget);
    expect(find.text('See all utsav'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Uncached event while offline shows a network message', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const EventDetailScreen(eventId: 'new-one'),
      lookups: <String, EventLookup>{
        'new-one': const EventLookup(null, isFromCache: true),
      },
    );
    expect(
      find.text('No internet connection. Please check your network.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home section lists upcoming events in a row', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: HomeUpcomingEvents())),
    );
    expect(find.text('Upcoming Utsav'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('Shrimad Bhagwat Katha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home section fits large Gujarati text', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: HomeUpcomingEvents())),
      size: const Size(320, 568),
      textScale: 1.4,
      language: AppLanguage.gu,
    );
    expect(find.text('આગામી ઉત્સવ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home section hides itself when nothing is upcoming', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: HomeUpcomingEvents())),
      events: <TempleEvent>[_events.last, _events[4]],
    );
    expect(find.text('Upcoming Utsav'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
