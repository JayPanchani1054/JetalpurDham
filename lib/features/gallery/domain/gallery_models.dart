import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/models/localized_text.dart';

/// A photo album (`albums/{albumId}`), e.g. the "Avsar 200" utsav album.
///
/// Every field is optional: albums are created automatically when photos are
/// uploaded to Storage and edited by hand in the Firebase console.
@immutable
class Album {
  const Album({
    required this.id,
    this.title = const LocalizedText.empty(),
    this.description = const LocalizedText.empty(),
    this.coverUrl,
    this.eventDate,
    this.order,
    this.isActive = true,
    this.isFeatured = false,
    this.photoCount,
  });

  /// Parses a Firestore document. Never throws on missing or wrong-typed
  /// fields.
  factory Album.fromMap(String id, Map<String, Object?> map) {
    final int? count = Fs.integerOrNull(map['photoCount']);
    return Album(
      id: id,
      title: LocalizedText.fromValue(map['title']),
      description: LocalizedText.fromValue(map['description']),
      coverUrl: Fs.stringOrNull(map['coverUrl']),
      eventDate: Fs.dateTime(map['eventDate']),
      order: Fs.integerOrNull(map['order']),
      isActive: Fs.boolean(map['isActive'], fallback: true),
      isFeatured: Fs.boolean(map['isFeatured'], fallback: false),
      photoCount: count == null ? null : (count < 0 ? 0 : count),
    );
  }

  final String id;
  final LocalizedText title;
  final LocalizedText description;

  /// Media reference (https, gs:// or Storage path) of the cover photo.
  final String? coverUrl;
  final DateTime? eventDate;
  final int? order;
  final bool isActive;
  final bool isFeatured;

  /// Maintained by Cloud Functions; null when unknown.
  final int? photoCount;

  /// Title in [languageCode], falling back to a readable form of the id
  /// ("avsar-200" → "Avsar 200") so an album never shows a blank title.
  String titleFor(String languageCode) {
    final String text = title.resolve(languageCode);
    return text.isNotEmpty ? text : humanizeAlbumId(id);
  }

  @override
  bool operator ==(Object other) =>
      other is Album &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.coverUrl == coverUrl &&
      other.eventDate == eventDate &&
      other.order == order &&
      other.isActive == isActive &&
      other.isFeatured == isFeatured &&
      other.photoCount == photoCount;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    coverUrl,
    eventDate,
    order,
    isActive,
    isFeatured,
    photoCount,
  );

  @override
  String toString() => 'Album($id)';
}

/// One photo of an album (`albums/{albumId}/photos/{photoId}`).
@immutable
class AlbumPhoto {
  const AlbumPhoto({
    required this.id,
    required this.url,
    this.thumbUrl,
    this.caption = const LocalizedText.empty(),
    this.order,
    this.width,
    this.height,
    this.createdAt,
    this.isActive = true,
  });

  factory AlbumPhoto.fromMap(String id, Map<String, Object?> map) {
    final int? width = Fs.integerOrNull(map['width']);
    final int? height = Fs.integerOrNull(map['height']);
    return AlbumPhoto(
      id: id,
      url: Fs.string(map['url']),
      thumbUrl: Fs.stringOrNull(map['thumbUrl']),
      caption: LocalizedText.fromValue(map['caption']),
      order: Fs.integerOrNull(map['order']),
      width: width != null && width > 0 ? width : null,
      height: height != null && height > 0 ? height : null,
      createdAt: Fs.dateTime(map['createdAt']),
      isActive: Fs.boolean(map['isActive'], fallback: true),
    );
  }

  final String id;

  /// Full-size image (media reference).
  final String url;

  /// Optional small version used in grids.
  final String? thumbUrl;
  final LocalizedText caption;
  final int? order;
  final int? width;
  final int? height;
  final DateTime? createdAt;
  final bool isActive;

  /// False for documents without an image (nothing to show).
  bool get hasImage => url.isNotEmpty;

  /// Best image for small previews: the thumbnail when there is one.
  String get previewUrl => thumbUrl ?? url;

  @override
  bool operator ==(Object other) =>
      other is AlbumPhoto &&
      other.id == id &&
      other.url == url &&
      other.thumbUrl == thumbUrl &&
      other.caption == caption &&
      other.order == order &&
      other.width == width &&
      other.height == height &&
      other.createdAt == createdAt &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(
    id,
    url,
    thumbUrl,
    caption,
    order,
    width,
    height,
    createdAt,
    isActive,
  );

  @override
  String toString() => 'AlbumPhoto($id)';
}

/// A live list read from Firestore together with where it came from.
///
/// An empty list served only from the offline cache means "not downloaded
/// yet" (the device is offline), not "nothing here", so screens can show the
/// right message.
@immutable
class LiveList<T> {
  const LiveList(this.items, {this.isFromCache = false});

  final List<T> items;
  final bool isFromCache;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;

  /// Nothing cached yet and the server could not be reached.
  bool get isUnavailableOffline => items.isEmpty && isFromCache;

  @override
  bool operator ==(Object other) =>
      other is LiveList<T> &&
      other.isFromCache == isFromCache &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(isFromCache, Object.hashAll(items));
}

/// Result of reading one album document.
@immutable
class AlbumLookup {
  const AlbumLookup(this.album, {this.isFromCache = false});

  /// The album (also when hidden with `isActive: false`), or null when the
  /// document does not exist.
  final Album? album;

  /// True when the answer came from the offline cache only.
  final bool isFromCache;

  bool get exists => album != null;

  @override
  bool operator ==(Object other) =>
      other is AlbumLookup &&
      other.album == album &&
      other.isFromCache == isFromCache;

  @override
  int get hashCode => Object.hash(album, isFromCache);
}

/// "avsar-200" → "Avsar 200", "diwali_2025" → "Diwali 2025".
String humanizeAlbumId(String id) {
  final Iterable<String> words = id
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .split(' ')
      .where((String w) => w.isNotEmpty);
  return words
      .map(
        (String w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1)}',
      )
      .join(' ');
}
