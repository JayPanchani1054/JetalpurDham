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

/// Painter for [data] (used both on screen and for the saved PNG, so they
/// always match), or null when the data cannot be encoded.
///
/// Medium error correction keeps the code readable when printed or
/// photographed from another screen; the package defaults (square black
/// modules and eyes) are the most scanner-friendly style.
QrPainter? buildQrPainter(String data) {
  try {
    final QrValidationResult result = QrValidator.validate(
      data: data,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    final QrCode? qr = result.qrCode;
    if (!result.isValid || qr == null) return null;
    // The QR matrix is computed here, so oversized data fails now instead of
    // during painting.
    return QrPainter.withQr(qr: qr, gapless: true);
  } catch (error, stack) {
    AppLogger.error('Could not encode QR', error, stack);
    return null;
  }
}

/// Renders [data] as a PNG: black modules on a white square with a quiet
/// zone, so it scans reliably from any gallery app (including dark ones —
/// `QrPainter.toImageData` alone would leave the background transparent).
Future<Uint8List> renderQrPng(String data, {int size = 1024}) async {
  final QrPainter? painter = buildQrPainter(data);
  if (painter == null) {
    throw ArgumentError.value(data, 'data', 'Not encodable');
  }
  final double side = size.toDouble();
  // ~4 modules of white margin, as the QR specification recommends.
  final double quietZone = side * 0.1;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, side, side),
      Paint()..color = const Color(0xFFFFFFFF),
    )
    ..translate(quietZone, quietZone);
  painter.paint(canvas, Size.square(side - quietZone * 2));
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
      final Uint8List? bytes = await _qrBytes(imageUrl, upiUri);
      if (bytes == null) return QrSaveOutcome.failed;
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

  /// The official QR image, or — when there is none or it cannot be
  /// downloaded (e.g. offline) — a QR generated from the UPI link.
  Future<Uint8List?> _qrBytes(String? imageUrl, String? upiUri) async {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      try {
        return await _downloadImage(imageUrl);
      } catch (error, stack) {
        if (upiUri == null) rethrow;
        AppLogger.error('QR image unavailable, generating it', error, stack);
      }
    }
    return upiUri == null ? null : renderQrPng(upiUri);
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
