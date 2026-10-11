import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/services/download_service.dart';
import 'package:jetalpur_dham/features/kirtan/data/kirtan_downloads_index.dart';
import 'package:jetalpur_dham/features/kirtan/domain/kirtan.dart';

DownloadedKirtan _entry(String id, {int bytes = 100, String ext = '.mp3'}) =>
    DownloadedKirtan(
      kirtan: Kirtan.fromMap(id, <String, Object?>{
        'title': <String, Object?>{'en': 'Kirtan $id', 'gu': 'કીર્તન $id'},
        'poet': 'Premanand Swami',
        'audioUrl': 'kirtans/aarti/$id$ext',
        'durationSec': 300,
        'lyrics': 'Line one\nLine two',
      }),
      extension: ext,
      sizeBytes: bytes,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

void main() {
  test('encodes and decodes without losing anything', () {
    final KirtanDownloadsIndex index = KirtanDownloadsIndex(<DownloadedKirtan>[
      _entry('a', bytes: 4000),
      _entry('b', ext: '.m4a', bytes: 6000),
    ]);
    final KirtanDownloadsIndex decoded = KirtanDownloadsIndex.decode(
      index.encode(),
    );
    expect(decoded, index);
    expect(decoded.items.first.kirtan.title.resolve('gu'), 'કીર્તન a');
    expect(
      decoded.items.first.kirtan.lyrics.resolve('en'),
      'Line one\nLine two',
    );
    expect(decoded['b']?.extension, '.m4a');
    expect(decoded.totalBytes, 10000);
  });

  test('corrupt or missing data yields an empty index', () {
    expect(KirtanDownloadsIndex.decode(null).isEmpty, isTrue);
    expect(KirtanDownloadsIndex.decode('').isEmpty, isTrue);
    expect(KirtanDownloadsIndex.decode('{not json').isEmpty, isTrue);
    expect(KirtanDownloadsIndex.decode('"text"').isEmpty, isTrue);
    expect(KirtanDownloadsIndex.decode('{"items": 5}').isEmpty, isTrue);
  });

  test('skips malformed entries, duplicates and fixes bad extensions', () {
    final String raw = jsonEncode(<String, Object?>{
      'items': <Object?>[
        <String, Object?>{'id': 'a', 'ext': 'mp3', 'bytes': '12'},
        <String, Object?>{'id': 'a', 'ext': '.m4a'},
        <String, Object?>{'ext': '.mp3'},
        'garbage',
        <String, Object?>{
          'id': 'b',
          'kirtan': <String, Object?>{'title': 'B'},
        },
      ],
    });
    final KirtanDownloadsIndex index = KirtanDownloadsIndex.decode(raw);
    expect(index.items.map((DownloadedKirtan d) => d.kirtan.id), <String>[
      'a',
      'b',
    ]);
    expect(index['a']?.extension, '.mp3');
    expect(index['a']?.sizeBytes, 12);
    expect(index['b']?.kirtan.title.resolve('en'), 'B');
  });

  test('accepts a bare list (older format)', () {
    final String raw = jsonEncode(<Object?>[_entry('x').toJson()]);
    expect(KirtanDownloadsIndex.decode(raw).contains('x'), isTrue);
  });

  test('upsert puts the newest download first and replaces old entries', () {
    final KirtanDownloadsIndex index = KirtanDownloadsIndex(<DownloadedKirtan>[
      _entry('a'),
      _entry('b'),
    ]).upsert(_entry('c')).upsert(_entry('b', bytes: 999));
    expect(index.items.map((DownloadedKirtan d) => d.kirtan.id), <String>[
      'b',
      'c',
      'a',
    ]);
    expect(index['b']?.sizeBytes, 999);
    expect(index.length, 3);
  });

  test('removeWhere drops entries', () {
    final KirtanDownloadsIndex index = KirtanDownloadsIndex(<DownloadedKirtan>[
      _entry('a'),
      _entry('b'),
    ]).removeWhere((DownloadedKirtan d) => d.kirtan.id == 'a');
    expect(index.contains('a'), isFalse);
    expect(index.contains('b'), isTrue);
  });

  test('download key points at kirtans/<id><ext>', () {
    final DownloadKey key = _entry('k9', ext: '.m4a').key;
    expect(key.folder, DownloadFolders.kirtans);
    expect(key.id, 'k9');
    expect(key.extension, '.m4a');
    expect(key, kirtanDownloadKey('k9', '.m4a'));
  });
}
