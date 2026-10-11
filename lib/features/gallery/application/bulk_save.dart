import 'package:flutter/foundation.dart';

import '../domain/gallery_models.dart';
import 'photo_saver.dart';

/// Progress of saving several photos one after another.
@immutable
class BulkSaveProgress {
  const BulkSaveProgress({
    required this.total,
    this.saved = 0,
    this.failed = 0,
    this.denied = false,
    this.cancelled = false,
    this.finished = false,
  });

  final int total;
  final int saved;
  final int failed;

  /// Photo-library permission was refused; saving stopped.
  final bool denied;

  /// The user stopped saving.
  final bool cancelled;
  final bool finished;

  /// Photos handled so far (saved or failed).
  int get done => saved + failed;

  /// 0..1 for a progress bar.
  double get fraction => total <= 0 ? 0 : (done / total).clamp(0, 1);

  BulkSaveProgress copyWith({
    int? saved,
    int? failed,
    bool? denied,
    bool? cancelled,
    bool? finished,
  }) => BulkSaveProgress(
    total: total,
    saved: saved ?? this.saved,
    failed: failed ?? this.failed,
    denied: denied ?? this.denied,
    cancelled: cancelled ?? this.cancelled,
    finished: finished ?? this.finished,
  );

  @override
  bool operator ==(Object other) =>
      other is BulkSaveProgress &&
      other.total == total &&
      other.saved == saved &&
      other.failed == failed &&
      other.denied == denied &&
      other.cancelled == cancelled &&
      other.finished == finished;

  @override
  int get hashCode =>
      Object.hash(total, saved, failed, denied, cancelled, finished);
}

/// Saves photos sequentially (gentle on memory and network), reporting
/// progress after each one. Can be cancelled at any time; the photo being
/// saved finishes first.
class BulkSaveJob {
  BulkSaveJob({
    required List<AlbumPhoto> photos,
    required this._save,
    this.maxConsecutiveFailures = 5,
  }) : _photos = List<AlbumPhoto>.unmodifiable(photos);

  final List<AlbumPhoto> _photos;
  final Future<PhotoSaveOutcome> Function(AlbumPhoto photo) _save;

  /// Stops early when this many photos in a row fail (usually no internet),
  /// instead of trying every remaining photo.
  final int maxConsecutiveFailures;

  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  Future<BulkSaveProgress> run({
    void Function(BulkSaveProgress progress)? onProgress,
  }) async {
    BulkSaveProgress progress = BulkSaveProgress(total: _photos.length);
    int failuresInARow = 0;
    for (final AlbumPhoto photo in _photos) {
      if (_cancelled) break;
      final PhotoSaveOutcome outcome = await _save(photo);
      switch (outcome) {
        case PhotoSaveOutcome.saved:
          failuresInARow = 0;
          progress = progress.copyWith(saved: progress.saved + 1);
        case PhotoSaveOutcome.failed:
          failuresInARow++;
          progress = progress.copyWith(failed: progress.failed + 1);
        case PhotoSaveOutcome.denied:
          progress = progress.copyWith(denied: true);
      }
      if (progress.denied) break;
      onProgress?.call(progress);
      if (failuresInARow >= maxConsecutiveFailures) break;
    }
    progress = progress.copyWith(cancelled: _cancelled, finished: true);
    onProgress?.call(progress);
    return progress;
  }
}
