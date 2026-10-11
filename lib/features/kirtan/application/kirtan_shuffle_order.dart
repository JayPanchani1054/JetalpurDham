import 'package:just_audio/just_audio.dart';

/// A shuffle order that always starts with the kirtan at [first].
///
/// When a new playlist is set, just_audio inserts every index at a random
/// position. With shuffle on, the starting kirtan could then land anywhere in
/// the order, and only the kirtans after it would play before the queue ends.
/// Moving it to the front makes "Shuffle" play every kirtan exactly once.
class KirtanShuffleOrder extends DefaultShuffleOrder {
  KirtanShuffleOrder({required this.first, super.random});

  /// Queue index of the kirtan that plays first.
  final int first;

  @override
  void insert(int index, int count) {
    super.insert(index, count);
    final int position = indices.indexOf(first);
    if (position > 0) {
      indices
        ..removeAt(position)
        ..insert(0, first);
    }
  }
}
