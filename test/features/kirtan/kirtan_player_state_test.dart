import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_player_state.dart';
import 'package:jetalpur_dham/features/kirtan/domain/kirtan.dart';

Kirtan _k(String id) =>
    Kirtan.fromMap(id, <String, Object?>{'title': id, 'audioUrl': '$id.mp3'});

void main() {
  group('KirtanQueue', () {
    test('is empty without a valid index', () {
      expect(const KirtanQueue().isEmpty, isTrue);
      expect(const KirtanQueue().current, isNull);
      expect(KirtanQueue(items: <Kirtan>[_k('a')], index: 3).current, isNull);
      expect(KirtanQueue(items: <Kirtan>[_k('a')], index: -1).current, isNull);
    });

    test('exposes the current kirtan and finds items by id', () {
      final KirtanQueue queue = KirtanQueue(
        items: <Kirtan>[_k('a'), _k('b')],
        index: 1,
      );
      expect(queue.current?.id, 'b');
      expect(queue.indexOfId('a'), 0);
      expect(queue.indexOfId('zzz'), -1);
    });

    test('copyWith keeps unspecified values', () {
      final KirtanQueue queue = KirtanQueue(
        items: <Kirtan>[_k('a'), _k('b')],
        index: 0,
        isPreparing: true,
        errorCount: 2,
      ).copyWith(index: 1, isPreparing: false);
      expect(queue.index, 1);
      expect(queue.isPreparing, isFalse);
      expect(queue.errorCount, 2);
      expect(queue.items, hasLength(2));
      expect(queue.autoplay, isTrue);
    });

    test('isStarting only while loading a kirtan that will play', () {
      final KirtanQueue loading = KirtanQueue(
        items: <Kirtan>[_k('a')],
        index: 0,
        isPreparing: true,
      );
      expect(loading.isStarting, isTrue);
      // Pause tapped while loading: no spinner, play icon instead.
      expect(loading.copyWith(autoplay: false).isStarting, isFalse);
      expect(loading.copyWith(autoplay: false).autoplay, isFalse);
      // Loaded: the player's own state decides.
      expect(loading.copyWith(isPreparing: false).isStarting, isFalse);
    });
  });

  group('KirtanProgress', () {
    test('fraction is clamped and safe for unknown durations', () {
      expect(KirtanProgress.zero.fraction, 0);
      expect(
        const KirtanProgress(
          position: Duration(seconds: 30),
          total: Duration(seconds: 120),
        ).fraction,
        0.25,
      );
      expect(
        const KirtanProgress(
          position: Duration(seconds: 130),
          total: Duration(seconds: 120),
        ).fraction,
        1,
      );
      expect(const KirtanProgress(position: Duration(seconds: 5)).fraction, 0);
    });

    test('has value equality', () {
      expect(
        const KirtanProgress(position: Duration(seconds: 1)),
        const KirtanProgress(position: Duration(seconds: 1)),
      );
      expect(
        const KirtanProgress(position: Duration(seconds: 1)) ==
            const KirtanProgress(position: Duration(seconds: 2)),
        isFalse,
      );
    });
  });

  test('formatKirtanSpeed', () {
    expect(formatKirtanSpeed(1), '1×');
    expect(formatKirtanSpeed(0.75), '0.75×');
    expect(formatKirtanSpeed(1.25), '1.25×');
    expect(formatKirtanSpeed(1.5), '1.5×');
    expect(kKirtanSpeeds, contains(1.0));
  });

  group('KirtanSleepTimer', () {
    test('off / fixed / end of kirtan', () {
      expect(const KirtanSleepTimer.off().isActive, isFalse);
      expect(const KirtanSleepTimer.endOfKirtan().isActive, isTrue);
      expect(
        const KirtanSleepTimer.endOfKirtan().remaining(DateTime(2026)),
        isNull,
      );
      final KirtanSleepTimer timer = KirtanSleepTimer.at(
        DateTime(2026, 1, 1, 21, 30),
      );
      expect(timer.isActive, isTrue);
      expect(
        timer.remaining(DateTime(2026, 1, 1, 21)),
        const Duration(minutes: 30),
      );
      expect(timer.remaining(DateTime(2026, 1, 1, 22)), Duration.zero);
    });

    test('has value equality', () {
      expect(const KirtanSleepTimer.off(), const KirtanSleepTimer.off());
      expect(
        KirtanSleepTimer.at(DateTime(2026)),
        KirtanSleepTimer.at(DateTime(2026)),
      );
    });
  });
}
