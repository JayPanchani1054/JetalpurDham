import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/firebase/media_url.dart';
import '../../../core/utils/app_logger.dart';

/// Outcome of saving the donation QR to the device's photos.
enum QrSaveOutcome { saved, denied, failed }

/// Validated QR code for [data], or null when it cannot be encoded.
///
/// Medium error correction keeps the code readable when printed or
/// photographed from another screen.
QrCode? buildQrCode(String data) {
  final QrValidationResult result = QrValidator.validate(
    data: data,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
  );
  return result.isValid ? result.qrCode : null;
}

/// Painter used both on screen and for the saved PNG, so they always match.
QrPainter donationQrPainter(QrCode qr) => QrPainter.withQr(
  qr: qr,
  gapless: true,
  eyeStyle: const QrEyeStyle(
    eyeShape: QrEyeShape.square,
    color: Color(0xFF000000),
  ),
  dataModuleStyle: const QrDataModuleStyle(
    dataModuleShape: QrDataModuleShape.square,
    color: Color(0xFF000000),
  ),
);

/// Renders [data] as a PNG: black modules on a white square with a quiet
/// zone, so it scans reliably from any gallery app (including dark ones —
/// `QrPainter.toImageData` alone would leave the background transparent).
Future<Uint8List> renderQrPng(String data, {int size = 1024}) async {
  final QrCode? qr = buildQrCode(data);
  if (qr == null) throw ArgumentError.value(data, 'data', 'Not encodable');
  final double side = size.toDouble();
  final double quietZone = side * 0.08;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, side, side),
      Paint()..color = const Color(0xFFFFFFFF),
    )
    ..translate(quietZone, quietZone);
  donationQrPainter(qr).paint(canvas, Size.square(side - quietZone * 2));
  final ui.Picture picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(size, size);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (bytes == null) throw StateError('QR encoding failed');
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image?.dispose();
    picture.dispose();
  }
}

/// Saves the temple's donation QR to the photo library.
class DonationQrSaver {
  DonationQrSaver({required this._resolveUrl, this._cacheManager});

  static const String albumName = 'Jetalpur Dham';
  static const String fileName = 'JetalpurDham_Donation_QR';
  static const Duration _downloadTimeout = Duration(minutes: 1);

  final Future<String> Function(String raw) _resolveUrl;
  final BaseCacheManager? _cacheManager;

  BaseCacheManager get _cache =>
      _cacheManager ?? CachedNetworkImageProvider.defaultCacheManager;

  /// Saves the official QR image ([imageUrl], read through the same disk
  /// cache the screen uses, so it works offline once shown) or, without one,
  /// a QR generated from [upiUri]. Never throws.
  Future<QrSaveOutcome> save({String? imageUrl, String? upiUri}) async {
    try {
      final String? album = await _requestAccess();
      if (album == null) return QrSaveOutcome.denied;
      final Uint8List bytes;
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        bytes = await _downloadImage(imageUrl);
      } else if (upiUri != null) {
        bytes = await renderQrPng(upiUri);
      } else {
        return QrSaveOutcome.failed;
      }
      await Gal.putImageBytes(
        bytes,
        album: album.isEmpty ? null : album,
        name: fileName,
      );
      return QrSaveOutcome.saved;
    } on GalException catch (error, stack) {
      if (error.type == GalExceptionType.accessDenied) {
        return QrSaveOutcome.denied;
      }
      AppLogger.error('Saving donation QR failed', error, stack);
      return QrSaveOutcome.failed;
    } catch (error, stack) {
      AppLogger.error('Saving donation QR failed', error, stack);
      return QrSaveOutcome.failed;
    }
  }

  /// Returns the album to save into ('' = camera roll), or null if refused.
  ///
  /// Android 10+ needs no prompt and saves into a "Jetalpur Dham" album. iOS
  /// uses the lighter "add photos only" permission (camera roll) unless full
  /// access was already granted.
  Future<String?> _requestAccess() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final bool granted =
          await Gal.hasAccess(toAlbum: true) ||
          await Gal.requestAccess(toAlbum: true);
      return granted ? albumName : null;
    }
    if (await Gal.hasAccess(toAlbum: true)) return albumName;
    final bool granted = await Gal.hasAccess() || await Gal.requestAccess();
    return granted ? '' : null;
  }

  Future<Uint8List> _downloadImage(String raw) async {
    final String url = await _resolveUrl(raw);
    final File file = await _cache.getSingleFile(url).timeout(_downloadTimeout);
    return file.readAsBytes();
  }
}

final Provider<DonationQrSaver> donationQrSaverProvider =
    Provider<DonationQrSaver>((Ref ref) {
      final MediaUrlResolver resolver = ref.watch(mediaUrlResolverProvider);
      return DonationQrSaver(resolveUrl: resolver.resolve);
    });
