import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/download_service.dart';
import '../../../core/services/preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../data/kirtan_downloads_index.dart';
import '../domain/kirtan.dart';
import 'kirtan_stream_cache.dart';

/// Outcome of a download request, used for the confirmation snackbar.
enum KirtanDownloadResult { saved, failed, cancelled }

/// Offline index of downloaded kirtans (persisted in SharedPreferences) and
/// the actions that keep it in sync with the files on disk.
///
/// The index lets the Downloads screen and offline playback work without any
/// network or Firestore access. The file system stays the source of truth:
/// entries whose file disappeared (e.g. "Remove all" in Settings) are pruned.
final NotifierProvider<KirtanDownloadsController, KirtanDownloadsIndex>
kirtanDownloadsProvider =
    NotifierProvider<KirtanDownloadsController, KirtanDownloadsIndex>(
      KirtanDownloadsController.new,
    );

class KirtanDownloadsController extends Notifier<KirtanDownloadsIndex> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  DownloadManager get _manager => ref.read(downloadManagerProvider.notifier);

  bool _pruning = false;

  @override
  KirtanDownloadsIndex build() {
    final KirtanDownloadsIndex index = KirtanDownloadsIndex.decode(
      _prefs.getString(PrefKeys.kirtanDownloadsIndex),
    );
    // A kirtan file that was downloaded and is now gone (e.g. Settings →
    // "Remove all") must leave the index too.
    ref.listen<Map<DownloadKey, DownloadState>>(downloadManagerProvider, (
      Map<DownloadKey, DownloadState>? previous,
      Map<DownloadKey, DownloadState> next,
    ) {
      if (previous == null) return;
      for (final MapEntry<DownloadKey, DownloadState> e in previous.entries) {
        if (e.key.folder == DownloadFolders.kirtans &&
            e.value.isDownloaded &&
            !(next[e.key]?.isDownloaded ?? false)) {
          unawaited(prune());
          return;
        }
      }
    });
    // Sync download states and drop stale entries once the index is ready.
    unawaited(Future<void>.microtask(prune));
    return index;
  }

  /// The download key for [kirtan]: the extension recorded when it was
  /// downloaded, otherwise the one derived from its audio URL.
  DownloadKey keyFor(Kirtan kirtan) => kirtanDownloadKey(
    kirtan.id,
    state[kirtan.id]?.extension ?? kirtanAudioExtension(kirtan.audioUrl),
  );

  /// Downloads [kirtan] for offline listening. Reuses the streaming cache when
  /// the kirtan was already heard completely, so no data is spent twice.
  Future<KirtanDownloadResult> download(Kirtan kirtan) async {
    final DownloadKey key = keyFor(kirtan);
    File? file;
    try {
      file = await _importFromStreamCache(kirtan, key);
      file ??= await _manager.download(key, kirtan.audioUrl);
    } catch (error, stack) {
      // e.g. the storage folder is unavailable: report, never crash a tap.
      AppLogger.error('Kirtan download failed ${kirtan.id}', error, stack);
      return KirtanDownloadResult.failed;
    }
    if (!ref.mounted) return KirtanDownloadResult.failed;
    if (file == null) {
      final DownloadStatus status =
          (ref.read(downloadManagerProvider)[key] ?? DownloadState.none).status;
      return status == DownloadStatus.failed
          ? KirtanDownloadResult.failed
          : KirtanDownloadResult.cancelled;
    }
    int size = kirtan.sizeBytes ?? 0;
    try {
      size = await file.length();
    } catch (_) {
      // Keep the size from Firestore.
    }
    if (!ref.mounted) return KirtanDownloadResult.saved;
    _save(
      state.upsert(
        DownloadedKirtan(
          kirtan: kirtan,
          extension: key.extension,
          sizeBytes: size,
          downloadedAt: DateTime.now(),
        ),
      ),
    );
    return KirtanDownloadResult.saved;
  }

  void cancel(Kirtan kirtan) => _manager.cancel(keyFor(kirtan));

  Future<void> remove(Kirtan kirtan) async {
    final DownloadKey key = keyFor(kirtan);
    _save(state.removeWhere((DownloadedKirtan d) => d.kirtan.id == kirtan.id));
    try {
      await _manager.delete(key);
    } catch (error, stack) {
      AppLogger.error('Could not delete kirtan $key', error, stack);
    }
  }

  /// Local file of a downloaded kirtan, or null.
  Future<File?> localFileFor(Kirtan kirtan) async {
    final DownloadKey key = keyFor(kirtan);
    final bool known =
        state.contains(kirtan.id) ||
        (ref.read(downloadManagerProvider)[key]?.isDownloaded ?? false);
    if (!known) return null;
    try {
      return await _manager.localFile(key);
    } catch (_) {
      return null;
    }
  }

  /// Checks every indexed file, syncing download states and removing entries
  /// whose file no longer exists. Also refreshes recorded sizes.
  Future<void> prune() async {
    if (_pruning || !ref.mounted) return;
    _pruning = true;
    try {
      final KirtanDownloadsIndex snapshot = state;
      final Set<String> missing = <String>{};
      final Map<String, int> sizes = <String, int>{};
      for (final DownloadedKirtan entry in snapshot.items) {
        final File? file = await _manager.localFile(entry.key);
        if (file == null) {
          missing.add(entry.kirtan.id);
        } else if (entry.sizeBytes <= 0) {
          sizes[entry.kirtan.id] = await file.length();
        }
        if (!ref.mounted) return;
      }
      if (missing.isEmpty && sizes.isEmpty) return;
      // Re-read the state: a download may have finished meanwhile.
      final KirtanDownloadsIndex updated = KirtanDownloadsIndex(
        state.items
            .where(
              (DownloadedKirtan d) =>
                  !missing.contains(d.kirtan.id) ||
                  !snapshot.contains(d.kirtan.id),
            )
            .map(
              (DownloadedKirtan d) => sizes.containsKey(d.kirtan.id)
                  ? d.copyWith(sizeBytes: sizes[d.kirtan.id])
                  : d,
            ),
      );
      _save(updated);
    } catch (error, stack) {
      AppLogger.error('Kirtan downloads prune failed', error, stack);
    } finally {
      _pruning = false;
    }
  }

  /// Copies a fully streamed kirtan from the cache instead of downloading it
  /// again. Returns null when there is no complete cached copy.
  Future<File?> _importFromStreamCache(Kirtan kirtan, DownloadKey key) async {
    try {
      final File? cached = await ref
          .read(kirtanStreamCacheProvider)
          .completedFileFor(kirtan);
      if (cached == null) return null;
      final File target = await _manager.fileFor(key);
      final File partial = await cached.copy('${target.path}.part');
      if (target.existsSync()) await target.delete();
      await partial.rename(target.path);
      return await _manager.localFile(key);
    } catch (error, stack) {
      AppLogger.error(
        'Could not reuse cached kirtan ${kirtan.id}',
        error,
        stack,
      );
      return null;
    }
  }

  void _save(KirtanDownloadsIndex index) {
    state = index;
    unawaited(
      _prefs
          .setString(PrefKeys.kirtanDownloadsIndex, index.encode())
          .catchError((Object error, StackTrace stack) {
            AppLogger.error('Could not save kirtan downloads', error, stack);
            return false;
          }),
    );
  }
}
