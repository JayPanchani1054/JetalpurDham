import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/gallery/application/bulk_save.dart';
import 'package:jetalpur_dham/features/gallery/application/photo_saver.dart';
import 'package:jetalpur_dham/features/gallery/domain/gallery_models.dart';

List<AlbumPhoto> _photos(int count) => <AlbumPhoto>[
  for (int i = 0; i < count; i++) AlbumPhoto(id: 'p$i', url: 'p$i.jpg'),
];

void main() {
  test('saves every photo in order and reports progress', () async {
    final List<String> saved = <String>[];
    final List<BulkSaveProgress> updates = <BulkSaveProgress>[];
    final BulkSaveJob job = BulkSaveJob(
      photos: _photos(3),
      save: (AlbumPhoto photo) async {
        saved.add(photo.id);
        return PhotoSaveOutcome.saved;
      },
    );
    final BulkSaveProgress result = await job.run(onProgress: updates.add);
    expect(saved, <String>['p0', 'p1', 'p2']);
    expect(result.saved, 3);
    expect(result.failed, 0);
    expect(result.finished, isTrue);
    expect(result.cancelled, isFalse);
    expect(result.fraction, 1);
    expect(updates.map((BulkSaveProgress p) => p.done), <int>[1, 2, 3, 3]);
  });

  test('counts failures but keeps going', () async {
    int calls = 0;
    final BulkSaveProgress result = await BulkSaveJob(
      photos: _photos(4),
      save: (AlbumPhoto photo) async {
        final bool ok = calls.isEven;
        calls++;
        return ok ? PhotoSaveOutcome.saved : PhotoSaveOutcome.failed;
      },
    ).run();
    expect(result.saved, 2);
    expect(result.failed, 2);
    expect(result.done, 4);
  });

  test('stops after too many failures in a row (e.g. offline)', () async {
    int calls = 0;
    final BulkSaveProgress result = await BulkSaveJob(
      photos: _photos(50),
      maxConsecutiveFailures: 3,
      save: (AlbumPhoto photo) async {
        calls++;
        return PhotoSaveOutcome.failed;
      },
    ).run();
    expect(calls, 3);
    expect(result.failed, 3);
    expect(result.saved, 0);
    expect(result.finished, isTrue);
  });

  test('stops immediately when permission is denied', () async {
    int calls = 0;
    final BulkSaveProgress result = await BulkSaveJob(
      photos: _photos(5),
      save: (AlbumPhoto photo) async {
        calls++;
        return calls == 2 ? PhotoSaveOutcome.denied : PhotoSaveOutcome.saved;
      },
    ).run();
    expect(calls, 2);
    expect(result.denied, isTrue);
    expect(result.saved, 1);
  });

  test('cancel stops after the current photo', () async {
    late final BulkSaveJob job;
    int calls = 0;
    job = BulkSaveJob(
      photos: _photos(10),
      save: (AlbumPhoto photo) async {
        calls++;
        if (calls == 3) job.cancel();
        return PhotoSaveOutcome.saved;
      },
    );
    final BulkSaveProgress result = await job.run();
    expect(calls, 3);
    expect(result.saved, 3);
    expect(result.cancelled, isTrue);
    expect(job.isCancelled, isTrue);
  });

  test('empty job finishes at once', () async {
    final BulkSaveProgress result = await BulkSaveJob(
      photos: const <AlbumPhoto>[],
      save: (AlbumPhoto photo) async => PhotoSaveOutcome.saved,
    ).run();
    expect(result.total, 0);
    expect(result.fraction, 0);
    expect(result.finished, isTrue);
  });

  test('progress equality', () {
    expect(
      const BulkSaveProgress(total: 2, saved: 1),
      const BulkSaveProgress(total: 2, saved: 1),
    );
    expect(const BulkSaveProgress(total: 2).copyWith(failed: 1).done, 1);
  });
}
