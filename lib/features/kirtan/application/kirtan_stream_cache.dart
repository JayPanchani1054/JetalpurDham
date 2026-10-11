import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/kirtan.dart';

/// Disk cache filled while a kirtan streams (via just_audio's
/// `LockCachingAudioSource`), so any kirtan heard once replays instantly and
/// works without internet.
///
/// Lives in the app's cache directory, which the system may clear when
/// storage is low. Kept below [maxBytes] by removing the least recently played
/// files once per session.
class KirtanStreamCache {
  KirtanStreamCache({
    Future<Directory> Function()? rootDirectory,
    this.maxBytes = defaultMaxBytes,
    this.targetBytes = defaultTargetBytes,
  }) : _rootDirectory = rootDirectory ?? getApplicationCacheDirectory;

  static const int defaultMaxBytes = 600 * 1024 * 1024;
  static const int defaultTargetBytes = 400 * 1024 * 1024;

  /// Pruning starts above this size…
  final int maxBytes;

  /// …and removes least recently played files until below this one.
  final int targetBytes;

  final Future<Directory> Function() _rootDirectory;
  Future<Directory>? _dir;
  Future<void>? _pruned;

  Future<Directory> directory() => _dir ??= _createDirectory();

  Future<Directory> _createDirectory() async {
    final Directory dir = Directory(
      p.join((await _rootDirectory()).path, 'kirtan_stream_cache'),
    );
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Cache file for [kirtan] (may not exist yet).
  Future<File> fileFor(Kirtan kirtan) async =>
      File(p.join((await directory()).path, kirtanCacheFileName(kirtan)));

  /// The fully cached file for [kirtan], or null.
  Future<File?> completedFileFor(Kirtan kirtan) async {
    try {
      final File file = await fileFor(kirtan);
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  /// Marks the cached copy of [kirtan] (if any) as just played, so pruning
  /// removes the least recently played kirtans first. Never throws.
  Future<void> markPlayed(Kirtan kirtan) async {
    try {
      final File file = await fileFor(kirtan);
      if (await file.exists()) await file.setLastModified(DateTime.now());
    } catch (_) {
      // Best effort only.
    }
  }

  /// Trims the cache once per app session. Never throws.
  Future<void> pruneOnce() => _pruned ??= _prune();

  Future<void> _prune() async {
    try {
      final Directory dir = await directory();
      final DateTime now = DateTime.now();
      final List<_CacheEntry> entries = <_CacheEntry>[];
      final Set<String> paths = <String>{};
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File) paths.add(entity.path);
      }
      for (final String path in paths) {
        final FileStat stat = await FileStat.stat(path);
        if (path.endsWith('.part')) {
          // Left behind by an interrupted stream.
          if (now.difference(stat.modified) > const Duration(hours: 1)) {
            await _delete(path);
          }
        } else if (path.endsWith('.mime')) {
          final String audio = path.substring(0, path.length - 5);
          if (!paths.contains(audio) && !paths.contains('$audio.part')) {
            await _delete(path);
          }
        } else {
          entries.add(_CacheEntry(path, stat.size, stat.modified));
        }
      }
      int total = entries.fold<int>(
        0,
        (int sum, _CacheEntry e) => sum + e.size,
      );
      if (total <= maxBytes) return;
      entries.sort((_CacheEntry a, _CacheEntry b) => a.used.compareTo(b.used));
      for (final _CacheEntry entry in entries) {
        if (total <= targetBytes) break;
        await _delete(entry.path);
        await _delete('${entry.path}.mime');
        total -= entry.size;
      }
    } catch (error, stack) {
      AppLogger.error('Kirtan cache prune failed', error, stack);
    }
  }

  /// Total bytes used by the cache. Never throws.
  Future<int> size() async {
    try {
      int total = 0;
      await for (final FileSystemEntity entity in (await directory()).list()) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Deletes every cached kirtan (e.g. from Settings). Files that are still
  /// being written or played are skipped. Never throws.
  Future<void> clear() async {
    try {
      await for (final FileSystemEntity entity in (await directory()).list()) {
        if (entity is File && !entity.path.endsWith('.part')) {
          await _delete(entity.path);
        }
      }
    } catch (error, stack) {
      AppLogger.error('Kirtan cache clear failed', error, stack);
    }
  }

  Future<void> _delete(String path) async {
    try {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A file in use or already gone is fine.
    }
  }
}

class _CacheEntry {
  const _CacheEntry(this.path, this.size, this.used);

  final String path;
  final int size;
  final DateTime used;
}

final Provider<KirtanStreamCache> kirtanStreamCacheProvider =
    Provider<KirtanStreamCache>((Ref ref) => KirtanStreamCache());

/// Stable cache file name: the kirtan id plus a hash of its audio reference,
/// so replacing the audio in the console never replays a stale file.
String kirtanCacheFileName(Kirtan kirtan) {
  final String safeId = kirtan.id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
  final String hash = fnv1a32(kirtan.audioUrl)
      .toRadixString(16)
      .padLeft(8, '0');
  return '${safeId}_$hash${kirtanAudioExtension(kirtan.audioUrl)}';
}

/// 32-bit FNV-1a hash of the UTF-16 code units of [input]. Deterministic
/// across runs and platforms (unlike [String.hashCode]).
int fnv1a32(String input) {
  int hash = 0x811c9dc5;
  for (final int unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
