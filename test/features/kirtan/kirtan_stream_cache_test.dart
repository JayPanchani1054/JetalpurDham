import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_stream_cache.dart';
import 'package:jetalpur_dham/features/kirtan/domain/kirtan.dart';
import 'package:path/path.dart' as p;

Kirtan _k(String id, String audio) =>
    Kirtan.fromMap(id, <String, Object?>{'title': id, 'audioUrl': audio});

void main() {
  group('fnv1a32', () {
    test('matches the reference FNV-1a values', () {
      expect(fnv1a32(''), 0x811c9dc5);
      expect(fnv1a32('a'), 0xe40c292c);
      expect(fnv1a32('foobar'), 0xbf9cf968);
    });
  });

  group('kirtanCacheFileName', () {
    test('is filesystem-safe and keeps the audio extension', () {
      final String name = kirtanCacheFileName(_k('a/b c', 'x/y.m4a'));
      expect(name, startsWith('a_b_c_'));
      expect(name, endsWith('.m4a'));
      expect(name, isNot(contains('/')));
    });

    test('changes when the audio file is replaced', () {
      expect(
        kirtanCacheFileName(_k('k', 'kirtans/a.mp3')),
        isNot(kirtanCacheFileName(_k('k', 'kirtans/b.mp3'))),
      );
      expect(
        kirtanCacheFileName(_k('k', 'kirtans/a.mp3')),
        kirtanCacheFileName(_k('k', 'kirtans/a.mp3')),
      );
    });
  });

  group('KirtanStreamCache', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kirtan_cache_test');
    });

    tearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    Future<File> write(
      Directory dir,
      String name,
      int bytes,
      DateTime modified,
    ) async {
      final File file = File(p.join(dir.path, name));
      await file.writeAsBytes(List<int>.filled(bytes, 1));
      await file.setLastModified(modified);
      return file;
    }

    test('completedFileFor returns only finished files', () async {
      final KirtanStreamCache cache = KirtanStreamCache(
        rootDirectory: () async => root,
      );
      final Kirtan kirtan = _k('k1', 'kirtans/a.mp3');
      expect(await cache.completedFileFor(kirtan), isNull);
      final File file = await cache.fileFor(kirtan);
      await File('${file.path}.part').writeAsString('partial');
      expect(await cache.completedFileFor(kirtan), isNull);
      await file.writeAsString('done');
      expect((await cache.completedFileFor(kirtan))?.path, file.path);
    });

    test('prunes least recently used files, stale parts and orphans', () async {
      final KirtanStreamCache cache = KirtanStreamCache(
        rootDirectory: () async => root,
        maxBytes: 250,
        targetBytes: 150,
      );
      final Directory dir = await cache.directory();
      final DateTime now = DateTime.now();
      await write(dir, 'old.mp3', 100, now.subtract(const Duration(days: 3)));
      await write(dir, 'old.mp3.mime', 10, now);
      await write(dir, 'mid.mp3', 100, now.subtract(const Duration(days: 2)));
      await write(dir, 'new.mp3', 100, now.subtract(const Duration(hours: 1)));
      await write(
        dir,
        'stale.mp3.part',
        5,
        now.subtract(const Duration(days: 1)),
      );
      await write(dir, 'live.mp3.part', 5, now);
      await write(dir, 'live.mp3.mime', 5, now);
      await write(dir, 'orphan.mp3.mime', 5, now);

      await cache.pruneOnce();

      final Set<String> left = dir
          .listSync()
          .map((FileSystemEntity e) => p.basename(e.path))
          .toSet();
      expect(left, <String>{'new.mp3', 'live.mp3.part', 'live.mp3.mime'});
    });

    test('reports its size and clears finished files', () async {
      final KirtanStreamCache cache = KirtanStreamCache(
        rootDirectory: () async => root,
      );
      final Directory dir = await cache.directory();
      await write(dir, 'a.mp3', 40, DateTime.now());
      await write(dir, 'a.mp3.mime', 10, DateTime.now());
      await write(dir, 'b.mp3.part', 5, DateTime.now());
      expect(await cache.size(), 55);
      await cache.clear();
      expect(
        dir.listSync().map((FileSystemEntity e) => p.basename(e.path)),
        <String>['b.mp3.part'],
      );
    });

    test('retries the folder after a failure and never throws', () async {
      int calls = 0;
      final KirtanStreamCache cache = KirtanStreamCache(
        rootDirectory: () async {
          calls++;
          if (calls == 1) throw const FileSystemException('unavailable');
          return root;
        },
      );
      final Kirtan kirtan = _k('k', 'kirtans/k.mp3');
      // Failure is reported to the caller but not remembered…
      await expectLater(cache.fileFor(kirtan), throwsA(isA<Exception>()));
      // …so the next call works.
      final File file = await cache.fileFor(kirtan);
      expect(p.dirname(file.path), endsWith('kirtan_stream_cache'));
      expect(await cache.completedFileFor(kirtan), isNull);
      expect(await cache.size(), 0);
    });

    test('keeps everything below the limit and prunes only once', () async {
      final KirtanStreamCache cache = KirtanStreamCache(
        rootDirectory: () async => root,
        maxBytes: 1000,
        targetBytes: 500,
      );
      final Directory dir = await cache.directory();
      await write(dir, 'a.mp3', 100, DateTime(2020));
      await cache.pruneOnce();
      expect(File(p.join(dir.path, 'a.mp3')).existsSync(), isTrue);
      expect(identical(cache.pruneOnce(), cache.pruneOnce()), isTrue);
    });
  });
}
