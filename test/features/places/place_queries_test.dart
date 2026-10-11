import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/places/domain/place_queries.dart';
import 'package:jetalpur_dham/features/places/domain/prasadi_place.dart';

PrasadiPlace _place(String id, {Object? order, Object? active, String? name}) =>
    PrasadiPlace.fromMap(id, <String, Object?>{
      'name': name ?? id,
      'order': ?order,
      'isActive': ?active,
    });

void main() {
  group('sortActivePlaces', () {
    test('hides inactive places and sorts by order, then name, then id', () {
      final List<PrasadiPlace> sorted = sortActivePlaces(<PrasadiPlace>[
        _place('c', name: 'Charlie'),
        _place('hidden', order: 0, active: false),
        _place('b', order: 2),
        _place('a', order: 1),
        _place('d2', name: 'alpha'),
        _place('d1', name: 'Alpha'),
        _place('string-false', active: 'false'),
      ]);
      expect(sorted.map((PrasadiPlace p) => p.id), <String>[
        'a',
        'b',
        'd1',
        'd2',
        'c',
      ]);
    });

    test('empty input', () {
      expect(sortActivePlaces(const <PrasadiPlace>[]), isEmpty);
    });
  });

  test('findPlace', () {
    final List<PrasadiPlace> places = <PrasadiPlace>[_place('a'), _place('b')];
    expect(findPlace(places, 'b')?.id, 'b');
    expect(findPlace(places, 'missing'), isNull);
  });

  test('clampPanoramaIndex', () {
    expect(clampPanoramaIndex(0, 0), 0);
    expect(clampPanoramaIndex(5, 0), 0);
    expect(clampPanoramaIndex(-3, 2), 0);
    expect(clampPanoramaIndex(1, 2), 1);
    expect(clampPanoramaIndex(9, 3), 2);
  });

  group('GeoBounds', () {
    test('around coordinates', () {
      final GeoBounds bounds = GeoBounds.around(const <GeoCoordinate>[
        GeoCoordinate(22.8895, 72.5956),
        GeoCoordinate(22.8915, 72.5930),
        GeoCoordinate(22.8875, 72.5990),
      ])!;
      expect(bounds.south, 22.8875);
      expect(bounds.north, 22.8915);
      expect(bounds.west, 72.5930);
      expect(bounds.east, 72.5990);
      expect(bounds.center.latitude, closeTo(22.8895, 1e-9));
      expect(bounds.center.longitude, closeTo(72.5960, 1e-9));
    });

    test('null when empty', () {
      expect(GeoBounds.around(const <GeoCoordinate>[]), isNull);
    });
  });

  group('fitZoom', () {
    const GeoBounds templeComplex = GeoBounds(
      south: 22.88915,
      west: 72.59530,
      north: 22.88985,
      east: 72.59595,
    );

    test('a single point (or tiny area) gets the max zoom', () {
      const GeoBounds point = GeoBounds(
        south: 22.8895,
        west: 72.5956,
        north: 22.8895,
        east: 72.5956,
      );
      expect(fitZoom(bounds: point, width: 390, height: 500), 17);
      expect(fitZoom(bounds: point, width: 390, height: 500, maxZoom: 19), 19);
    });

    test('places ~80 m apart fit at street level', () {
      final double zoom = fitZoom(
        bounds: templeComplex,
        width: 390,
        height: 450,
        maxZoom: 21,
      );
      expect(zoom, greaterThan(17));
      expect(zoom, lessThan(20));
    });

    test('a wider area zooms out, and a bigger map zooms in', () {
      const GeoBounds gujarat = GeoBounds(
        south: 20.1,
        west: 68.1,
        north: 24.7,
        east: 74.5,
      );
      final double small = fitZoom(bounds: gujarat, width: 360, height: 400);
      final double big = fitZoom(bounds: gujarat, width: 1080, height: 1200);
      expect(small, inInclusiveRange(4, 7));
      expect(big, greaterThan(small));
      expect(
        fitZoom(bounds: templeComplex, width: 390, height: 450, maxZoom: 21),
        greaterThan(small),
      );
    });

    test('never below minZoom and tolerates tiny maps', () {
      const GeoBounds world = GeoBounds(
        south: -80,
        west: -179,
        north: 80,
        east: 179,
      );
      expect(fitZoom(bounds: world, width: 360, height: 400), 3);
      final double tiny = fitZoom(bounds: templeComplex, width: 0, height: 0);
      expect(tiny.isFinite, isTrue);
      expect(tiny, inInclusiveRange(3, 17));
    });
  });

  test('googleMapsLink', () {
    expect(
      googleMapsLink(const GeoCoordinate(22.8895, 72.5956)),
      'https://www.google.com/maps/search/?api=1&query=22.8895,72.5956',
    );
  });

  group('share text', () {
    test('excerpt keeps short text and cuts long text at a word', () {
      expect(excerpt('  Short   text  '), 'Short text');
      final String long = List<String>.filled(100, 'mahima').join(' ');
      final String cut = excerpt(long, maxLength: 40);
      expect(cut.length, lessThanOrEqualTo(41));
      expect(cut.endsWith('mahima…'), isTrue);
    });

    test('joins header, body and link, skipping empty parts', () {
      expect(
        buildPlaceShareText(
          header: 'Jay Shree Swaminarayan! Dev Sarovar',
          body: 'Shreeji bathed here.',
          link: 'https://maps.example/x',
        ),
        'Jay Shree Swaminarayan! Dev Sarovar\n\n'
        'Shreeji bathed here.\n\n'
        'https://maps.example/x',
      );
      expect(buildPlaceShareText(header: 'Header', body: '  '), 'Header');
    });
  });
}
