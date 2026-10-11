import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../firebase/media_url.dart';
import '../utils/app_logger.dart';

/// Folders (under the app documents directory) that hold offline files.
abstract final class DownloadFolders {
  static const String kirtans = 'kirtans';
  static const String books = 'books';
}

/// Low-level file downloader used by the kirtan and shastra features.
///
/// Files are written to `<name>.part` first and renamed when complete, so a
/// half-downloaded file is never mistaken for a finished one.
class DownloadService {
  DownloadService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 5),
            ),
          );

  final Dio _dio;
  Directory? _root;

  Future<Directory> _rootDir() async =>
      _root ??= await getApplicationDocumentsDirectory();

  /// Directory for [folder], created on demand.
  Future<Directory> directory(String folder) async {
    final Directory dir = Directory(p.join((await _rootDir()).path, folder));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Deterministic local file for an item, e.g. `kirtans/<id>.mp3`.
  Future<File> fileFor(String folder, String id, String extension) async {
    final String safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final String ext = extension.startsWith('.') ? extension : '.$extension';
    return File(p.join((await directory(folder)).path, '$safeId$ext'));
  }

  /// Downloads [url] into [target]. [onProgress] reports 0..1 (or -1 when the
  /// server does not send a content length). Throws on failure/cancel.
  Future<File> download({
    required String url,
    required File target,
    CancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    final File partial = File('${target.path}.part');
    try {
      await _dio.download(
        url,
        partial.path,
        cancelToken: cancelToken,
        onReceiveProgress: (int received, int total) {
          onProgress?.call(total > 0 ? received / total : -1);
        },
      );
      if (target.existsSync()) await target.delete();
      return await partial.rename(target.path);
    } catch (error, stack) {
      if (partial.existsSync()) {
        await partial.delete().catchError((Object _) => partial);
      }
      if (!(error is DioException && CancelToken.isCancel(error))) {
        AppLogger.error('Download failed: $url', error, stack);
      }
      rethrow;
    }
  }

  /// Total bytes used by finished files in [folder].
  Future<int> folderSize(String folder) async {
    final Directory dir = await directory(folder);
    int total = 0;
    await for (final FileSystemEntity entity in dir.list(recursive: true)) {
      if (entity is File && !entity.path.endsWith('.part')) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Deletes every file in [folder].
  Future<void> clearFolder(String folder) async {
    final Directory dir = await directory(folder);
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
  }
}

final Provider<DownloadService> downloadServiceProvider =
    Provider<DownloadService>((Ref ref) => DownloadService());

enum DownloadStatus { notDownloaded, downloading, downloaded, failed }

/// State of one downloadable item.
class DownloadState {
  const DownloadState(this.status, {this.progress = 0});

  static const DownloadState none = DownloadState(DownloadStatus.notDownloaded);

  final DownloadStatus status;

  /// 0..1 while downloading; -1 when the total size is unknown.
  final double progress;

  bool get isDownloaded => status == DownloadStatus.downloaded;
  bool get isDownloading => status == DownloadStatus.downloading;
}

/// Identifies an offline file: `folder/id.extension`.
class DownloadKey {
  const DownloadKey({
    required this.folder,
    required this.id,
    required this.extension,
  });

  final String folder;
  final String id;
  final String extension;

  @override
  bool operator ==(Object other) =>
      other is DownloadKey &&
      other.folder == folder &&
      other.id == id &&
      other.extension == extension;

  @override
  int get hashCode => Object.hash(folder, id, extension);

  @override
  String toString() => '$folder/$id$extension';
}

/// Tracks download progress for every item, keyed by [DownloadKey].
///
/// The file system is the source of truth: an item is "downloaded" when its
/// final file exists. Call [refresh] to sync after external changes.
final NotifierProvider<DownloadManager, Map<DownloadKey, DownloadState>>
downloadManagerProvider =
    NotifierProvider<DownloadManager, Map<DownloadKey, DownloadState>>(
      DownloadManager.new,
    );

class DownloadManager extends Notifier<Map<DownloadKey, DownloadState>> {
  final Map<DownloadKey, CancelToken> _tokens = <DownloadKey, CancelToken>{};

  DownloadService get _service => ref.read(downloadServiceProvider);

  @override
  Map<DownloadKey, DownloadState> build() {
    ref.onDispose(() {
      for (final CancelToken token in _tokens.values) {
        token.cancel();
      }
    });
    return const <DownloadKey, DownloadState>{};
  }

  void _set(DownloadKey key, DownloadState value) {
    state = <DownloadKey, DownloadState>{...state, key: value};
  }

  Future<File> fileFor(DownloadKey key) =>
      _service.fileFor(key.folder, key.id, key.extension);

  /// Returns the local file when it has been fully downloaded, else null.
  Future<File?> localFile(DownloadKey key) async {
    final File file = await fileFor(key);
    final bool exists = file.existsSync();
    final DownloadState current = state[key] ?? DownloadState.none;
    if (!current.isDownloading) {
      final DownloadStatus status = exists
          ? DownloadStatus.downloaded
          : DownloadStatus.notDownloaded;
      if (current.status != status) _set(key, DownloadState(status));
    }
    return exists ? file : null;
  }

  /// Checks the file system for each key and updates the state.
  Future<void> refresh(Iterable<DownloadKey> keys) async {
    for (final DownloadKey key in keys) {
      await localFile(key);
    }
  }

  /// Starts (or joins) a download. Returns the file, or null if it failed or
  /// was cancelled. [source] may be any media reference (https, gs://, path).
  Future<File?> download(DownloadKey key, String source) async {
    if (_tokens.containsKey(key) || (state[key]?.isDownloading ?? false)) {
      return null;
    }
    final CancelToken token = CancelToken();
    _tokens[key] = token;
    try {
      final File? existing = await localFile(key);
      if (existing != null) return existing;
      _set(key, const DownloadState(DownloadStatus.downloading));
      final String url = await ref
          .read(mediaUrlResolverProvider)
          .resolve(source);
      double lastReported = 0;
      final File file = await _service.download(
        url: url,
        target: await fileFor(key),
        cancelToken: token,
        onProgress: (double progress) {
          // Throttle rebuilds to ~1% steps for smooth, cheap progress UI.
          if (progress < 0 ||
              progress - lastReported >= 0.01 ||
              progress >= 1) {
            lastReported = progress;
            _set(
              key,
              DownloadState(DownloadStatus.downloading, progress: progress),
            );
          }
        },
      );
      _set(key, const DownloadState(DownloadStatus.downloaded, progress: 1));
      return file;
    } catch (_) {
      _set(
        key,
        token.isCancelled
            ? DownloadState.none
            : const DownloadState(DownloadStatus.failed),
      );
      return null;
    } finally {
      _tokens.remove(key);
    }
  }

  void cancel(DownloadKey key) => _tokens[key]?.cancel();

  Future<void> delete(DownloadKey key) async {
    cancel(key);
    final File file = await fileFor(key);
    if (file.existsSync()) await file.delete();
    _set(key, DownloadState.none);
  }

  /// Removes every file in [folder] and resets matching states.
  Future<void> clearFolder(String folder) async {
    for (final MapEntry<DownloadKey, CancelToken> entry in _tokens.entries) {
      if (entry.key.folder == folder) entry.value.cancel();
    }
    await _service.clearFolder(folder);
    state = <DownloadKey, DownloadState>{
      for (final MapEntry<DownloadKey, DownloadState> e in state.entries)
        if (e.key.folder != folder) e.key: e.value,
    };
  }
}

/// Convenience: the state of a single item (rebuilds only when it changes).
final ProviderFamily<DownloadState, DownloadKey> downloadStateProvider =
    Provider.family<DownloadState, DownloadKey>(
      (Ref ref, DownloadKey key) => ref.watch(
        downloadManagerProvider.select(
          (Map<DownloadKey, DownloadState> s) => s[key] ?? DownloadState.none,
        ),
      ),
    );
