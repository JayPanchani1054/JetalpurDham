import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import 'gallery_models.dart';

/// Pure list logic for the gallery (sorting, filtering, selection). Kept free
/// of Flutter widgets and Firebase so it is easy to unit test.

/// Active albums: featured first, then `order`, then newest `eventDate`,
/// then title/id for a stable result.
List<Album> sortActiveAlbums(Iterable<Album> albums) {
  final List<Album> result = albums.where((Album a) => a.isActive).toList()
    ..sort(compareAlbums);
  return List<Album>.unmodifiable(result);
}

int compareAlbums(Album a, Album b) {
  if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
  final int byOrder = compareByOrder(a.order, b.order);
  if (byOrder != 0) return byOrder;
  final DateTime? da = a.eventDate;
  final DateTime? db = b.eventDate;
  if (da != null && db != null) {
    final int byDate = db.compareTo(da); // newest first
    if (byDate != 0) return byDate;
  } else if (da != null || db != null) {
    return da != null ? -1 : 1; // dated albums before undated ones
  }
  final int byTitle = a
      .titleFor('en')
      .toLowerCase()
      .compareTo(b.titleFor('en').toLowerCase());
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}

/// Visible photos (active and with an image) sorted by `order`, then upload
/// time, then id.
List<AlbumPhoto> sortVisiblePhotos(Iterable<AlbumPhoto> photos) {
  final List<AlbumPhoto> result =
      photos.where((AlbumPhoto p) => p.isActive && p.hasImage).toList()
        ..sort(comparePhotos);
  return List<AlbumPhoto>.unmodifiable(result);
}

int comparePhotos(AlbumPhoto a, AlbumPhoto b) {
  final int byOrder = compareByOrder(a.order, b.order);
  if (byOrder != 0) return byOrder;
  final DateTime? ca = a.createdAt;
  final DateTime? cb = b.createdAt;
  if (ca != null && cb != null) {
    final int byDate = ca.compareTo(cb);
    if (byDate != 0) return byDate;
  } else if (ca != null || cb != null) {
    return ca != null ? -1 : 1;
  }
  return a.id.compareTo(b.id);
}

/// What the album screen should show.
enum AlbumViewStatus {
  /// Show the album (possibly with an "empty" message inside).
  ready,

  /// The album was removed or hidden.
  notFound,

  /// Nothing is cached yet and the device is offline.
  offline,
}

/// Decides the album screen state from the album document and its photos.
///
/// A missing album document with photos still shows the photos (the album
/// title falls back to its id), so content never disappears because a
/// document was not created by hand. A hidden album (`isActive: false`)
/// is never shown.
AlbumViewStatus albumViewStatus(
  AlbumLookup lookup,
  LiveList<AlbumPhoto> photos,
) {
  final Album? album = lookup.album;
  if (album != null) {
    return album.isActive ? AlbumViewStatus.ready : AlbumViewStatus.notFound;
  }
  if (photos.isNotEmpty) return AlbumViewStatus.ready;
  if (lookup.isFromCache || photos.isFromCache) return AlbumViewStatus.offline;
  return AlbumViewStatus.notFound;
}

/// The album to display: the document, or a stand-in built from the id when
/// only photos exist.
Album displayAlbum(String albumId, AlbumLookup lookup) =>
    lookup.album ?? Album(id: albumId);

/// Cover image for an album: its `coverUrl`, else the first photo.
String? albumCoverUrl(Album album, List<AlbumPhoto> photos) =>
    album.coverUrl ?? (photos.isEmpty ? null : photos.first.previewUrl);

/// Keeps only the selected ids that still exist (photos can be removed while
/// the user is selecting).
Set<String> retainExistingSelection(
  Set<String> selected,
  List<AlbumPhoto> photos,
) {
  if (selected.isEmpty) return selected;
  final Set<String> ids = photos.map((AlbumPhoto p) => p.id).toSet();
  return selected.where(ids.contains).toSet();
}

/// Selected photos in album order (saving follows what the user sees).
List<AlbumPhoto> selectedPhotosInOrder(
  List<AlbumPhoto> photos,
  Set<String> selected,
) => photos
    .where((AlbumPhoto p) => selected.contains(p.id))
    .toList(growable: false);

/// Index of [photoId] in [photos], or -1.
int indexOfPhoto(List<AlbumPhoto> photos, String? photoId) {
  if (photoId == null) return -1;
  for (int i = 0; i < photos.length; i++) {
    if (photos[i].id == photoId) return i;
  }
  return -1;
}

/// [index] clamped to a valid position in a list of [length] (0 when empty).
int clampIndex(int index, int length) {
  if (length <= 0) return 0;
  if (index < 0) return 0;
  if (index >= length) return length - 1;
  return index;
}

/// Hero tag shared by a thumbnail and the full-screen photo.
String photoHeroTag(String albumId, String photoId) =>
    'gallery-photo/$albumId/$photoId';

/// Hero tag shared by an album card cover and the album header.
String albumCoverHeroTag(String albumId) => 'gallery-cover/$albumId';

/// File name (without extension) used when saving or sharing a photo, e.g.
/// `JetalpurDham_avsar-200_img-0001`.
String photoFileName(String albumId, String photoId) {
  String clean(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
  final String name = 'JetalpurDham_${clean(albumId)}_${clean(photoId)}';
  return name.length <= 80 ? name : name.substring(0, 80);
}

/// Longest side (in pixels) to decode a full-screen photo at: sharp enough to
/// zoom, but bounded so very large uploads never exhaust memory.
int viewerDecodeSize(double longestSideDp, double devicePixelRatio) {
  final double pixels = longestSideDp * devicePixelRatio * 1.5;
  if (pixels.isNaN || pixels <= 0) return 2048;
  return pixels.round().clamp(1440, 3200);
}

/// Image container types the app can save or share.
enum ImageFileType {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  webp('webp', 'image/webp'),
  gif('gif', 'image/gif'),
  heic('heic', 'image/heic');

  const ImageFileType(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

/// Detects the image type from its first bytes (defaults to JPEG).
ImageFileType sniffImageType(Uint8List bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (int i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const <int>[0xFF, 0xD8, 0xFF])) return ImageFileType.jpeg;
  if (startsWith(const <int>[0x89, 0x50, 0x4E, 0x47])) return ImageFileType.png;
  if (startsWith(const <int>[0x47, 0x49, 0x46, 0x38])) return ImageFileType.gif;
  if (startsWith(const <int>[0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const <int>[0x57, 0x45, 0x42, 0x50], 8)) {
    return ImageFileType.webp;
  }
  // ISO-BMFF ("....ftyp<brand>") used by HEIC/HEIF photos from iPhones.
  if (startsWith(const <int>[0x66, 0x74, 0x79, 0x70], 4) &&
      bytes.length >= 12) {
    final String brand = String.fromCharCodes(bytes.sublist(8, 12));
    const Set<String> heif = <String>{
      'heic',
      'heix',
      'hevc',
      'hevx',
      'heim',
      'heis',
      'mif1',
      'msf1',
    };
    if (heif.contains(brand)) return ImageFileType.heic;
  }
  return ImageFileType.jpeg;
}
