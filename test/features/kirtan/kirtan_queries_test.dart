import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/kirtan/domain/kirtan.dart';
import 'package:jetalpur_dham/features/kirtan/domain/kirtan_queries.dart';

Kirtan _k(
  String id, {
  String? title,
  int? order,
  String? category,
  bool active = true,
  bool featured = false,
  String audio = 'a.mp3',
  String? poet,
  String? gu,
}) => Kirtan.fromMap(id, <String, Object?>{
  'title': <String, Object?>{'en': title ?? id, 'gu': ?gu},
  'order': order,
  'categoryId': category,
  'isActive': active,
  'isFeatured': featured,
  'audioUrl': audio,
  'poet': poet,
});

List<String> _ids(List<Kirtan> list) => list.map((Kirtan k) => k.id).toList();

void main() {
  group('sortActiveKirtans', () {
    test('sorts by order, then title; drops inactive and unplayable', () {
      final List<Kirtan> sorted = sortActiveKirtans(<Kirtan>[
        _k('c', title: 'Zulan', order: 2),
        _k('d', title: 'Aarti'),
        _k('a', title: 'Mangla', order: 1),
        _k('e', title: 'Bhajan'),
        _k('hidden', order: 0, active: false),
        _k('silent', order: 0, audio: ''),
        _k('b', title: 'Abhishek', order: 2),
      ]);
      expect(_ids(sorted), <String>['a', 'b', 'c', 'd', 'e']);
      expect(() => sorted.add(_k('x')), throwsUnsupportedError);
    });
  });

  group('sortActiveCategories', () {
    test('keeps active categories in order', () {
      final List<KirtanCategory> sorted = sortActiveCategories(<KirtanCategory>[
        KirtanCategory.fromMap('dhun', <String, Object?>{'order': 2}),
        KirtanCategory.fromMap('off', <String, Object?>{'isActive': false}),
        KirtanCategory.fromMap('aarti', <String, Object?>{'order': 1}),
      ]);
      expect(sorted.map((KirtanCategory c) => c.id), <String>['aarti', 'dhun']);
    });
  });

  group('selectFeaturedKirtans', () {
    test('returns only featured kirtans when any are marked', () {
      final List<Kirtan> list = <Kirtan>[
        _k('a'),
        _k('b', featured: true),
        _k('c'),
        _k('d', featured: true),
      ];
      expect(_ids(selectFeaturedKirtans(list)), <String>['b', 'd']);
    });

    test('falls back to the first 8 kirtans', () {
      final List<Kirtan> list = <Kirtan>[
        for (int i = 0; i < 12; i++) _k('k$i'),
      ];
      expect(selectFeaturedKirtans(list), hasLength(8));
      expect(selectFeaturedKirtans(list).first.id, 'k0');
      expect(selectFeaturedKirtans(list.take(3).toList()), hasLength(3));
      expect(selectFeaturedKirtans(const <Kirtan>[]), isEmpty);
    });
  });

  group('filterKirtans', () {
    final List<Kirtan> all = <Kirtan>[
      _k('1', title: 'Jay Sadguru Swami', category: 'aarti', gu: 'જય સદગુરુ'),
      _k('2', title: 'Swaminarayan Dhun', category: 'dhun'),
      _k('3', title: 'Prem Sakhi', category: 'pad', poet: 'Premanand Swami'),
    ];

    test('returns the same list when nothing is filtered', () {
      expect(identical(filterKirtans(all), all), isTrue);
      expect(identical(filterKirtans(all, query: '  '), all), isTrue);
    });

    test('matches title, poet and other languages', () {
      // "Swaminarayan" contains "swami", so all three match.
      expect(_ids(filterKirtans(all, query: 'swami')), <String>['1', '2', '3']);
      expect(_ids(filterKirtans(all, query: 'SAKHI')), <String>['3']);
      expect(_ids(filterKirtans(all, query: 'સદગુરુ')), <String>['1']);
      expect(_ids(filterKirtans(all, query: 'premanand')), <String>['3']);
      expect(filterKirtans(all, query: 'nothing'), isEmpty);
    });

    test('filters by category and combines with the query', () {
      expect(_ids(filterKirtans(all, categoryId: 'dhun')), <String>['2']);
      expect(filterKirtans(all, query: 'prem', categoryId: 'dhun'), isEmpty);
    });
  });

  test('categoriesInUse keeps only categories with kirtans', () {
    final List<KirtanCategory> categories = <KirtanCategory>[
      KirtanCategory.fromMap('aarti', const <String, Object?>{}),
      KirtanCategory.fromMap('empty', const <String, Object?>{}),
      KirtanCategory.fromMap('dhun', const <String, Object?>{}),
    ];
    final List<KirtanCategory> used = categoriesInUse(categories, <Kirtan>[
      _k('1', category: 'dhun'),
      _k('2', category: 'aarti'),
      _k('3'),
    ]);
    expect(used.map((KirtanCategory c) => c.id), <String>['aarti', 'dhun']);
  });

  group('resolveStartIndex', () {
    final List<Kirtan> original = <Kirtan>[_k('a'), _k('b'), _k('c'), _k('d')];

    test('maps the requested kirtan into the playable list', () {
      expect(
        resolveStartIndex(
          original: original,
          startIndex: 2,
          playable: <Kirtan>[original[0], original[2]],
          strict: true,
        ),
        1,
      );
    });

    test('strict start fails when the tapped kirtan is unavailable', () {
      expect(
        resolveStartIndex(
          original: original,
          startIndex: 1,
          playable: <Kirtan>[original[0], original[2]],
          strict: true,
        ),
        isNull,
      );
    });

    test('non-strict start moves forward and wraps around', () {
      expect(
        resolveStartIndex(
          original: original,
          startIndex: 1,
          playable: <Kirtan>[original[0], original[2]],
          strict: false,
        ),
        1,
      );
      expect(
        resolveStartIndex(
          original: original,
          startIndex: 3,
          playable: <Kirtan>[original[0]],
          strict: false,
        ),
        0,
      );
    });

    test('handles empty lists and out-of-range indexes', () {
      expect(
        resolveStartIndex(
          original: original,
          startIndex: 0,
          playable: const <Kirtan>[],
          strict: false,
        ),
        isNull,
      );
      expect(
        resolveStartIndex(
          original: original,
          startIndex: 99,
          playable: original,
          strict: true,
        ),
        3,
      );
    });
  });

  group('upcomingQueueOrder', () {
    test('starts at the current item', () {
      expect(upcomingQueueOrder(<int>[3, 0, 2, 1], 2, wrap: false), <int>[
        2,
        1,
      ]);
    });

    test('wraps around with repeat all', () {
      expect(upcomingQueueOrder(<int>[3, 0, 2, 1], 2, wrap: true), <int>[
        2,
        1,
        3,
        0,
      ]);
    });

    test('falls back to the current item when it is not in the order', () {
      expect(upcomingQueueOrder(<int>[0, 1], 5, wrap: true), <int>[5]);
    });
  });
}
