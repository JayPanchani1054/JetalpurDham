import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';

/// Initialises background audio playback (lock-screen / notification
/// controls) and the audio session. Awaited once in bootstrap before runApp.
/// Never throws: without it kirtans still play, just without background
/// controls.
Future<void> initKirtanAudio() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.jetalpurdham.app.audio',
      androidNotificationChannelName: 'Kirtan',
      androidNotificationChannelDescription: 'Kirtan playback controls',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_notification',
      notificationColor: AppColors.saffron,
      // Lock-screen artwork is decoded at a modest size to save memory.
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    );
  } catch (error, stack) {
    AppLogger.error('Background audio initialisation failed', error, stack);
  }
  try {
    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (error, stack) {
    AppLogger.error('Audio session configuration failed', error, stack);
  }
}
