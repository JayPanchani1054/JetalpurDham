import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/firebase/media_url.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/gallery_models.dart';
import '../domain/gallery_queries.dart';

/// Outcome of saving one photo to the device gallery.
enum PhotoSaveOutcome { saved, denied, failed }

/// Where photos may be written, decided once per save session.
@immutable
class SaveAccess {
  const SaveAccess._(this.album);

  /// Saved into the "Jetalpur Dham" album.
  const SaveAccess.album(String name) : this._(name);

  /// Saved to the main camera roll (iOS "add only" permission).
  static const SaveAccess cameraRoll = SaveAccess._(null);

  final String? album;
}

/// Saves and shares album photos.
///
/// Photos are read through the same disk cache the image widgets use, so a
/// photo that is already on screen is saved or shared instantly and offline.
class PhotoSaver {
  PhotoSaver({required this._resolveUrl, this._cacheManager});

  /// Device album that saved photos go into.
  static const String albumName = 'Jetalpur Dham';

  static const Duration _downloadTimeout = Duration(minutes: 2);

  final Future<String> Function(String raw) _resolveUrl;
  final BaseCacheManager? _cacheManager;

  BaseCacheManager get _cache =>
      _cacheManager ?? CachedNetworkImageProvider.defaultCacheManager;

  /// Asks for permission to write to the photo library (once per session).
  /// Returns null when the user refused. Throws on platform errors.
  ///
  /// Android needs no prompt on Android 10+ and saves into a "Jetalpur Dham"
  /// album. On iOS an album needs full photo-library access, so unless that
  /// was already granted we use the lighter "add photos only" permission and
  /// save to the camera roll — one simple, trustworthy prompt.
  Future<SaveAccess?> requestAccess() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final bool granted =
          await Gal.hasAccess(toAlbum: true) ||
          await Gal.requestAccess(toAlbum: true);
      return granted ? const SaveAccess.album(albumName) : null;
    }
    if (await Gal.hasAccess(toAlbum: true)) {
      return const SaveAccess.album(albumName);
    }
    final bool granted = await Gal.hasAccess() || await Gal.requestAccess();
    return granted ? SaveAccess.cameraRoll : null;
  }

  /// Saves one photo. Never throws.
  Future<PhotoSaveOutcome> save(
    AlbumPhoto photo, {
    required String albumId,
    SaveAccess? access,
  }) async {
    try {
      final SaveAccess? target = access ?? await requestAccess();
      if (target == null) return PhotoSaveOutcome.denied;
      final Uint8List bytes = await loadBytes(photo);
      await Gal.putImageBytes(
        bytes,
        album: target.album,
        name: photoFileName(albumId, photo.id),
      );
      return PhotoSaveOutcome.saved;
    } on GalException catch (error, stack) {
      if (error.type == GalExceptionType.accessDenied) {
        return PhotoSaveOutcome.denied;
      }
      AppLogger.error('Saving photo ${photo.id} failed', error, stack);
      return PhotoSaveOutcome.failed;
    } catch (error, stack) {
      AppLogger.error('Saving photo ${photo.id} failed', error, stack);
      return PhotoSaveOutcome.failed;
    }
  }

  /// Opens the system share sheet with the photo. Returns false on failure.
  Future<bool> share(
    AlbumPhoto photo, {
    required String albumId,
    String? text,
    Rect? origin,
  }) async {
    try {
      final Uint8List bytes = await loadBytes(photo);
      final ImageFileType type = sniffImageType(bytes);
      final Directory dir = await _shareDirectory();
      final File file = File(
        p.join(
          dir.path,
          '${photoFileName(albumId, photo.id)}.${type.extension}',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: type.mimeType)],
          text: text,
          sharePositionOrigin: origin,
        ),
      );
      return true;
    } catch (error, stack) {
      AppLogger.error('Sharing photo ${photo.id} failed', error, stack);
      return false;
    }
  }

  /// The full-size photo bytes, from the disk cache when available.
  Future<Uint8List> loadBytes(AlbumPhoto photo) async {
    final String url = await _resolveUrl(photo.url);
    final File file = await _cache.getSingleFile(url).timeout(_downloadTimeout);
    return file.readAsBytes();
  }

  /// Temporary folder for shared files; files older than an hour are removed
  /// (recent ones may still be read by the app the user shared to).
  Future<Directory> _shareDirectory() async {
    final Directory dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'shared_photos'),
    );
    if (await dir.exists()) {
      final DateTime cutoff = DateTime.now().subtract(const Duration(hours: 1));
      try {
        await for (final FileSystemEntity entity in dir.list()) {
          if (entity is File &&
              (await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      } catch (error) {
        AppLogger.info('Could not clean shared photos: $error');
      }
    } else {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

final Provider<PhotoSaver> photoSaverProvider = Provider<PhotoSaver>((Ref ref) {
  final MediaUrlResolver resolver = ref.watch(mediaUrlResolverProvider);
  return PhotoSaver(resolveUrl: resolver.resolve);
});
