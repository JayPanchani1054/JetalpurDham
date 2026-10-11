import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/utils/app_logger.dart';
import 'kirtan_player_controller.dart';
import 'kirtan_player_state.dart';

/// Sleep timer: pauses after a number of minutes or at the end of the current
/// kirtan. The volume fades out over a few seconds so the stop is gentle.
final NotifierProvider<KirtanSleepTimerController, KirtanSleepTimer>
kirtanSleepTimerProvider =
    NotifierProvider<KirtanSleepTimerController, KirtanSleepTimer>(
      KirtanSleepTimerController.new,
    );

class KirtanSleepTimerController extends Notifier<KirtanSleepTimer> {
  static const Duration _fadeDuration = Duration(seconds: 6);
  static const int _fadeSteps = 24;

  Timer? _timer;
  Timer? _fadeTimer;
  StreamSubscription<PositionDiscontinuity>? _advanceSub;
  StreamSubscription<ProcessingState>? _completedSub;
  double? _volumeToRestore;

  AudioPlayer get _player => ref.read(kirtanAudioPlayerProvider);

  @override
  KirtanSleepTimer build() {
    ref.onDispose(_cancelAll);
    return const KirtanSleepTimer.off();
  }

  /// Pauses playback after [duration].
  void startFor(Duration duration) {
    _cancelAll();
    _timer = Timer(duration - _fadeDuration, _fadeOutAndPause);
    state = KirtanSleepTimer.at(DateTime.now().add(duration));
  }

  /// Pauses when the current kirtan finishes.
  void stopAtEndOfKirtan() {
    _cancelAll();
    final AudioPlayer player = _player;
    _advanceSub = player.positionDiscontinuityStream
        .where(
          (PositionDiscontinuity d) =>
              d.reason == PositionDiscontinuityReason.autoAdvance &&
              // just_audio also reports "auto-advance" when a newly tapped
              // queue replaces the old one; that kirtan must keep playing
              // (the timer then applies to it).
              !ref.read(kirtanPlayerProvider.notifier).changedKirtanRecently,
        )
        .listen((_) => unawaited(_pauseNow(rewind: true)));
    _completedSub = player.processingStateStream
        .where((ProcessingState s) => s == ProcessingState.completed)
        .listen((_) => cancel());
    state = const KirtanSleepTimer.endOfKirtan();
  }

  void cancel() {
    _cancelAll();
    if (ref.mounted) state = const KirtanSleepTimer.off();
  }

  void _fadeOutAndPause() {
    final AudioPlayer player = _player;
    if (!player.playing) {
      // A tapped kirtan that is still loading must not start afterwards.
      if (ref.read(kirtanPlayerProvider).isStarting) {
        unawaited(_pauseNow());
      } else {
        cancel();
      }
      return;
    }
    final double startVolume = player.volume;
    _volumeToRestore = startVolume;
    int step = 0;
    _fadeTimer = Timer.periodic(
      Duration(milliseconds: _fadeDuration.inMilliseconds ~/ _fadeSteps),
      (Timer timer) {
        step++;
        if (step >= _fadeSteps) {
          timer.cancel();
          unawaited(_pauseNow());
          return;
        }
        unawaited(
          player
              .setVolume(startVolume * (1 - step / _fadeSteps))
              .catchError((Object _) {}),
        );
      },
    );
  }

  Future<void> _pauseNow({bool rewind = false}) async {
    final double? restore = _volumeToRestore;
    _volumeToRestore = null;
    _cancelAll();
    if (!ref.mounted) return;
    state = const KirtanSleepTimer.off();
    final AudioPlayer player = _player;
    try {
      // Through the controller, so a kirtan that is still loading is kept
      // from starting too.
      await ref.read(kirtanPlayerProvider.notifier).pause();
      // The next kirtan has just started: keep it at the beginning.
      if (rewind) await player.seek(Duration.zero);
      if (restore != null) await player.setVolume(restore);
    } catch (error, stack) {
      AppLogger.error('Sleep timer could not pause', error, stack);
    }
  }

  void _cancelAll() {
    _timer?.cancel();
    _timer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    unawaited(_advanceSub?.cancel());
    _advanceSub = null;
    unawaited(_completedSub?.cancel());
    _completedSub = null;
    // Cancelled in the middle of a fade: bring the volume back.
    final double? restore = _volumeToRestore;
    _volumeToRestore = null;
    if (restore != null && ref.mounted) {
      unawaited(_player.setVolume(restore).catchError((Object _) {}));
    }
  }
}
