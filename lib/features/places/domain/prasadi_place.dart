import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/models/localized_text.dart';

/// A latitude/longitude pair that is known to be a real point on Earth.
///
/// Staff type coordinates by hand in the Firebase console, so [tryParse]
/// accepts every reasonable shape and rejects anything out of range (and the
/// `0, 0` placeholder) instead of throwing.
@immutable
class GeoCoordinate {
  const GeoCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  static bool isValid(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);

  /// Parses a Firestore [GeoPoint], a map (`lat`/`lng`, `latitude`/
  /// `longitude` or `_latitude`/`_longitude`), a `[lat, lng]` list or a
  /// `"22.8895, 72.5956"` string copied from Google Maps. Never throws.
  static GeoCoordinate? tryParse(Object? value) {
    double? lat;
    double? lng;
    if (value is GeoPoint) {
      lat = value.latitude;
      lng = value.longitude;
    } else if (value is Map) {
      final Map<String, Object?> map = Fs.map(value);
      lat = Fs.doubleOrNull(map['lat'] ?? map['latitude'] ?? map['_latitude']);
      lng = Fs.doubleOrNull(
        map['lng'] ??
            map['lon'] ??
            map['long'] ??
            map['longitude'] ??
            map['_longitude'],
      );
    } else if (value is List && value.length == 2) {
      lat = Fs.doubleOrNull(value[0]);
      lng = Fs.doubleOrNull(value[1]);
    } else if (value is String) {
      final List<String> parts = value
          .replaceAll(RegExp(r'[()\[\]°]'), ' ')
          .split(RegExp(r'[,;\s]+'))
          .where((String p) => p.isNotEmpty)
          .toList(growable: false);
      if (parts.length == 2) {
        lat = double.tryParse(parts[0]);
        lng = double.tryParse(parts[1]);
      }
    }
    if (lat == null || lng == null || !isValid(lat, lng)) return null;
    return GeoCoordinate(lat, lng);
  }

  @override
  bool operator ==(Object other) =>
      other is GeoCoordinate &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoCoordinate($latitude, $longitude)';
}

/// Kind of prasadi place; decides the icon and the label shown on cards.
enum PlaceCategory {
  temple,
  yagna,
  water,
  tree,
  residence,
  other;

  /// English / transliterated words plus the Gujarati and Hindi words staff
  /// are likely to type in the console.
  static const Map<PlaceCategory, List<String>> _keywords =
      <PlaceCategory, List<String>>{
        PlaceCategory.temple: <String>[
          'temple',
          'mandir',
          'shrine',
          'shiv',
          'મંદિર',
          'મંદીર',
          'मंदिर',
        ],
        PlaceCategory.yagna: <String>[
          'yagna',
          'yajna',
          'yagya',
          'yagn',
          'યજ્ઞ',
          'यज्ञ',
        ],
        PlaceCategory.water: <String>[
          'water',
          'lake',
          'talav',
          'talao',
          'vav',
          'well',
          'kund',
          'sarovar',
          'river',
          'pond',
          'તળાવ',
          'વાવ',
          'કૂવો',
          'કુવો',
          'કુંડ',
          'સરોવર',
          'નદી',
          'तालाब',
          'बावड़ी',
          'कुआँ',
          'कुंड',
          'सरोवर',
          'नदी',
        ],
        PlaceCategory.tree: <String>[
          'tree',
          'vruksh',
          'vriksh',
          'vruksha',
          'વૃક્ષ',
          'ઝાડ',
          'वृक्ष',
          'पेड़',
        ],
        PlaceCategory.residence: <String>[
          'residence',
          'home',
          'house',
          'ordo',
          'ordi',
          'haveli',
          'nivas',
          'room',
          'ઓરડો',
          'ઓરડી',
          'હવેલી',
          'નિવાસ',
          'मकान',
          'हवेली',
          'निवास',
        ],
      };

  /// Parses the `category` field. Exact names win; otherwise a few common
  /// words staff might type (e.g. "Mandir", "Talav") are understood, and
  /// anything else is [other].
  static PlaceCategory fromValue(Object? value) {
    final String v = Fs.string(value).toLowerCase();
    if (v.isEmpty) return PlaceCategory.other;
    for (final PlaceCategory category in PlaceCategory.values) {
      if (category.name == v) return category;
    }
    for (final MapEntry<PlaceCategory, List<String>> entry
        in _keywords.entries) {
      if (entry.value.any(v.contains)) return entry.key;
    }
    return PlaceCategory.other;
  }
}

/// Optional Google Street View viewpoint (`streetView` map on a place).
@immutable
class StreetViewPoint {
  const StreetViewPoint({this.coordinate, this.heading = 0, this.pitch = 0});

  /// Returns null when [value] carries nothing usable.
  static StreetViewPoint? tryParse(Object? value) {
    if (value is! Map) return null;
    final Map<String, Object?> map = Fs.map(value);
    final GeoCoordinate? coordinate = GeoCoordinate.tryParse(map);
    final double? heading = Fs.doubleOrNull(map['heading']);
    final double? pitch = Fs.doubleOrNull(map['pitch']);
    if (coordinate == null && heading == null && pitch == null) return null;
    return StreetViewPoint(
      coordinate: coordinate,
      heading: heading == null || !heading.isFinite
          ? 0
          : ((heading % 360) + 360) % 360,
      pitch: pitch == null || !pitch.isFinite
          ? 0
          : pitch.clamp(-90, 90).toDouble(),
    );
  }

  /// Viewpoint position; the place's own location is used when null.
  final GeoCoordinate? coordinate;

  /// Compass direction the camera faces (0 = north, 90 = east).
  final double heading;

  /// Up/down angle (0 = straight ahead).
  final double pitch;

  @override
  bool operator ==(Object other) =>
      other is StreetViewPoint &&
      other.coordinate == coordinate &&
      other.heading == heading &&
      other.pitch == pitch;

  @override
  int get hashCode => Object.hash(coordinate, heading, pitch);
}

/// Where Street View should open for a place.
typedef StreetViewTarget = ({
  GeoCoordinate coordinate,
  double heading,
  double pitch,
});

/// A prasadi place (`places/{placeId}`): a sacred place touched by Shree
/// Swaminarayan Bhagwan. See docs/DATA_MODEL.md.
@immutable
class PrasadiPlace {
  const PrasadiPlace({
    required this.id,
    required this.name,
    this.shortDescription = const LocalizedText.empty(),
    this.mahima = const LocalizedText.empty(),
    this.address = const LocalizedText.empty(),
    this.location,
    this.category = PlaceCategory.other,
    this.images = const <String>[],
    this.panoramaUrls = const <String>[],
    this.streetView,
    this.order,
    this.isActive = true,
  });

  /// Parses a Firestore document. Tolerates missing and wrongly typed fields
  /// and never throws.
  factory PrasadiPlace.fromMap(String id, Map<String, Object?> map) {
    final LocalizedText name = LocalizedText.fromValue(map['name']);
    List<String> images = _mediaList(map['images']);
    if (images.isEmpty) {
      images = _mediaList(map['imageUrl'] ?? map['coverUrl'] ?? map['image']);
    }
    List<String> panoramas = _mediaList(map['panoramaUrls']);
    if (panoramas.isEmpty) {
      panoramas = _mediaList(map['panoramas'] ?? map['panoramaUrl']);
    }
    return PrasadiPlace(
      id: id,
      name: name.isEmpty ? LocalizedText.single(humanizeId(id)) : name,
      shortDescription: LocalizedText.fromValue(map['shortDescription']),
      mahima: normalizeLongText(LocalizedText.fromValue(map['mahima'])),
      address: LocalizedText.fromValue(map['address']),
      location:
          GeoCoordinate.tryParse(map['location']) ??
          GeoCoordinate.tryParse(map),
      category: PlaceCategory.fromValue(map['category']),
      images: images,
      panoramaUrls: panoramas,
      streetView: StreetViewPoint.tryParse(map['streetView']),
      order: Fs.integerOrNull(map['order']),
      isActive: Fs.boolean(map['isActive'], fallback: true),
    );
  }

  final String id;
  final LocalizedText name;
  final LocalizedText shortDescription;

  /// The greatness / story of the place (long text).
  final LocalizedText mahima;
  final LocalizedText address;
  final GeoCoordinate? location;
  final PlaceCategory category;

  /// Photos (media references); the first one is the cover.
  final List<String> images;

  /// 360° equirectangular photos (media references).
  final List<String> panoramaUrls;
  final StreetViewPoint? streetView;
  final int? order;
  final bool isActive;

  String? get coverImage => images.isEmpty ? null : images.first;
  bool get hasLocation => location != null;
  bool get hasPanorama => panoramaUrls.isNotEmpty;

  /// Street View viewpoint: the explicit `streetView` override, else the
  /// place's own location. Null when neither is known.
  StreetViewTarget? get streetViewTarget {
    final GeoCoordinate? at = streetView?.coordinate ?? location;
    if (at == null) return null;
    return (
      coordinate: at,
      heading: streetView?.heading ?? 0,
      pitch: streetView?.pitch ?? 0,
    );
  }

  /// Ascending `order` (missing last), then English name, then id.
  static int compare(PrasadiPlace a, PrasadiPlace b) {
    final int byOrder = compareByOrder(a.order, b.order);
    if (byOrder != 0) return byOrder;
    final int byName = a.name
        .resolve('en')
        .toLowerCase()
        .compareTo(b.name.resolve('en').toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  @override
  bool operator ==(Object other) =>
      other is PrasadiPlace &&
      other.id == id &&
      other.name == name &&
      other.shortDescription == shortDescription &&
      other.mahima == mahima &&
      other.address == address &&
      other.location == location &&
      other.category == category &&
      listEquals(other.images, images) &&
      listEquals(other.panoramaUrls, panoramaUrls) &&
      other.streetView == streetView &&
      other.order == order &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    shortDescription,
    mahima,
    address,
    location,
    category,
    Object.hashAll(images),
    Object.hashAll(panoramaUrls),
    streetView,
    order,
    isActive,
  );

  @override
  String toString() => 'PrasadiPlace($id)';
}

/// Media references from a list of strings (or `{url: ...}` maps) or a
/// single string. Blank entries are dropped.
List<String> _mediaList(Object? value) {
  if (value is String) {
    final String v = value.trim();
    return v.isEmpty ? const <String>[] : <String>[v];
  }
  if (value is! List) return const <String>[];
  final List<String> result = <String>[];
  for (final Object? item in value) {
    final String? ref = item is Map
        ? Fs.stringOrNull(Fs.map(item)['url'] ?? Fs.map(item)['src'])
        : (item is String ? Fs.stringOrNull(item) : null);
    if (ref != null) result.add(ref);
  }
  return List<String>.unmodifiable(result);
}

/// `dev-sarovar` → `Dev Sarovar`; used only when a place has no name yet.
@visibleForTesting
String humanizeId(String id) => id
    .split(RegExp(r'[-_\s]+'))
    .where((String w) => w.isNotEmpty)
    .map((String w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Long texts typed in the console may contain literal `\n` sequences or
/// Windows line breaks; turn them into real paragraphs.
@visibleForTesting
LocalizedText normalizeLongText(LocalizedText text) {
  if (text.isEmpty) return text;
  return LocalizedText(<String, String>{
    for (final MapEntry<String, String> e in text.values.entries)
      e.key: e.value
          .replaceAll(r'\n', '\n')
          .replaceAll('\r\n', '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim(),
  });
}
