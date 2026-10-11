import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/config/app_config.dart';
import 'package:jetalpur_dham/core/l10n/app_language.dart';
import 'package:jetalpur_dham/core/l10n/l10n.dart';
import 'package:jetalpur_dham/core/services/connectivity_service.dart';
import 'package:jetalpur_dham/core/services/preferences.dart';
import 'package:jetalpur_dham/core/theme/app_theme.dart';
import 'package:jetalpur_dham/features/donation/data/donation_repository.dart';
import 'package:jetalpur_dham/features/donation/domain/donation_config.dart';
import 'package:jetalpur_dham/features/donation/presentation/donation_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the donation screen and form with fake data (no Firebase, no
/// network: the QR is generated from the UPI ID) to catch build errors and
/// layout overflows, including Gujarati, large text and dark mode.

final DonationConfig _config = DonationConfig.fromMap(<String, Object?>{
  'enabled': true,
  'message': <String, Object?>{
    'en': 'Every offering supports daily seva.',
    'gu': 'દરેક દાન નિત્ય સેવામાં ઉપયોગી બને છે.',
  },
  'note': '80G tax exemption available on request.',
  'upiId': 'jetalpurdham@sbi',
  'payeeName': 'Shree Swaminarayan Mandir Jetalpur',
  'bank': <String, Object?>{
    'accountName': 'Shree Swaminarayan Mandir Jetalpur Trust',
    'accountNumber': '1234 5678 9012',
    'ifsc': 'SBIN0001234',
    'bankName': 'State Bank of India',
    'branch': 'Jetalpur, Ahmedabad',
    'accountType': 'Savings',
  },
  'contactPhone': '+919876543210',
  'contactWhatsapp': '919876543210',
  'purposes': <Object?>[
    <String, Object?>{'en': 'General seva', 'gu': 'સામાન્ય સેવા'},
    <String, Object?>{'en': 'Annakut', 'gu': 'અન્નકૂટ'},
  ],
});

class _FakeRepository extends DonationRepository {
  _FakeRepository(this.result)
    : super(
        addDocument: (Map<String, Object?> _) async {},
        appVersion: () async => 'test',
      );

  final FutureOr<DonationSubmitResult> Function() result;
  int calls = 0;

  @override
  Future<DonationSubmitResult> submit(
    _, {
    Duration? timeout,
    Object? createdAt,
  }) async {
    calls++;
    return result();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(
  WidgetTester tester, {
  DonationConfigSnapshot? snapshot,
  Object? error,
  DonationRepository? repository,
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
      key: UniqueKey(),
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        appConfigValueProvider.overrideWithValue(AppConfig.fallback),
        isOnlineProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
        donationConfigProvider.overrideWith(
          (Ref ref) => error != null
              ? Stream<DonationConfigSnapshot>.error(error)
              : Stream<DonationConfigSnapshot>.value(
                  snapshot ??
                      DonationConfigSnapshot(config: _config, fromCache: false),
                ),
        ),
        if (repository != null)
          donationRepositoryProvider.overrideWithValue(repository),
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
        home: const DonationScreen(),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _openForm(WidgetTester tester) async {
  final Finder contactNow = find.text('Contact Now');
  await _scrollTo(tester, contactNow);
  await tester.tap(contactNow);
  await _settle(tester);
  expect(find.text('Share Donation Details'), findsWidgets);
}

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

void main() {
  testWidgets('shows QR, bank details and contact options', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    expect(find.text('Donate'), findsOneWidget);
    expect(find.text('Offer Your Seva'), findsOneWidget);
    expect(find.text('Every offering supports daily seva.'), findsOneWidget);
    expect(find.text('Scan & Pay'), findsOneWidget);
    expect(find.text('jetalpurdham@sbi'), findsOneWidget);
    expect(find.text('Save QR'), findsOneWidget);

    await _scrollTo(tester, find.text('Copy all details'));
    expect(find.text('Bank Transfer'), findsOneWidget);
    expect(find.text('SBIN0001234'), findsOneWidget);
    expect(find.text('1234 5678 9012'), findsOneWidget);

    await _scrollTo(tester, find.text('WhatsApp'));
    expect(find.text('Contact Now'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled config hides payments but keeps Contact Now', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      snapshot: DonationConfigSnapshot(
        config: DonationConfig.fromMap(<String, Object?>{
          'enabled': false,
          'upiId': 'jetalpurdham@sbi',
          'contactPhone': '+919876543210',
        }),
        fromCache: false,
      ),
    );
    expect(
      find.text('Donation details will be available soon.'),
      findsOneWidget,
    );
    expect(find.text('Scan & Pay'), findsNothing);
    expect(find.text('Bank Transfer'), findsNothing);
    await _scrollTo(tester, find.text('Call'));
    expect(find.text('Contact Now'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing document offline asks to retry; error too', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      snapshot: const DonationConfigSnapshot(config: null, fromCache: true),
    );
    expect(
      find.text('No internet connection. Please check your network.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await _pump(tester, error: StateError('boom'));
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    await _scrollTo(tester, find.text('Contact Now'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gujarati, large text, small phone, dark mode', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      size: const Size(320, 568),
      textScale: 1.4,
      language: AppLanguage.gu,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('દાન'), findsOneWidget);
    expect(find.text('દરેક દાન નિત્ય સેવામાં ઉપયોગી બને છે.'), findsOneWidget);
    await _scrollTo(tester, find.text('બધી વિગતો કૉપિ કરો'));
    await _scrollTo(tester, find.text('હમણાં સંપર્ક કરો'));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('હમણાં સંપર્ક કરો'));
    await _settle(tester);
    expect(find.text('દાનની વિગતો મોકલો'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form validates, submits once and shows thank you', (
    WidgetTester tester,
  ) async {
    final Completer<DonationSubmitResult> pending =
        Completer<DonationSubmitResult>();
    final _FakeRepository repository = _FakeRepository(() => pending.future);
    await _pump(tester, repository: repository);
    await _openForm(tester);

    final Finder submit = find.text('Submit details');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _settle(tester);
    expect(find.text('This field is required'), findsWidgets);
    expect(repository.calls, 0);

    await tester.enterText(_field('Full name *'), 'Ramesh Patel');
    await tester.enterText(_field('Mobile number *'), '12345');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _settle(tester);
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);

    await tester.enterText(_field('Mobile number *'), '+91 98765 43210');
    await tester.ensureVisible(find.text('Bank transfer'));
    await tester.tap(find.text('Bank transfer'));
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Submitting…'), findsOneWidget);

    // A second tap while submitting does nothing.
    await tester.tap(find.text('Submitting…'), warnIfMissed: false);
    await tester.pump();
    expect(repository.calls, 1);

    pending.complete(DonationSubmitResult.sent);
    await _settle(tester);
    expect(find.text('Thank you!'), findsOneWidget);
    expect(
      find.text(
        "You're offline right now. Your details are saved on this phone and "
        "will be sent automatically once you're connected.",
      ),
      findsNothing,
    );

    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text('Thank you!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('queued submission explains offline sync; errors show inline', (
    WidgetTester tester,
  ) async {
    int attempt = 0;
    final _FakeRepository repository = _FakeRepository(() {
      attempt++;
      if (attempt == 1) throw StateError('rejected');
      return DonationSubmitResult.queued;
    });
    await _pump(tester, repository: repository);
    await _openForm(tester);

    await tester.enterText(_field('Full name *'), 'Ramesh Patel');
    await tester.enterText(_field('Mobile number *'), '9876543210');
    await tester.ensureVisible(find.text('Cash'));
    await tester.tap(find.text('Cash'));
    await tester.pump();
    expect(_field('Transaction / UTR no. (optional)'), findsNothing);

    final Finder submit = find.text('Submit details');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _settle(tester);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _settle(tester);
    expect(find.text('Thank you!'), findsOneWidget);
    expect(
      find.text(
        "You're offline right now. Your details are saved on this phone and "
        "will be sent automatically once you're connected.",
      ),
      findsOneWidget,
    );
    expect(repository.calls, 2);
    expect(tester.takeException(), isNull);
  });
}
