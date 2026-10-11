import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/models/localized_text.dart';
import 'package:jetalpur_dham/features/kirtan/domain/kirtan.dart';

void main() {
  group('Kirtan.fromMap', () {
    test('parses every documented field', () {
      final DateTime created = DateTime(2026, 3, 14, 10, 30);
      final Kirtan k = Kirtan.fromMap('k1', <String, Object?>{
        'title': <String, Object?>{
          'en': 'Jay Sadguru Swami',
          'gu': 'જય સદગુરુ સ્વામી',
        },
        'poet': 'Premanand Swami',
        'singer': <String, Object?>{'en': 'Santo'},
        'categoryId': 'aarti',
        'audioUrl': 'https://example.com/a.mp3',
        'durationSec': 275,
        'sizeBytes': 4400000,
        'lyrics': <String, Object?>{'gu': 'જય સદગુરુ…'},
        'coverUrl': 'kirtans/covers/a.jpg',
        'order': 3,
        'isActive': true,
        'isFeatured': true,
        'createdAt': Timestamp.fromDate(created),
      });
      expect(k.id, 'k1');
      expect(k.title.resolve('gu'), 'જય સદગુરુ સ્વામી');
      expect(k.title.resolve('hi'), 'Jay Sadguru Swami');
      expect(k.poet.resolve('gu'), 'Premanand Swami');
      expect(k.singer.resolve('en'), 'Santo');
      expect(k.categoryId, 'aarti');
      expect(k.audioUrl, 'https://example.com/a.mp3');
      expect(k.duration, const Duration(seconds: 275));
      expect(k.sizeBytes, 4400000);
      expect(k.lyrics.resolve('gu'), 'જય સદગુરુ…');
      expect(k.coverUrl, 'kirtans/covers/a.jpg');
      expect(k.order, 3);
      expect(k.isActive, isTrue);
      expect(k.isFeatured, isTrue);
      expect(k.createdAt, created);
      expect(k.isPlayable, isTrue);
    });

    test('tolerates missing and wrongly typed fields', () {
      final Kirtan k = Kirtan.fromMap('k2', <String, Object?>{
        'title': 42,
        'poet': <Object?>['x'],
        'audioUrl': 'kirtans/dhun/Swaminarayan_Dhun-01.mp3',
        'durationSec': 'abc',
        'sizeBytes': -5,
        'order': '7',
        'isActive': 'yes',
        'isFeatured': 'false',
        'createdAt': 'not a date',
      });
      // A non-text title falls back to a title made from the file name.
      expect(k.title.resolve('en'), 'Swaminarayan Dhun 01');
      expect(k.poet.isEmpty, isTrue);
      expect(k.durationSec, isNull);
      expect(k.sizeBytes, isNull);
      expect(k.order, 7);
      expect(k.isActive, isTrue);
      expect(k.isFeatured, isFalse);
      expect(k.createdAt, isNull);
    });

    test(
      'missing isActive defaults to true and missing isFeatured to false',
      () {
        final Kirtan k = Kirtan.fromMap('k3', <String, Object?>{
          'title': 'Dhun',
          'audioUrl': 'a.mp3',
        });
        expect(k.isActive, isTrue);
        expect(k.isFeatured, isFalse);
        expect(k.categoryId, isNull);
        expect(k.coverUrl, isNull);
      },
    );

    test('empty document falls back to the id as title and is unplayable', () {
      final Kirtan k = Kirtan.fromMap('only-id', const <String, Object?>{});
      expect(k.title.resolve('en'), 'only-id');
      expect(k.isPlayable, isFalse);
    });

    test('round-trips through toJson for the offline index', () {
      final Kirtan original = Kirtan.fromMap('k4', <String, Object?>{
        'title': <String, Object?>{'en': 'Aarti', 'hi': 'आरती'},
        'poet': 'Muktanand Swami',
        'audioUrl': 'https://example.com/aarti.m4a',
        'durationSec': '4:35',
        'lyrics': 'Jay Sadguru Swami…',
        'order': 1,
        'isFeatured': true,
        'createdAt': DateTime.fromMillisecondsSinceEpoch(1700000000000),
      });
      final Kirtan copy = Kirtan.fromMap('k4', original.toJson());
      expect(copy, original);
      expect(copy.hashCode, original.hashCode);
      expect(copy.title.resolve('hi'), 'आरती');
      expect(copy.lyrics.resolve('gu'), 'Jay Sadguru Swami…');
    });
  });

  group('Kirtan helpers', () {
    const Kirtan kirtan = Kirtan(
      id: 'x',
      title: LocalizedText(<String, String>{
        'en': 'Prem Sakhi',
        'gu': 'પ્રેમ સખી',
      }),
      audioUrl: 'a.mp3',
      poet: LocalizedText(<String, String>{'en': 'Premanand Swami'}),
      singer: LocalizedText(<String, String>{'*': 'Hari Bhakt'}),
    );

    test('credits joins poet and singer, skipping empty or equal parts', () {
      expect(kirtan.credits('en'), 'Premanand Swami · Hari Bhakt');
      const Kirtan onlySinger = Kirtan(
        id: 'y',
        title: LocalizedText(<String, String>{'en': 'T'}),
        audioUrl: 'a.mp3',
        singer: LocalizedText(<String, String>{'en': 'S'}),
      );
      expect(onlySinger.credits('en'), 'S');
      expect(onlySinger.artist.resolve('en'), 'S');
      const Kirtan same = Kirtan(
        id: 'z',
        title: LocalizedText(<String, String>{'en': 'T'}),
        audioUrl: 'a.mp3',
        poet: LocalizedText(<String, String>{'en': 'P'}),
        singer: LocalizedText(<String, String>{'en': 'P'}),
      );
      expect(same.credits('en'), 'P');
    });

    test('matches title, poet or singer in any language', () {
      expect(kirtan.matches(''), isTrue);
      expect(kirtan.matches('prem sakhi'), isTrue);
      expect(kirtan.matches('સખી'), isTrue);
      expect(kirtan.matches('PREMANAND'), isTrue);
      expect(kirtan.matches('hari'), isTrue);
      expect(kirtan.matches('brahmanand'), isFalse);
    });
  });

  group('KirtanCategory', () {
    test('parses and falls back to the id for a missing name', () {
      final KirtanCategory c = KirtanCategory.fromMap('dhun', <String, Object?>{
        'order': 2.0,
        'isActive': false,
      });
      expect(c.name.resolve('gu'), 'dhun');
      expect(c.order, 2);
      expect(c.isActive, isFalse);
    });

    test('sorts by order then name, unordered last', () {
      final List<KirtanCategory> list = <KirtanCategory>[
        KirtanCategory.fromMap('c', <String, Object?>{'name': 'Bhajan'}),
        KirtanCategory.fromMap('b', <String, Object?>{
          'name': 'Dhun',
          'order': 2,
        }),
        KirtanCategory.fromMap('a', <String, Object?>{
          'name': 'Aarti',
          'order': 1,
        }),
        KirtanCategory.fromMap('d', <String, Object?>{'name': 'Aarti 2'}),
      ]..sort(KirtanCategory.compare);
      expect(list.map((KirtanCategory c) => c.id), <String>[
        'a',
        'b',
        'd',
        'c',
      ]);
    });
  });

  group('parseKirtanDurationSeconds', () {
    test('accepts numbers and clock strings', () {
      expect(parseKirtanDurationSeconds(275), 275);
      expect(parseKirtanDurationSeconds(275.6), 276);
      expect(parseKirtanDurationSeconds('275'), 275);
      expect(parseKirtanDurationSeconds(' 4:35 '), 275);
      expect(parseKirtanDurationSeconds('1:02:45'), 3765);
    });

    test('rejects invalid, empty and non-positive values', () {
      expect(parseKirtanDurationSeconds(null), isNull);
      expect(parseKirtanDurationSeconds(0), isNull);
      expect(parseKirtanDurationSeconds(-3), isNull);
      expect(parseKirtanDurationSeconds(''), isNull);
      expect(parseKirtanDurationSeconds('abc'), isNull);
      expect(parseKirtanDurationSeconds('4:xx'), isNull);
      expect(parseKirtanDurationSeconds('1:2:3:4'), isNull);
      expect(parseKirtanDurationSeconds(true), isNull);
      expect(parseKirtanDurationSeconds(double.nan), isNull);
    });
  });

  group('kirtanAudioExtension', () {
    test('reads the extension from any media reference', () {
      expect(
        kirtanAudioExtension(
          'https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/'
          'kirtans%2Faarti%2FJay%20Sadguru.M4A?alt=media&token=abc',
        ),
        '.m4a',
      );
      expect(kirtanAudioExtension('gs://bucket/kirtans/dhun/a.ogg'), '.ogg');
      expect(kirtanAudioExtension('kirtans/dhun/a.mp3'), '.mp3');
      expect(
        kirtanAudioExtension('https://cdn.example.com/a.aac#t=10'),
        '.aac',
      );
    });

    test('falls back to .mp3 for unknown or missing extensions', () {
      expect(kirtanAudioExtension(''), '.mp3');
      expect(kirtanAudioExtension('https://example.com/stream'), '.mp3');
      expect(kirtanAudioExtension('kirtans/a.exe'), '.mp3');
      expect(kirtanAudioExtension('kirtans/.hidden'), '.mp3');
      expect(kirtanAudioExtension('kirtans/name.'), '.mp3');
    });
  });

  test('kirtanTitleFromAudioRef builds a readable title', () {
    expect(
      kirtanTitleFromAudioRef('kirtans/aarti/Jay_Sadguru--Swami.mp3'),
      'Jay Sadguru Swami',
    );
    expect(
      kirtanTitleFromAudioRef(
        'https://firebasestorage.googleapis.com/v0/b/x/o/'
        'kirtans%2Fdhun%2FSwaminarayan%20Dhun.mp3?alt=media',
      ),
      'Swaminarayan Dhun',
    );
    expect(kirtanTitleFromAudioRef(''), '');
    expect(kirtanTitleFromAudioRef('bad%escape.mp3'), 'bad%escape');
  });
}
