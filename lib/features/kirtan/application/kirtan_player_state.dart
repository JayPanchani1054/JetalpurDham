import 'package:flutter/foundation.dart';

import '../domain/kirtan.dart';

/// The queue the player is working on and which item is current.
///
/// [items] are aligned with the player's sequence (same order, same length),
/// so [index] is also the player's sequence index.
@immutable
class KirtanQueue {
  const KirtanQueue({
    this.items = const <Kirtan>[],
    this.index,
    this.isPreparing = false,
    this.errorCount = 0,
  });

  final List<Kirtan> items;
  final int? index;

  /// True while URLs are resolved and the first kirtan is loading.
  final bool isPreparing;

  /// Incremented on every playback error so the UI can show one message per
  /// failure.
  final int errorCount;

  bool get isEmpty => current == null;

  Kirtan? get current {
    final int? i = index;
    return i != null && i >= 0 && i < items.length ? items[i] : null;
  }

  int indexOfId(String kirtanId) =>
      items.indexWhere((Kirtan k) => k.id == kirtanId);

  KirtanQueue copyWith({
    List<Kirtan>? items,
    int? index,
    bool? isPreparing,
    int? errorCount,
  }) => KirtanQueue(
    items: items ?? this.items,
    index: index ?? this.index,
    isPreparing: isPreparing ?? this.isPreparing,
    errorCount: errorCount ?? this.errorCount,
  );
}

/// Position, buffered position and duration of the current kirtan.
@immutable
class KirtanProgress {
  const KirtanProgress({
    this.position = Duration.zero,
    this.buffered = Duration.zero,
    this.total = Duration.zero,
  });

  static const KirtanProgress zero = KirtanProgress();

  final Duration position;
  final Duration buffered;
  final Duration total;

  /// 0..1 for progress lines; 0 when the duration is unknown.
  double get fraction {
    if (total <= Duration.zero) return 0;
    return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is KirtanProgress &&
      other.position == position &&
      other.buffered == buffered &&
      other.total == total;

  @override
  int get hashCode => Object.hash(position, buffered, total);
}

/// Playback speeds offered to devotees (slower helps learning a kirtan).
const List<double> kKirtanSpeeds = <double>[0.75, 1.0, 1.25, 1.5];

/// Sleep timer choices in minutes.
const List<int> kSleepTimerMinutes = <int>[15, 30, 45, 60];

/// `1×`, `0.75×`, `1.25×`.
String formatKirtanSpeed(double speed) {
  final String text = speed == speed.roundToDouble()
      ? speed.toStringAsFixed(0)
      : speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  return '$text×';
}

/// Sleep timer state: off, a fixed end time, or "at the end of this kirtan".
@immutable
class KirtanSleepTimer {
  const KirtanSleepTimer.off() : endsAt = null, endOfKirtan = false;
  const KirtanSleepTimer.at(DateTime this.endsAt) : endOfKirtan = false;
  const KirtanSleepTimer.endOfKirtan() : endsAt = null, endOfKirtan = true;

  final DateTime? endsAt;
  final bool endOfKirtan;

  bool get isActive => endsAt != null || endOfKirtan;

  /// Time left, never negative; null unless a fixed end time is set.
  Duration? remaining(DateTime now) {
    final DateTime? end = endsAt;
    if (end == null) return null;
    final Duration left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  bool operator ==(Object other) =>
      other is KirtanSleepTimer &&
      other.endsAt == endsAt &&
      other.endOfKirtan == endOfKirtan;

  @override
  int get hashCode => Object.hash(endsAt, endOfKirtan);
}
