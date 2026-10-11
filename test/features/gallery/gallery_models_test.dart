import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/models/localized_text.dart';
import 'package:jetalpur_dham/features/gallery/data/gallery_repository.dart';
import 'package:jetalpur_dham/features/gallery/domain/gallery_models.dart';

void main() {
  group('Album.fromMap', () {
    test('parses a complete document', () {
      final DateTime date = DateTime(2025, 9, 1, 8);
      final Album album = Album.fromMap('avsar-200', <String, Object?>{
        'title': <String, Object?>{'en': 'Avsar 200', 'gu': 'અવસર ૨૦૦'},
        'description': 'Bicentenary celebration',
        'coverUrl': ' gallery/avsar-200/cover.jpg ',
        'eventDate': Timestamp.fromDate(date),
        'order': 1,
        'isActive': true,
        'isFeatured': true,
        'photoCount': 240,
      });
      expect(album.id, 'avsar-200');
      expect(album.titleFor('gu'), 'અવસર ૨૦૦');
      expect(album.titleFor('hi'), 'Avsar 200');
      expect(album.description.resolve('en'), 'Bicentenary celebration');
      expect(album.coverUrl, 'gallery/avsar-200/cover.jpg');
      expect(album.eventDate, date);
      expect(album.order, 1);
      expect(album.isActive, isTrue);
      expect(album.isFeatured, isTrue);
      expect(album.photoCount, 240);
    });

    test('tolerates missing and wrong-typed fields', () {
      final Album album = Album.fromMap('diwali_2025', <String, Object?>{
        'title': 42,
        'coverUrl': '   ',
        'eventDate': 'not a date',
        'order': '3',
        'isFeatured': 'yes',
        'photoCount': -4,
      });
      expect(album.title.isEmpty, isTrue);
      expect(album.titleFor('en'), 'Diwali 2025');
      expect(album.coverUrl, isNull);
      expect(album.eventDate, isNull);
      expect(album.order, 3);
      expect(album.isActive, isTrue, reason: 'missing isActive means true');
      expect(album.isFeatured, isTrue);
      expect(album.photoCount, 0);
    });

    test('empty document still yields a usable album', () {
      final Album album = Album.fromMap('avsar-200', const <String, Object?>{});
      expect(album.titleFor('en'), 'Avsar 200');
      expect(album.isActive, isTrue);
      expect(album.isFeatured, isFalse);
      expect(album.photoCount, isNull);
    });

    test('isActive false hides the album', () {
      expect(
        Album.fromMap('a', const <String, Object?>{'isActive': false}).isActive,
        isFalse,
      );
      expect(
        Album.fromMap('a', const <String, Object?>{
          'isActive': 'false',
        }).isActive,
        isFalse,
      );
    });

    test('value equality', () {
      final Map<String, Object?> data = <String, Object?>{
        'title': 'Avsar',
        'order': 2,
      };
      expect(Album.fromMap('a', data), Album.fromMap('a', data));
      expect(
        Album.fromMap('a', data).hashCode,
        Album.fromMap('a', data).hashCode,
      );
      expect(Album.fromMap('a', data), isNot(Album.fromMap('b', data)));
    });
  });

  group('AlbumPhoto.fromMap', () {
    test('parses fields and prefers the thumbnail for previews', () {
      final AlbumPhoto photo = AlbumPhoto.fromMap('img-0001', <String, Object?>{
        'url': 'https://example.com/full.jpg',
        'thumbUrl': 'https://example.com/thumb.webp',
        'caption': <String, Object?>{'gu': 'ઠાકોરજી'},
        'order': 1.0,
        'width': 4000,
        'height': '3000',
        'createdAt': Timestamp.fromDate(DateTime(2025, 9, 2)),
      });
      expect(photo.hasImage, isTrue);
      expect(photo.previewUrl, 'https://example.com/thumb.webp');
      expect(photo.caption.resolve('en'), 'ઠાકોરજી');
      expect(photo.order, 1);
      expect(photo.width, 4000);
      expect(photo.height, 3000);
      expect(photo.createdAt, DateTime(2025, 9, 2));
      expect(photo.isActive, isTrue);
    });

    test('falls back to the full image and rejects bad sizes', () {
      final AlbumPhoto photo = AlbumPhoto.fromMap('p', <String, Object?>{
        'url': 'gallery/avsar-200/p.jpg',
        'thumbUrl': '',
        'width': 0,
        'height': -10,
      });
      expect(photo.previewUrl, 'gallery/avsar-200/p.jpg');
      expect(photo.width, isNull);
      expect(photo.height, isNull);
      expect(photo.caption, const LocalizedText.empty());
    });

    test('a document without url has no image', () {
      expect(
        AlbumPhoto.fromMap('p', const <String, Object?>{'url': 12}).hasImage,
        isTrue,
        reason: 'numbers are coerced to text by Fs.string',
      );
      expect(
        AlbumPhoto.fromMap('p', const <String, Object?>{}).hasImage,
        isFalse,
      );
      expect(
        AlbumPhoto.fromMap('p', const <String, Object?>{
          'url': <String>['x'],
        }).hasImage,
        isFalse,
      );
    });
  });

  group('document parsing', () {
    test('skips nothing valid and never throws on odd data', () {
      final List<Album> albums = parseAlbumDocuments(
        <MapEntry<String, Map<String, Object?>>>[
          const MapEntry<String, Map<String, Object?>>('a', <String, Object?>{
            'title': 'A',
          }),
          const MapEntry<String, Map<String, Object?>>('b', <String, Object?>{
            'title': <Object?>[1, 2],
            'photoCount': <String, Object?>{},
          }),
        ],
      );
      expect(albums.map((Album a) => a.id), <String>['a', 'b']);

      final List<AlbumPhoto> photos = parsePhotoDocuments(
        <MapEntry<String, Map<String, Object?>>>[
          const MapEntry<String, Map<String, Object?>>('p1', <String, Object?>{
            'url': 'x.jpg',
          }),
          const MapEntry<String, Map<String, Object?>>('p2', <String, Object?>{
            'url': null,
            'createdAt': true,
          }),
        ],
      );
      expect(photos, hasLength(2));
    });
  });

  group('LiveList', () {
    test('offline-empty only when empty and from cache', () {
      expect(
        const LiveList<int>(<int>[], isFromCache: true).isUnavailableOffline,
        isTrue,
      );
      expect(const LiveList<int>(<int>[]).isUnavailableOffline, isFalse);
      expect(
        const LiveList<int>(<int>[1], isFromCache: true).isUnavailableOffline,
        isFalse,
      );
    });

    test('equality compares items and source', () {
      expect(
        const LiveList<int>(<int>[1, 2]),
        LiveList<int>(List<int>.of(<int>[1, 2])),
      );
      expect(
        const LiveList<int>(<int>[1, 2]),
        isNot(const LiveList<int>(<int>[1, 2], isFromCache: true)),
      );
      expect(
        const LiveList<int>(<int>[1, 2]).hashCode,
        LiveList<int>(List<int>.of(<int>[1, 2])).hashCode,
      );
    });
  });

  test('AlbumLookup equality', () {
    final Album album = Album.fromMap('a', const <String, Object?>{});
    expect(AlbumLookup(album), AlbumLookup(album));
    expect(AlbumLookup(album).exists, isTrue);
    expect(const AlbumLookup(null).exists, isFalse);
    expect(
      const AlbumLookup(null),
      isNot(const AlbumLookup(null, isFromCache: true)),
    );
  });

  test('humanizeAlbumId', () {
    expect(humanizeAlbumId('avsar-200'), 'Avsar 200');
    expect(humanizeAlbumId('diwali__2025_annakut'), 'Diwali 2025 Annakut');
    expect(humanizeAlbumId('a'), 'A');
    expect(humanizeAlbumId(''), '');
    expect(humanizeAlbumId('--'), '');
  });
}
