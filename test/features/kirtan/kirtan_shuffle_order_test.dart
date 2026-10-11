import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_shuffle_order.dart';

void main() {
  group('KirtanShuffleOrder', () {
    test('a new playlist starts with the chosen kirtan', () {
      for (int seed = 0; seed < 50; seed++) {
        final int first = seed % 12;
        // Exactly what just_audio does when a playlist is set.
        final KirtanShuffleOrder order =
            KirtanShuffleOrder(first: first, random: Random(seed))
              ..clear()
              ..insert(0, 12);
        expect(order.indices.first, first, reason: 'seed $seed');
        // Every kirtan plays exactly once.
        expect(order.indices.toSet(), <int>{for (int i = 0; i < 12; i++) i});
        expect(order.indices, hasLength(12));
      }
    });

    test('still shuffles the rest', () {
      final Set<String> orders = <String>{
        for (int seed = 0; seed < 20; seed++)
          (KirtanShuffleOrder(
            first: 0,
            random: Random(seed),
          )..insert(0, 8)).indices.join(','),
      };
      expect(orders.length, greaterThan(1));
    });

    test('re-shuffling keeps the playing kirtan first', () {
      final KirtanShuffleOrder order =
          KirtanShuffleOrder(first: 2, random: Random(1))
            ..insert(0, 6)
            ..shuffle(initialIndex: 4);
      expect(order.indices.first, 4);
      expect(order.indices.toSet(), <int>{0, 1, 2, 3, 4, 5});
    });

    test('works with a single kirtan and an out-of-range start', () {
      expect((KirtanShuffleOrder(first: 0)..insert(0, 1)).indices, <int>[0]);
      final KirtanShuffleOrder order = KirtanShuffleOrder(first: 9)
        ..insert(0, 3);
      expect(order.indices.toSet(), <int>{0, 1, 2});
    });
  });
}
