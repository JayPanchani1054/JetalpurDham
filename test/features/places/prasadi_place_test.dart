import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/models/localized_text.dart';
import 'package:jetalpur_dham/features/places/domain/prasadi_place.dart';

void main() {
  group('PrasadiPlace.fromMap', () {
    test('parses a complete document', () {
      final PrasadiPlace place = PrasadiPlace.fromMap(
        'dev-sarovar',
        <String, Object?>{
          'name': <String, Object?>{'en': 'Dev Sarovar', 'gu': 'દેવ સરોવર'},
          'shortDescription': 'Sacred lake',
          'mahima': <String, Object?>{'en': 'Shreeji bathed here.'},
          'address': 'Jetalpur, Ahmedabad',
          'location': const GeoPoint(22.8891, 72.5959),
          'category': 'water',
          'images': <Object?>['places/dev-sarovar/1.jpg', ' ', 42],
          'panoramaUrls': <Object?>['places/dev-sarovar/360-1.jpg'],
          'streetView': <String, Object?>{
            'lat': 22.8892,
            'lng': 72.5958,
            'heading': 90,
            'pitch': 5,
          },
          'order': 3,
          'isActive': true,
        },
      );

      expect(place.id, 'dev-sarovar');
      expect(place.name.resolve('gu'), 'દેવ સરોવર');
      expect(place.name.resolve('hi'), 'Dev Sarovar');
      expect(place.shortDescription.resolve('gu'), 'Sacred lake');
      expect(place.mahima.resolve('en'), 'Shreeji bathed here.');
      expect(place.location, const GeoCoordinate(22.8891, 72.5959));
      expect(place.category, PlaceCategory.water);
      expect(place.images, <String>['places/dev-sarovar/1.jpg']);
      expect(place.coverImage, 'places/dev-sarovar/1.jpg');
      expect(place.hasPanorama, isTrue);
      expect(place.order, 3);
      expect(place.isActive, isTrue);

      final StreetViewTarget target = place.streetViewTarget!;
      expect(target.coordinate, const GeoCoordinate(22.8892, 72.5958));
      expect(target.heading, 90);
      expect(target.pitch, 5);
    });

    test('tolerates an empty document', () {
      final PrasadiPlace place = PrasadiPlace.fromMap(
        'prasadi-ni-amli',
        const <String, Object?>{},
      );
      expect(place.name.resolve('en'), 'Prasadi Ni Amli');
      expect(place.shortDescription.isEmpty, isTrue);
      expect(place.mahima.isEmpty, isTrue);
      expect(place.location, isNull);
      expect(place.hasLocation, isFalse);
      expect(place.category, PlaceCategory.other);
      expect(place.images, isEmpty);
      expect(place.coverImage, isNull);
      expect(place.panoramaUrls, isEmpty);
      expect(place.streetView, isNull);
      expect(place.streetViewTarget, isNull);
      expect(place.order, isNull);
      expect(place.isActive, isTrue, reason: 'missing isActive means active');
    });

    test('tolerates wrong types', () {
      final PrasadiPlace place = PrasadiPlace.fromMap('x', <String, Object?>{
        'name': 12,
        'mahima': <Object?>['not', 'text'],
        'location': 'somewhere',
        'category': 7,
        'images': 'places/x/cover.jpg',
        'panoramaUrls': <String, Object?>{'a': 'b'},
        'streetView': 'north',
        'order': '5',
        'isActive': 'false',
      });
      expect(place.name.resolve('en'), 'X');
      expect(place.mahima.isEmpty, isTrue);
      expect(place.location, isNull);
      expect(place.category, PlaceCategory.other);
      expect(place.images, <String>['places/x/cover.jpg']);
      expect(place.panoramaUrls, isEmpty);
      expect(place.streetView, isNull);
      expect(place.order, 5);
      expect(place.isActive, isFalse);
    });

    test('accepts image maps and legacy single-image fields', () {
      final PrasadiPlace fromMaps = PrasadiPlace.fromMap('a', <String, Object?>{
        'images': <Object?>[
          <String, Object?>{'url': 'https://example.com/1.jpg'},
          <String, Object?>{'src': 'places/a/2.jpg'},
          <String, Object?>{'caption': 'no url'},
        ],
      });
      expect(fromMaps.images, <String>[
        'https://example.com/1.jpg',
        'places/a/2.jpg',
      ]);

      final PrasadiPlace legacy = PrasadiPlace.fromMap('b', <String, Object?>{
        'coverUrl': 'places/b/cover.jpg',
        'panoramaUrl': 'places/b/360.jpg',
      });
      expect(legacy.images, <String>['places/b/cover.jpg']);
      expect(legacy.panoramaUrls, <String>['places/b/360.jpg']);
    });

    test('street view falls back to the location', () {
      final PrasadiPlace place = PrasadiPlace.fromMap('a', <String, Object?>{
        'location': const GeoPoint(22.88, 72.59),
        'streetView': <String, Object?>{'heading': -90, 'pitch': 200},
      });
      final StreetViewTarget target = place.streetViewTarget!;
      expect(target.coordinate, const GeoCoordinate(22.88, 72.59));
      expect(target.heading, 270, reason: 'heading is normalised to 0..360');
      expect(target.pitch, 90, reason: 'pitch is clamped');

      final PrasadiPlace noHeading = PrasadiPlace.fromMap(
        'b',
        <String, Object?>{'location': const GeoPoint(22.88, 72.59)},
      );
      expect(noHeading.streetViewTarget?.heading, 0);
      expect(noHeading.streetViewTarget?.pitch, 0);
    });

    test('turns literal \\n sequences in the mahima into paragraphs', () {
      final PrasadiPlace place = PrasadiPlace.fromMap('a', <String, Object?>{
        'mahima': <String, Object?>{
          'en': r'First.\nSecond.\n\n\n\nThird.',
          'gu': 'પહેલું.\r\nબીજું.',
        },
      });
      expect(place.mahima.resolve('en'), 'First.\nSecond.\n\nThird.');
      expect(place.mahima.resolve('gu'), 'પહેલું.\nબીજું.');
    });

    test('supports equality', () {
      Map<String, Object?> doc() => <String, Object?>{
        'name': 'Yagnashala',
        'images': <Object?>['a.jpg'],
        'location': const GeoPoint(22.8, 72.5),
      };
      expect(
        PrasadiPlace.fromMap('y', doc()),
        PrasadiPlace.fromMap('y', doc()),
      );
      expect(
        PrasadiPlace.fromMap('y', doc()).hashCode,
        PrasadiPlace.fromMap('y', doc()).hashCode,
      );
    });
  });

  group('GeoCoordinate.tryParse', () {
    test('accepts GeoPoint, maps, lists and Google Maps strings', () {
      const GeoCoordinate expected = GeoCoordinate(22.889512, 72.595634);
      expect(
        GeoCoordinate.tryParse(const GeoPoint(22.889512, 72.595634)),
        expected,
      );
      expect(
        GeoCoordinate.tryParse(<String, Object?>{
          'lat': 22.889512,
          'lng': 72.595634,
        }),
        expected,
      );
      expect(
        GeoCoordinate.tryParse(<String, Object?>{
          'latitude': '22.889512',
          'longitude': '72.595634',
        }),
        expected,
      );
      expect(
        GeoCoordinate.tryParse(<String, Object?>{
          '_latitude': 22.889512,
          '_longitude': 72.595634,
        }),
        expected,
      );
      expect(GeoCoordinate.tryParse(<Object?>[22.889512, 72.595634]), expected);
      expect(GeoCoordinate.tryParse('22.889512, 72.595634'), expected);
      expect(GeoCoordinate.tryParse('(22.889512 72.595634)'), expected);
    });

    test('rejects invalid or placeholder coordinates', () {
      expect(GeoCoordinate.tryParse(null), isNull);
      expect(GeoCoordinate.tryParse('Jetalpur'), isNull);
      expect(GeoCoordinate.tryParse('22.88'), isNull);
      expect(GeoCoordinate.tryParse(const GeoPoint(0, 0)), isNull);
      expect(
        GeoCoordinate.tryParse(<String, Object?>{'lat': 200, 'lng': 72}),
        isNull,
      );
      expect(
        GeoCoordinate.tryParse(<String, Object?>{'lat': 22, 'lng': -500}),
        isNull,
      );
      expect(
        GeoCoordinate.tryParse(<String, Object?>{'lat': double.nan, 'lng': 1}),
        isNull,
      );
    });

    test('a place reads top-level lat/lng when location is missing', () {
      final PrasadiPlace place = PrasadiPlace.fromMap('a', <String, Object?>{
        'lat': 22.88,
        'lng': 72.59,
      });
      expect(place.location, const GeoCoordinate(22.88, 72.59));
    });
  });

  group('PlaceCategory.fromValue', () {
    test('exact names', () {
      for (final PlaceCategory category in PlaceCategory.values) {
        expect(PlaceCategory.fromValue(category.name), category);
        expect(
          PlaceCategory.fromValue(' ${category.name.toUpperCase()} '),
          category,
        );
      }
    });

    test('common words typed by staff', () {
      expect(PlaceCategory.fromValue('Mandir'), PlaceCategory.temple);
      expect(PlaceCategory.fromValue('Yagnashala'), PlaceCategory.yagna);
      expect(PlaceCategory.fromValue('Talav'), PlaceCategory.water);
      expect(PlaceCategory.fromValue('Lake'), PlaceCategory.water);
      expect(PlaceCategory.fromValue('Prasadi Tree'), PlaceCategory.tree);
      expect(PlaceCategory.fromValue('Ordo'), PlaceCategory.residence);
    });

    test('Gujarati and Hindi words typed in the console', () {
      expect(PlaceCategory.fromValue('મંદિર'), PlaceCategory.temple);
      expect(PlaceCategory.fromValue('यज्ञशाला'), PlaceCategory.yagna);
      expect(PlaceCategory.fromValue('ગોમતી તળાવ'), PlaceCategory.water);
      expect(PlaceCategory.fromValue('બાવડી / વાવ'), PlaceCategory.water);
      expect(PlaceCategory.fromValue('प्रसादी वृक्ष'), PlaceCategory.tree);
      expect(PlaceCategory.fromValue('અક્ષર ઓરડી'), PlaceCategory.residence);
      expect(PlaceCategory.fromValue('પ્રસાદીની વસ્તુ'), PlaceCategory.other);
    });

    test('unknown, empty or non-string values are other', () {
      expect(PlaceCategory.fromValue('relics'), PlaceCategory.other);
      expect(PlaceCategory.fromValue(''), PlaceCategory.other);
      expect(PlaceCategory.fromValue(null), PlaceCategory.other);
      expect(PlaceCategory.fromValue(true), PlaceCategory.other);
    });
  });

  group('helpers', () {
    test('humanizeId', () {
      expect(
        humanizeId('nij-mandir_revati  baldevji'),
        'Nij Mandir Revati Baldevji',
      );
      expect(humanizeId(''), '');
    });

    test('normalizeLongText keeps empty text empty', () {
      expect(normalizeLongText(const LocalizedText.empty()).isEmpty, isTrue);
    });
  });
}
