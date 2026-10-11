import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'prasadi_place.dart';

/// Active places in display order. Inactive ones are hidden on the device so
/// no Firestore index or server-side filter is needed.
List<PrasadiPlace> sortActivePlaces(Iterable<PrasadiPlace> places) =>
    places.where((PrasadiPlace p) => p.isActive).toList(growable: false)
      ..sort(PrasadiPlace.compare);

PrasadiPlace? findPlace(Iterable<PrasadiPlace> places, String id) {
  for (final PrasadiPlace place in places) {
    if (place.id == id) return place;
  }
  return null;
}

/// Clamps a requested panorama index into range (0 when there are none).
int clampPanoramaIndex(int requested, int count) =>
    count <= 0 ? 0 : requested.clamp(0, count - 1);

/// Axis-aligned bounding box around a set of coordinates.
@immutable
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// Null when [points] is empty.
  static GeoBounds? around(Iterable<GeoCoordinate> points) {
    double? south, west, north, east;
    for (final GeoCoordinate p in points) {
      south = south == null ? p.latitude : math.min(south, p.latitude);
      north = north == null ? p.latitude : math.max(north, p.latitude);
      west = west == null ? p.longitude : math.min(west, p.longitude);
      east = east == null ? p.longitude : math.max(east, p.longitude);
    }
    if (south == null || west == null || north == null || east == null) {
      return null;
    }
    return GeoBounds(south: south, west: west, north: north, east: east);
  }

  final double south;
  final double west;
  final double north;
  final double east;

  GeoCoordinate get center =>
      GeoCoordinate((south + north) / 2, (west + east) / 2);

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}

/// Google Maps zoom level that fits [bounds] into a map of [width] × [height]
/// logical pixels, keeping [padding] free on every side.
///
/// Computed on the device (Web Mercator) so the very first frame of the map
/// already shows every place, without a platform round trip. A single place
/// or places a few metres apart get [maxZoom].
double fitZoom({
  required GeoBounds bounds,
  required double width,
  required double height,
  double padding = 48,
  double minZoom = 3,
  double maxZoom = 17,
}) {
  final double w = math.max(1, width - 2 * padding);
  final double h = math.max(1, height - 2 * padding);

  double mercatorY(double latitude) {
    final double s = math.sin(latitude * math.pi / 180);
    final double r = math.log((1 + s) / (1 - s)) / 2;
    return math.max(math.min(r, math.pi), -math.pi) / 2;
  }

  double zoomFor(double pixels, double fraction) => fraction <= 0
      ? double.infinity
      : math.log(pixels / 256 / fraction) / math.ln2;

  final double latFraction =
      (mercatorY(bounds.north) - mercatorY(bounds.south)) / math.pi;
  final double lngFraction = (bounds.east - bounds.west) / 360;
  final double zoom = math.min(
    zoomFor(h, latFraction),
    zoomFor(w, lngFraction),
  );
  if (zoom.isNaN) return maxZoom;
  return zoom.clamp(minZoom, maxZoom).toDouble();
}

/// Link that opens [at] in Google Maps (app or browser).
String googleMapsLink(GeoCoordinate at) =>
    'https://www.google.com/maps/search/?api=1'
    '&query=${at.latitude},${at.longitude}';

/// The first [maxLength] characters of [text], cut at a word boundary.
String excerpt(String text, {int maxLength = 320}) {
  final String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= maxLength) return clean;
  final String cut = clean.substring(0, maxLength);
  final int space = cut.lastIndexOf(' ');
  return '${(space > maxLength * 0.6 ? cut.substring(0, space) : cut).trimRight()}…';
}

/// Message used by the share button: a greeting with the place name, a short
/// part of the mahima and a Google Maps link. Empty parts are left out.
String buildPlaceShareText({
  required String header,
  String body = '',
  String? link,
}) {
  return <String>[
    header.trim(),
    if (body.trim().isNotEmpty) excerpt(body),
    if (link != null && link.trim().isNotEmpty) link.trim(),
  ].where((String part) => part.isNotEmpty).join('\n\n');
}
