import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';

/// How long background audio (lock-screen / notification controls) may take
/// to start. After that, kirtans play without those controls this session.
const Duration kBackgroundAudioTimeout = Duration(seconds: 8);

/// Limit for configuring the audio session, which the player also waits for.
const Duration _sessionTimeout = Duration(seconds: 4);

Future<void>? _initialising;
bool _backgroundAudio = false;

/// Completes when [initKirtanAudio] has finished: background audio is ready,
/// or it failed and was rolled back. The kirtan player waits for this before
/// it loads a kirtan. Never throws, and completes at once if
/// [initKirtanAudio] was never called.
Future<void> get kirtanAudioReady => _initialising ?? Future<void>.value();

/// Whether kirtans have lock-screen and notification controls this session.
bool get kirtanBackgroundAudioEnabled => _backgroundAudio;

/// Sets up background audio playback (lock-screen and notification controls)
/// and the audio session. Started once at start-up without blocking the first
/// frame; later calls return the same future.
///
/// Never throws. If background audio fails or takes longer than
/// [kBackgroundAudioTimeout], kirtans still play, only without those controls.
Future<void> initKirtanAudio() => _initialising ??= _initialise();

Future<void> _initialise() async {
  _backgroundAudio = await enableBackgroundAudio(
    () => JustAudioBackground.init(
      androidNotificationChannelId: 'com.jetalpurdham.app.audio',
      androidNotificationChannelName: 'Kirtan',
      androidNotificationChannelDescription: 'Kirtan playback controls',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_notification',
      notificationColor: AppColors.saffron,
      // Lock-screen artwork is decoded at a modest size to save memory.
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    ),
  );
  try {
    final AudioSession session = await AudioSession.instance.timeout(
      _sessionTimeout,
    );
    await session
        .configure(const AudioSessionConfiguration.music())
        .timeout(_sessionTimeout);
  } catch (error, stack) {
    AppLogger.error('Audio session configuration failed', error, stack);
  }
}

/// Runs [init] (`JustAudioBackground.init`) and returns whether it finished
/// within [timeout].
///
/// `JustAudioBackground.init` switches just_audio to its background player
/// first, and only then starts audio_service. If audio_service fails or is
/// still starting, that player is unusable: the first kirtan fails, and every
/// later one is refused because it accepts a single player only. So on
/// failure or timeout the plain player is restored, and kirtans play in the
/// foreground for the rest of the session.
@visibleForTesting
Future<bool> enableBackgroundAudio(
  Future<void> Function() init, {
  Duration timeout = kBackgroundAudioTimeout,
}) async {
  final JustAudioPlatform plain = JustAudioPlatform.instance;
  try {
    await init().timeout(timeout);
    return true;
  } catch (error, stack) {
    JustAudioPlatform.instance = plain;
    AppLogger.error(
      'Background audio unavailable; kirtans play without lock-screen '
      'controls',
      error,
      stack,
    );
    return false;
  }
}
