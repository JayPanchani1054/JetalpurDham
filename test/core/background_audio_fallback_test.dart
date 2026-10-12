import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_audio_init.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// Stands in for just_audio's native player (ExoPlayer / AVPlayer).
class _FakePlatform extends JustAudioPlatform {
  final List<String> initIds = <String>[];

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    initIds.add(request.id);
    return _FakePlayer(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async => DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
}

class _FakePlayer extends AudioPlayerPlatform {
  _FakePlayer(super.id);

  final StreamController<PlaybackEventMessage> _events =
      StreamController<PlaybackEventMessage>.broadcast();

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    const Duration duration = Duration(minutes: 5);
    _events.add(
      PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updateTime: DateTime.now(),
        updatePosition: Duration.zero,
        bufferedPosition: duration,
        duration: duration,
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ),
    );
    return LoadResponse(duration: duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _events.close();
    return DisposeResponse();
  }
}

/// A background player whose service never started: refuses every kirtan.
class _BrokenPlatform extends JustAudioPlatform {
  int calls = 0;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    calls++;
    throw PlatformException(code: 'error', message: 'single player only');
  }
}

/// A player like the app's, without the audio session (no plugin in tests).
AudioPlayer _player() => AudioPlayer(
  handleInterruptions: false,
  handleAudioSessionActivation: false,
  androidApplyAudioAttributes: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('jd_audio_test');
    // audio_service creates its artwork cache before it reaches the
    // (missing) native side.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async => temp.path,
        );
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  late _FakePlatform plain;
  setUp(() => JustAudioPlatform.instance = plain = _FakePlatform());

  // Tests share the audio_service state of this isolate and run in order.

  test('just_audio_background replaces the player before audio_service '
      'starts', () async {
    // audio_service is a no-op on the test host, so this start succeeds.
    late final JustAudioPlatform swapped;
    final bool enabled = await enableBackgroundAudio(() {
      final Future<void> init = JustAudioBackground.init(
        androidNotificationChannelId: 'test.audio',
      );
      swapped = JustAudioPlatform.instance;
      return init;
    });

    expect(enabled, isTrue);
    expect(swapped, isNot(same(plain)));
    expect(JustAudioPlatform.instance, same(swapped));
  });

  test('a failed start puts back the plain player, so every kirtan still '
      'plays', () async {
    final _BrokenPlatform broken = _BrokenPlatform();
    final bool enabled = await enableBackgroundAudio(() async {
      // What JustAudioBackground.init does when audio_service fails.
      JustAudioPlatform.instance = broken;
      throw PlatformException(code: 'error', message: 'service not bound');
    });

    expect(enabled, isFalse);
    expect(JustAudioPlatform.instance, same(plain));

    // Kirtan after kirtan gets a working player (just_audio asks the
    // platform for a new one after each stop).
    final AudioPlayer player = _player();
    addTearDown(player.dispose);
    expect(
      await player.setUrl('https://example.com/1.mp3'),
      const Duration(minutes: 5),
    );
    await player.stop();
    await player.setUrl('https://example.com/2.mp3');
    expect(plain.initIds, hasLength(2));
    expect(broken.calls, 0);
  });

  test('a start that hangs is rolled back after the time limit', () async {
    final Completer<void> never = Completer<void>();
    final bool enabled = await enableBackgroundAudio(() {
      JustAudioPlatform.instance = _BrokenPlatform();
      return never.future;
    }, timeout: const Duration(milliseconds: 50));

    expect(enabled, isFalse);
    expect(JustAudioPlatform.instance, same(plain));
  });

  test('initKirtanAudio never throws, runs once, and rolls back a real '
      'failure', () async {
    // audio_service can be started only once per app (it asserts in debug
    // builds). Make sure it has started, also when this test runs alone, so
    // the real JustAudioBackground.init below fails after it has already
    // replaced the player.
    await enableBackgroundAudio(
      () => JustAudioBackground.init(androidNotificationChannelId: 'test.x'),
    );
    JustAudioPlatform.instance = plain;

    final Future<void> first = initKirtanAudio();
    expect(initKirtanAudio(), same(first));
    await first;
    await kirtanAudioReady;

    expect(kirtanBackgroundAudioEnabled, isFalse);
    expect(JustAudioPlatform.instance, same(plain));
  });
}
