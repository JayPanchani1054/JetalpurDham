import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/events/data/events_repository.dart';
import 'package:jetalpur_dham/features/events/domain/temple_time.dart';

void main() {
  group('TempleTime', () {
    test('converts instants to India wall-clock time', () {
      expect(
        TempleTime.fromInstant(DateTime.utc(2026, 10, 19, 18, 30)),
        DateTime(2026, 10, 20),
      );
      expect(
        TempleTime.fromInstant(DateTime.utc(2026, 10, 20, 14)),
        DateTime(2026, 10, 20, 19, 30),
      );
    });

    test('parse keeps zone-less values and converts zoned ones', () {
      expect(
        TempleTime.parse('2026-10-20T19:30'),
        DateTime(2026, 10, 20, 19, 30),
      );
      expect(
        TempleTime.parse('2026-10-20T14:00:00Z'),
        DateTime(2026, 10, 20, 19, 30),
      );
      expect(
        TempleTime.parse(DateTime.utc(2026, 10, 20, 14)),
        DateTime(2026, 10, 20, 19, 30),
      );
      expect(
        TempleTime.parse(DateTime(2026, 10, 20, 19, 30)),
        DateTime(2026, 10, 20, 19, 30),
      );
      expect(TempleTime.parse('soon'), isNull);
      expect(TempleTime.parse(null), isNull);
      expect(TempleTime.parse(<String>[]), isNull);
    });

    test('untilNextMidnight counts to the next India midnight', () {
      expect(
        TempleTime.untilNextMidnight(DateTime(2026, 10, 20, 23, 59, 30)),
        const Duration(seconds: 30),
      );
      expect(
        TempleTime.untilNextMidnight(DateTime(2026, 12, 31)),
        const Duration(days: 1),
      );
    });
  });

  group('eventsTodayProvider', () {
    late DateTime instant;

    setUp(() => EventsToday.clock = () => instant);
    tearDown(() => EventsToday.clock = DateTime.now);

    test('is the India date, not the phone date', () {
      // 20:00 UTC on the 19th is already 01:30 on the 20th in India.
      instant = DateTime.utc(2026, 10, 19, 20);
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(eventsTodayProvider), DateTime(2026, 10, 20));
    });

    testWidgets('moves to the new day when the app is resumed', (
      WidgetTester tester,
    ) async {
      instant = DateTime.utc(2026, 10, 10, 12);
      final ProviderContainer container = ProviderContainer();
      final List<DateTime> seen = <DateTime>[];
      container.listen<DateTime>(
        eventsTodayProvider,
        (_, DateTime next) => seen.add(next),
        fireImmediately: true,
      );
      expect(seen, <DateTime>[DateTime(2026, 10, 10)]);

      // The phone slept through the night with the app in the background.
      instant = DateTime.utc(2026, 10, 11, 3);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(seen.last, DateTime(2026, 10, 11));

      // Resuming again on the same day does not notify.
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(seen, hasLength(2));

      // Cancels the midnight timer before the test ends.
      container.dispose();
    });
  });
}
