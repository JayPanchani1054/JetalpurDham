// just_audio marks LockCachingAudioSource (cache-while-streaming) as
// experimental; it is used deliberately, only in this file, with a fallback to
// direct streaming when it cannot be used.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/firebase/media_url.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/kirtan.dart';
import '../domain/kirtan_queries.dart';
import 'kirtan_downloads_controller.dart';
import 'kirtan_player_state.dart';
import 'kirtan_stream_cache.dart';

/// Bundled image of Shree Revati Baldevji Harikrushna Maharaj, used as the
/// artwork of kirtans without a cover (in the app and on the lock screen).
const String kKirtanFallbackArtAsset = 'assets/images/murti.jpg';

/// The single app-wide audio player (just_audio_background supports exactly
/// one). Tuned to start quickly and to buffer far ahead, so the next kirtan
/// is preloaded while the current one plays.
final Provider<AudioPlayer> kirtanAudioPlayerProvider = Provider<AudioPlayer>((
  Ref ref,
) {
  final AudioPlayer player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 60),
        maxBufferDuration: Duration(minutes: 10),
        bufferForPlaybackDuration: Duration(milliseconds: 1000),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 3),
        backBufferDuration: Duration(seconds: 30),
      ),
    ),
  );
  ref.onDispose(() => unawaited(player.dispose().catchError((Object _) {})));
  return player;
});

/// Queue + playback actions. UI widgets watch the narrow providers below.
final NotifierProvider<KirtanPlayerController, KirtanQueue>
kirtanPlayerProvider = NotifierProvider<KirtanPlayerController, KirtanQueue>(
  KirtanPlayerController.new,
);

/// The kirtan currently loaded (playing or paused), or null.
final Provider<Kirtan?> currentKirtanProvider = Provider<Kirtan?>(
  (Ref ref) =>
      ref.watch(kirtanPlayerProvider.select((KirtanQueue q) => q.current)),
);

final StreamProvider<PlayerState> kirtanPlayerStateProvider =
    StreamProvider<PlayerState>(
      (Ref ref) => ref.watch(kirtanAudioPlayerProvider).playerStateStream,
    );

/// True while playback is requested (also while buffering).
final Provider<bool> kirtanIsPlayingProvider = Provider<bool>(
  (Ref ref) => ref.watch(
    kirtanPlayerStateProvider.select(
      (AsyncValue<PlayerState> s) => s.value?.playing ?? false,
    ),
  ),
);

/// True while the current kirtan is being prepared, or is buffering while
/// playback is requested (shown as a spinner on the play button).
final Provider<bool> kirtanIsLoadingProvider = Provider<bool>((Ref ref) {
  final bool preparing = ref.watch(
    kirtanPlayerProvider.select((KirtanQueue q) => q.isPreparing),
  );
  final bool buffering = ref.watch(
    kirtanPlayerStateProvider.select((AsyncValue<PlayerState> s) {
      final PlayerState? state = s.value;
      return state != null &&
          state.playing &&
          (state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering);
    }),
  );
  return preparing || buffering;
});

/// Position, buffered position and duration (rebuilds ~5×/s while playing,
/// so only progress widgets should watch it).
final StreamProvider<KirtanProgress> kirtanProgressProvider =
    StreamProvider<KirtanProgress>((Ref ref) {
      final AudioPlayer player = ref.watch(kirtanAudioPlayerProvider);
      return Rx.combineLatest3<Duration, Duration, Duration?, KirtanProgress>(
        player.positionStream,
        player.bufferedPositionStream,
        player.durationStream,
        (Duration position, Duration buffered, Duration? total) =>
            KirtanProgress(
              position: position,
              buffered: buffered,
              total: total ?? Duration.zero,
            ),
      ).distinct();
    });

final StreamProvider<LoopMode> kirtanLoopModeProvider =
    StreamProvider<LoopMode>(
      (Ref ref) => ref.watch(kirtanAudioPlayerProvider).loopModeStream,
    );

final StreamProvider<bool> kirtanShuffleProvider = StreamProvider<bool>(
  (Ref ref) => ref.watch(kirtanAudioPlayerProvider).shuffleModeEnabledStream,
);

final StreamProvider<double> kirtanSpeedProvider = StreamProvider<double>(
  (Ref ref) => ref.watch(kirtanAudioPlayerProvider).speedStream,
);

final StreamProvider<SequenceState> _sequenceStateProvider =
    StreamProvider<SequenceState>(
      (Ref ref) => ref.watch(kirtanAudioPlayerProvider).sequenceStateStream,
    );

/// Whether "next" can do anything (respects shuffle and repeat).
final Provider<bool> kirtanHasNextProvider = Provider<bool>((Ref ref) {
  ref.watch(_sequenceStateProvider);
  return ref.watch(kirtanAudioPlayerProvider).hasNext;
});

class KirtanPlayerController extends Notifier<KirtanQueue> {
  late AudioPlayer _player;
  StreamSubscription<SequenceState>? _sequenceSub;
  StreamSubscription<PlayerException>? _errorSub;
  StreamSubscription<ProcessingState>? _processingSub;

  int _generation = 0;
  int _loadedGeneration = -1;
  int _consecutiveErrors = 0;

  /// Cleared when the user taps pause while a queue is still loading.
  bool _autoplay = true;
  DateTime _lastErrorAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Cache-while-streaming needs just_audio's localhost proxy. If the platform
  /// blocks it (cleartext policy), playback falls back to direct streaming for
  /// the rest of the session.
  bool _streamCacheEnabled = true;
  bool _streamCacheVerified = false;

  /// One caching source per cache file, reused across queues so two
  /// downloads never write the same file.
  final Map<String, LockCachingAudioSource> _cachingSources =
      <String, LockCachingAudioSource>{};
  Future<Uri?>? _fallbackArt;

  @override
  KirtanQueue build() {
    _player = ref.watch(kirtanAudioPlayerProvider);
    _sequenceSub = _player.sequenceStateStream.listen(_onSequenceState);
    _errorSub = _player.errorStream.listen(_onPlayerError);
    _processingSub = _player.processingStateStream.listen(_onProcessingState);
    ref.onDispose(() {
      _sequenceSub?.cancel();
      _errorSub?.cancel();
      _processingSub?.cancel();
      _sequenceSub = null;
      _errorSub = null;
      _processingSub = null;
    });
    unawaited(ref.read(kirtanStreamCacheProvider).pruneOnce());
    return const KirtanQueue();
  }

  // ---------------------------------------------------------------------------
  // Public actions. None of them throw; failures are logged and surfaced via
  // [KirtanQueue.errorCount].

  /// Plays [kirtans] starting with the one at [startIndex] (a tapped row).
  Future<void> playKirtans(List<Kirtan> kirtans, {int startIndex = 0}) =>
      _load(kirtans, startIndex: startIndex, strict: true, shuffle: false);

  /// "Play all" / "Shuffle": starts at the top (or a random kirtan), skipping
  /// kirtans that cannot be played right now (e.g. offline).
  Future<void> playAll(List<Kirtan> kirtans, {bool shuffle = false}) {
    if (kirtans.isEmpty) return Future<void>.value();
    return _load(
      kirtans,
      startIndex: shuffle ? Random().nextInt(kirtans.length) : 0,
      strict: false,
      shuffle: shuffle,
    );
  }

  Future<void> togglePlayPause() async {
    if (state.isEmpty) return;
    if (state.isPreparing) {
      // Still loading: don't start once ready.
      _autoplay = false;
      return;
    }
    if (_player.playing &&
        _player.processingState != ProcessingState.completed) {
      return _guard('pause', _player.pause);
    }
    if (_needsReload) {
      await _load(
        state.items,
        startIndex: state.index ?? 0,
        strict: true,
        position: _player.processingState == ProcessingState.idle
            ? _player.position
            : null,
      );
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _guard('restart', () => _player.seek(Duration.zero));
    }
    _startPlayback();
  }

  Future<void> pause() => _guard('pause', _player.pause);

  Future<void> skipToNext() async {
    if (state.isPreparing) return;
    if (_needsReload) {
      final int next = (state.index ?? -1) + 1;
      if (next < state.items.length) {
        await _load(state.items, startIndex: next, strict: true);
      }
      return;
    }
    await _guard('next', _player.seekToNext);
  }

  /// Restarts the kirtan when more than 3 s in (or when there is no previous
  /// one), otherwise goes to the previous kirtan.
  Future<void> skipToPrevious() async {
    if (state.isPreparing) return;
    if (_needsReload) {
      final int current = state.index ?? 0;
      await _load(
        state.items,
        startIndex: current > 0 ? current - 1 : 0,
        strict: true,
      );
      return;
    }
    await _guard('previous', () async {
      if (_player.position > const Duration(seconds: 3) ||
          !_player.hasPrevious) {
        await _player.seek(Duration.zero);
      } else {
        await _player.seekToPrevious();
      }
    });
  }

  /// Jumps to an item of the current queue.
  Future<void> skipToIndex(int index) async {
    if (state.isPreparing || index < 0 || index >= state.items.length) return;
    if (_needsReload) {
      await _load(state.items, startIndex: index, strict: true);
      return;
    }
    await _guard('skip', () => _player.seek(Duration.zero, index: index));
    _startPlayback();
  }

  Future<void> seek(Duration position) =>
      _guard('seek', () => _player.seek(position));

  Future<void> toggleShuffle() => _guard('shuffle', () async {
    final bool enable = !_player.shuffleModeEnabled;
    // A fresh order that keeps the current kirtan playing first.
    if (enable) await _player.shuffle();
    await _player.setShuffleModeEnabled(enable);
  });

  /// Off → all → one → off.
  Future<void> cycleRepeat() => _guard('repeat', () {
    final LoopMode next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    return _player.setLoopMode(next);
  });

  Future<void> setSpeed(double speed) =>
      _guard('speed', () => _player.setSpeed(speed.clamp(0.5, 2.0)));

  /// Stops playback and clears the queue (hides the mini player).
  Future<void> stop() async {
    _generation++;
    state = KirtanQueue(errorCount: state.errorCount);
    await _guard('stop', _player.stop);
  }

  /// Queue indices in play order (respecting shuffle), starting with the
  /// current kirtan. Used by the "Up next" sheet.
  List<int> upcomingOrder() {
    final int? current = state.index;
    if (current == null) return const <int>[];
    List<int> order = const <int>[];
    try {
      order = _player.effectiveIndices;
    } catch (_) {
      // Nothing loaded yet: fall back to the queue order.
    }
    if (order.length != state.items.length) {
      order = List<int>.generate(state.items.length, (int i) => i);
    }
    return upcomingQueueOrder(
      order,
      current,
      wrap: _player.loopMode == LoopMode.all,
    );
  }

  // ---------------------------------------------------------------------------
  // Loading.

  bool get _needsReload =>
      _loadedGeneration != _generation ||
      _player.processingState == ProcessingState.idle;

  bool _isCurrent(int generation) => generation == _generation && ref.mounted;

  /// Builds the playlist for [kirtans] and starts playing. Returns whether
  /// playback started.
  Future<bool> _load(
    List<Kirtan> kirtans, {
    required int startIndex,
    required bool strict,
    bool? shuffle,
    Duration? position,
    bool allowDirectRetry = true,
  }) async {
    final List<Kirtan> requested = List<Kirtan>.unmodifiable(kirtans);
    if (requested.isEmpty) return false;
    final int start = startIndex.clamp(0, requested.length - 1);
    final int generation = ++_generation;
    // Show the tapped kirtan immediately; loading continues behind it. The
    // previous kirtan stops now so the sound always matches the title shown.
    state = KirtanQueue(
      items: requested,
      index: start,
      isPreparing: true,
      errorCount: state.errorCount,
    );
    if (allowDirectRetry) _autoplay = true;
    if (_player.playing) await _guard('pause previous', _player.pause);

    bool startUsesProxy = false;
    try {
      final bool offline = !(ref.read(isOnlineProvider).value ?? true);
      await ref.read(kirtanStreamCacheProvider).pruneOnce();
      final _TagBuilder tags = await _tagBuilder();
      final List<AudioSource?> sources = await Future.wait(
        requested.map(
          (Kirtan k) => _sourceFor(k, tags: tags, offline: offline),
        ),
      );
      if (!_isCurrent(generation)) return false;

      final List<Kirtan> items = <Kirtan>[];
      final List<AudioSource> playable = <AudioSource>[];
      for (int i = 0; i < requested.length; i++) {
        final AudioSource? source = sources[i];
        if (source != null) {
          items.add(requested[i]);
          playable.add(source);
        }
      }
      final int? index = resolveStartIndex(
        original: requested,
        startIndex: start,
        playable: items,
        strict: strict,
      );
      if (index == null) {
        _failLoad(generation);
        return false;
      }
      startUsesProxy = playable[index] is LockCachingAudioSource;
      state = KirtanQueue(
        items: List<Kirtan>.unmodifiable(items),
        index: index,
        isPreparing: true,
        errorCount: state.errorCount,
      );
      if (shuffle != null) await _player.setShuffleModeEnabled(shuffle);
      await _player.setAudioSources(
        playable,
        initialIndex: index,
        initialPosition: position ?? Duration.zero,
      );
      if (!_isCurrent(generation)) return false;
      _loadedGeneration = generation;
      _consecutiveErrors = 0;
      state = state.copyWith(isPreparing: false);
      _markPlayed();
      if (_autoplay) _startPlayback();
      return true;
    } on PlayerInterruptedException {
      // Replaced by a newer request.
      return false;
    } catch (error, stack) {
      if (!_isCurrent(generation)) return false;
      AppLogger.error('Kirtan playback could not start', error, stack);
      if (allowDirectRetry &&
          startUsesProxy &&
          _streamCacheEnabled &&
          !_streamCacheVerified) {
        return _retryWithoutStreamCache(
          requested,
          startIndex: start,
          strict: strict,
          shuffle: shuffle,
          position: position,
        );
      }
      _failLoad(generation);
      return false;
    }
  }

  Future<bool> _retryWithoutStreamCache(
    List<Kirtan> kirtans, {
    required int startIndex,
    required bool strict,
    bool? shuffle,
    Duration? position,
  }) async {
    _streamCacheEnabled = false;
    final bool started = await _load(
      kirtans,
      startIndex: startIndex,
      strict: strict,
      shuffle: shuffle,
      position: position,
      allowDirectRetry: false,
    );
    // Direct streaming failed too: a network problem, not the proxy.
    if (!started) _streamCacheEnabled = true;
    return started;
  }

  void _failLoad(int generation) {
    if (!_isCurrent(generation)) return;
    state = state.copyWith(isPreparing: false);
    _reportError();
  }

  void _startPlayback() {
    unawaited(
      _player.play().catchError((Object error, StackTrace stack) {
        AppLogger.error('Kirtan play failed', error, stack);
      }),
    );
  }

  /// Best available source: downloaded file → fully cached stream → stream
  /// while caching. Null when the kirtan can't be played right now.
  Future<AudioSource?> _sourceFor(
    Kirtan kirtan, {
    required _TagBuilder tags,
    required bool offline,
  }) async {
    try {
      final File? local = await ref
          .read(kirtanDownloadsProvider.notifier)
          .localFileFor(kirtan);
      if (local != null) {
        return AudioSource.file(local.path, tag: tags.build(kirtan));
      }
      final KirtanStreamCache cache = ref.read(kirtanStreamCacheProvider);
      final File? cached = await cache.completedFileFor(kirtan);
      if (cached != null) {
        return AudioSource.file(cached.path, tag: tags.build(kirtan));
      }
      if (offline) return null;

      final String cacheKey = kirtanCacheFileName(kirtan);
      final LockCachingAudioSource? caching = _cachingSources[cacheKey];
      // Reuse the source that may still be filling this cache file.
      if (caching != null && _streamCacheEnabled) return caching;

      final String url = await ref
          .read(mediaUrlResolverProvider)
          .resolve(kirtan.audioUrl)
          .timeout(const Duration(seconds: 12));
      final Uri? uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      if (!_streamCacheEnabled) {
        return AudioSource.uri(uri, tag: tags.build(kirtan));
      }
      final LockCachingAudioSource source = LockCachingAudioSource(
        uri,
        cacheFile: await cache.fileFor(kirtan),
        tag: tags.build(kirtan),
      );
      _cachingSources[cacheKey] = source;
      return source;
    } catch (error, stack) {
      AppLogger.error('Kirtan ${kirtan.id} unavailable', error, stack);
      return null;
    }
  }

  /// Lock-screen metadata in the app language, with the https cover (or the
  /// murti image) as artwork.
  Future<_TagBuilder> _tagBuilder() async {
    final String code = ref.read(languageProvider).code;
    String album = '';
    try {
      album = lookupAppLocalizations(Locale(code)).templeShortName;
    } catch (_) {
      // Unsupported locale: leave the album empty.
    }
    return _TagBuilder(
      languageCode: code,
      album: album,
      fallbackArt: await (_fallbackArt ??= _writeFallbackArt()),
    );
  }

  Future<Uri?> _writeFallbackArt() async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      final File file = File(p.join(dir.path, 'kirtan_art', 'murti.jpg'));
      if (!await file.exists()) {
        final ByteData data = await rootBundle.load(kKirtanFallbackArtAsset);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      return Uri.file(file.path);
    } catch (error, stack) {
      AppLogger.error('Kirtan fallback artwork unavailable', error, stack);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Player events.

  void _onSequenceState(SequenceState sequence) {
    if (state.isPreparing) return;
    final Object? tag = sequence.currentSource?.tag;
    if (tag is! MediaItem) return;
    final int index = state.indexOfId(tag.id);
    if (index >= 0 && index != state.index) {
      state = state.copyWith(index: index);
      _markPlayed();
    }
  }

  void _markPlayed() {
    final Kirtan? current = state.current;
    if (current == null) return;
    unawaited(ref.read(kirtanStreamCacheProvider).markPlayed(current));
  }

  void _onProcessingState(ProcessingState processing) {
    switch (processing) {
      case ProcessingState.ready:
        _consecutiveErrors = 0;
        final int? index = _player.currentIndex;
        final List<IndexedAudioSource> sequence = _player.sequence;
        if (index != null &&
            index < sequence.length &&
            sequence[index] is LockCachingAudioSource) {
          _streamCacheVerified = true;
        }
      case ProcessingState.completed:
        // End of the queue: rewind to its first kirtan, paused.
        if (_loadedGeneration == _generation && !state.isPreparing) {
          unawaited(
            _guard('completed', () async {
              await _player.pause();
              final List<int> order = _player.effectiveIndices;
              await _player.seek(
                Duration.zero,
                index: order.isEmpty ? 0 : order.first,
              );
            }),
          );
        }
      case ProcessingState.idle:
      case ProcessingState.loading:
      case ProcessingState.buffering:
        break;
    }
  }

  void _onPlayerError(PlayerException error) {
    AppLogger.error('Kirtan playback error', error);
    // Errors while a queue loads are handled by [_load].
    if (state.isPreparing || _loadedGeneration != _generation) return;
    final int? index = error.index ?? _player.currentIndex;
    final List<IndexedAudioSource> sequence = _player.sequence;
    if (index != null &&
        index >= 0 &&
        index < sequence.length &&
        index < state.items.length &&
        sequence[index] is LockCachingAudioSource &&
        _streamCacheEnabled &&
        !_streamCacheVerified) {
      unawaited(
        _retryWithoutStreamCache(
          state.items,
          startIndex: index,
          strict: true,
          position: _player.position,
        ),
      );
      return;
    }
    _reportError();
    if (_consecutiveErrors < 3 && _player.hasNext) {
      _consecutiveErrors++;
      unawaited(_guard('skip after error', _player.seekToNext));
    } else {
      _consecutiveErrors = 0;
      unawaited(_guard('pause after error', _player.pause));
    }
  }

  void _reportError() {
    final DateTime now = DateTime.now();
    // One failure can surface twice (load error + error event).
    if (now.difference(_lastErrorAt) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastErrorAt = now;
    if (ref.mounted) state = state.copyWith(errorCount: state.errorCount + 1);
  }

  Future<void> _guard(String action, Future<void> Function() body) async {
    try {
      await body();
    } on PlayerInterruptedException {
      // Superseded by another action.
    } catch (error, stack) {
      AppLogger.error('Kirtan $action failed', error, stack);
    }
  }
}

/// Builds [MediaItem] tags for one queue (shared language, album, artwork).
class _TagBuilder {
  const _TagBuilder({
    required this.languageCode,
    required this.album,
    required this.fallbackArt,
  });

  final String languageCode;
  final String album;
  final Uri? fallbackArt;

  MediaItem build(Kirtan kirtan) {
    final String artist = kirtan.artist.resolve(languageCode);
    final String? cover = kirtan.coverUrl;
    final Uri? coverUri = cover != null && cover.startsWith('https://')
        ? Uri.tryParse(cover)
        : null;
    return MediaItem(
      id: kirtan.id,
      title: kirtan.title.resolve(languageCode),
      artist: artist.isEmpty ? null : artist,
      album: album.isEmpty ? null : album,
      duration: kirtan.duration,
      artUri: coverUri ?? fallbackArt,
    );
  }
}
