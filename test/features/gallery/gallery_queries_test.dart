import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/gallery/domain/gallery_models.dart';
import 'package:jetalpur_dham/features/gallery/domain/gallery_queries.dart';

Album _album(
  String id, {
  String? title,
  int? order,
  DateTime? date,
  bool featured = false,
  bool active = true,
  String? cover,
}) => Album.fromMap(id, <String, Object?>{
  'title': ?title,
  'order': ?order,
  'eventDate': ?date,
  'isFeatured': featured,
  'isActive': active,
  'coverUrl': ?cover,
});

AlbumPhoto _photo(
  String id, {
  int? order,
  DateTime? createdAt,
  String url = 'gallery/a/p.jpg',
  String? thumb,
  bool active = true,
}) => AlbumPhoto.fromMap(id, <String, Object?>{
  'url': url,
  'thumbUrl': ?thumb,
  'order': ?order,
  'createdAt': ?createdAt,
  'isActive': active,
});

List<String> _ids(Iterable<Object> items) => items
    .map(
      (Object e) => switch (e) {
        Album(:final String id) => id,
        AlbumPhoto(:final String id) => id,
        _ => '',
      },
    )
    .toList();

void main() {
  group('sortActiveAlbums', () {
    test('featured first, then order, then newest date, then title', () {
      final List<Album> sorted = sortActiveAlbums(<Album>[
        _album('old', title: 'Old', date: DateTime(2020)),
        _album('new', title: 'New', date: DateTime(2025)),
        _album('ordered2', order: 2),
        _album('ordered1', order: 1),
        _album('featured', featured: true, order: 99),
        _album('hidden', active: false, order: 0),
        _album('b-undated', title: 'B'),
        _album('a-undated', title: 'A'),
      ]);
      expect(_ids(sorted), <String>[
        'featured',
        'ordered1',
        'ordered2',
        'new',
        'old',
        'a-undated',
        'b-undated',
      ]);
    });

    test('ties fall back to id so the order is stable', () {
      final List<Album> sorted = sortActiveAlbums(<Album>[
        _album('b', title: 'Same'),
        _album('a', title: 'Same'),
      ]);
      expect(_ids(sorted), <String>['a', 'b']);
    });
  });

  group('sortVisiblePhotos', () {
    test('order, then upload time, then id; hides inactive and blank', () {
      final List<AlbumPhoto> sorted = sortVisiblePhotos(<AlbumPhoto>[
        _photo('late', createdAt: DateTime(2025, 1, 2, 8)),
        _photo('early', createdAt: DateTime(2025, 1, 1, 8)),
        _photo('z-nodate'),
        _photo('a-nodate'),
        _photo('second', order: 2),
        _photo('first', order: 1),
        _photo('hidden', order: 0, active: false),
        _photo('blank', order: 0, url: ''),
      ]);
      expect(_ids(sorted), <String>[
        'first',
        'second',
        'early',
        'late',
        'a-nodate',
        'z-nodate',
      ]);
    });

    test('handles 500+ photos', () {
      final List<AlbumPhoto> many = <AlbumPhoto>[
        for (int i = 600; i > 0; i--) _photo('p$i', order: i),
      ];
      final List<AlbumPhoto> sorted = sortVisiblePhotos(many);
      expect(sorted, hasLength(600));
      expect(sorted.first.id, 'p1');
      expect(sorted.last.id, 'p600');
    });
  });

  group('albumViewStatus', () {
    const LiveList<AlbumPhoto> none = LiveList<AlbumPhoto>(<AlbumPhoto>[]);
    const LiveList<AlbumPhoto> noneCached = LiveList<AlbumPhoto>(
      <AlbumPhoto>[],
      isFromCache: true,
    );
    final LiveList<AlbumPhoto> some = LiveList<AlbumPhoto>(<AlbumPhoto>[
      _photo('p'),
    ]);

    test('active album is ready, even without photos', () {
      expect(
        albumViewStatus(AlbumLookup(_album('a')), none),
        AlbumViewStatus.ready,
      );
    });

    test('hidden album is not found, even with photos', () {
      expect(
        albumViewStatus(AlbumLookup(_album('a', active: false)), some),
        AlbumViewStatus.notFound,
      );
    });

    test('missing album with photos still shows them', () {
      expect(
        albumViewStatus(const AlbumLookup(null), some),
        AlbumViewStatus.ready,
      );
    });

    test('missing album without photos: offline vs not found', () {
      expect(
        albumViewStatus(const AlbumLookup(null), none),
        AlbumViewStatus.notFound,
      );
      expect(
        albumViewStatus(const AlbumLookup(null, isFromCache: true), none),
        AlbumViewStatus.offline,
      );
      expect(
        albumViewStatus(const AlbumLookup(null), noneCached),
        AlbumViewStatus.offline,
      );
    });
  });

  test('displayAlbum falls back to an id-based album', () {
    expect(displayAlbum('avsar-200', const AlbumLookup(null)).id, 'avsar-200');
    expect(
      displayAlbum('avsar-200', const AlbumLookup(null)).titleFor('en'),
      'Avsar 200',
    );
    final Album album = _album('x', title: 'X');
    expect(displayAlbum('x', AlbumLookup(album)), album);
  });

  test('albumCoverUrl prefers the cover, then the first photo preview', () {
    final List<AlbumPhoto> photos = <AlbumPhoto>[
      _photo('p1', url: 'full.jpg', thumb: 'thumb.jpg'),
    ];
    expect(albumCoverUrl(_album('a', cover: 'cover.jpg'), photos), 'cover.jpg');
    expect(albumCoverUrl(_album('a'), photos), 'thumb.jpg');
    expect(albumCoverUrl(_album('a'), const <AlbumPhoto>[]), isNull);
  });

  group('selection helpers', () {
    final List<AlbumPhoto> photos = <AlbumPhoto>[
      _photo('a'),
      _photo('b'),
      _photo('c'),
    ];

    test('retainExistingSelection drops removed photos', () {
      expect(retainExistingSelection(<String>{'a', 'x', 'c'}, photos), <String>{
        'a',
        'c',
      });
      final Set<String> empty = <String>{};
      expect(identical(retainExistingSelection(empty, photos), empty), isTrue);
    });

    test('selectedPhotosInOrder follows album order', () {
      expect(_ids(selectedPhotosInOrder(photos, <String>{'c', 'a'})), <String>[
        'a',
        'c',
      ]);
    });

    test('indexOfPhoto and clampIndex', () {
      expect(indexOfPhoto(photos, 'b'), 1);
      expect(indexOfPhoto(photos, 'zz'), -1);
      expect(indexOfPhoto(photos, null), -1);
      expect(clampIndex(-3, 3), 0);
      expect(clampIndex(1, 3), 1);
      expect(clampIndex(99, 3), 2);
      expect(clampIndex(5, 0), 0);
    });
  });

  test('hero tags are unique per album and photo', () {
    expect(photoHeroTag('a', '1'), isNot(photoHeroTag('b', '1')));
    expect(photoHeroTag('a', '1'), isNot(albumCoverHeroTag('a')));
  });

  test('photoFileName is safe and bounded', () {
    expect(
      photoFileName('avsar-200', 'img-0001'),
      'JetalpurDham_avsar-200_img-0001',
    );
    expect(photoFileName('a b/c', 'x:y?.jpg'), 'JetalpurDham_a_b_c_x_y_jpg');
    expect(photoFileName('a' * 100, 'b' * 100).length, 80);
  });

  test('viewerDecodeSize stays within sensible bounds', () {
    // Capped so one decoded photo stays around 20 MB on large screens.
    expect(viewerDecodeSize(844, 3), 2560);
    expect(viewerDecodeSize(1366, 2), 2560);
    expect(viewerDecodeSize(640, 2), 1920);
    expect(viewerDecodeSize(300, 1), 1440);
    expect(viewerDecodeSize(0, 3), 2048);
    expect(viewerDecodeSize(double.nan, 3), 2048);
    expect(viewerDecodeSize(double.infinity, 3), 2048);
  });

  group('sniffImageType', () {
    Uint8List bytes(List<int> head) =>
        Uint8List.fromList(<int>[...head, ...List<int>.filled(16, 0)]);

    test('recognises common formats', () {
      expect(
        sniffImageType(bytes(<int>[0xFF, 0xD8, 0xFF, 0xE0])),
        ImageFileType.jpeg,
      );
      expect(
        sniffImageType(bytes(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])),
        ImageFileType.png,
      );
      expect(sniffImageType(bytes('GIF89a'.codeUnits)), ImageFileType.gif);
      expect(
        sniffImageType(
          bytes(<int>[...'RIFF'.codeUnits, 1, 2, 3, 4, ...'WEBP'.codeUnits]),
        ),
        ImageFileType.webp,
      );
      expect(
        sniffImageType(
          bytes(<int>[0, 0, 0, 24, ...'ftyp'.codeUnits, ...'heic'.codeUnits]),
        ),
        ImageFileType.heic,
      );
    });

    test('defaults to JPEG for unknown or short data', () {
      expect(sniffImageType(Uint8List(0)), ImageFileType.jpeg);
      expect(sniffImageType(bytes(<int>[1, 2, 3])), ImageFileType.jpeg);
      expect(
        sniffImageType(
          bytes(<int>[0, 0, 0, 24, ...'ftyp'.codeUnits, ...'mp42'.codeUnits]),
        ),
        ImageFileType.jpeg,
      );
    });

    test('extensions and mime types match', () {
      expect(ImageFileType.jpeg.extension, 'jpg');
      expect(ImageFileType.jpeg.mimeType, 'image/jpeg');
      expect(ImageFileType.webp.mimeType, 'image/webp');
    });
  });
}
