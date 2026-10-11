/// Initialises background audio playback (lock-screen / notification
/// controls) and the audio session. Awaited once in bootstrap before runApp.
/// Must never throw.
///
/// TODO(feature-agent): implement (JustAudioBackground.init + AudioSession).
Future<void> initKirtanAudio() async {}
