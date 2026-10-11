import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/models/localized_text.dart';

/// A kirtan category (`kirtan_categories/{id}`), e.g. Aarti, Dhun, Prabhatiya.
@immutable
class KirtanCategory {
  const KirtanCategory({
    required this.id,
    required this.name,
    this.order,
    this.isActive = true,
    this.imageUrl,
  });

  /// Parses a Firestore document. Never throws.
  factory KirtanCategory.fromMap(String id, Map<String, Object?> map) {
    final LocalizedText name = LocalizedText.fromValue(map['name']);
    return KirtanCategory(
      id: id,
      name: name.isEmpty ? LocalizedText.single(id) : name,
      order: Fs.integerOrNull(map['order']),
      isActive: Fs.boolean(map['isActive'], fallback: true),
      imageUrl: Fs.stringOrNull(map['imageUrl']),
    );
  }

  final String id;
  final LocalizedText name;
  final int? order;
  final bool isActive;
  final String? imageUrl;

  /// Sort: ascending `order` (missing last), then English name, then id.
  static int compare(KirtanCategory a, KirtanCategory b) {
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
      other is KirtanCategory &&
      other.id == id &&
      other.name == name &&
      other.order == order &&
      other.isActive == isActive &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(id, name, order, isActive, imageUrl);
}

/// One kirtan (`kirtans/{id}`). See docs/DATA_MODEL.md.
@immutable
class Kirtan {
  const Kirtan({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.poet = const LocalizedText.empty(),
    this.singer = const LocalizedText.empty(),
    this.categoryId,
    this.durationSec,
    this.sizeBytes,
    this.lyrics = const LocalizedText.empty(),
    this.coverUrl,
    this.order,
    this.isActive = true,
    this.isFeatured = false,
    this.createdAt,
  });

  /// Parses a Firestore document (or an entry of the offline downloads index,
  /// which uses the same shape). Tolerates missing and wrongly typed fields.
  factory Kirtan.fromMap(String id, Map<String, Object?> map) {
    final String audioUrl = Fs.string(map['audioUrl']);
    final LocalizedText title = LocalizedText.fromValue(map['title']);
    final String fallbackTitle = kirtanTitleFromAudioRef(audioUrl);
    return Kirtan(
      id: id,
      title: title.isNotEmpty
          ? title
          : LocalizedText.single(fallbackTitle.isEmpty ? id : fallbackTitle),
      audioUrl: audioUrl,
      poet: LocalizedText.fromValue(map['poet']),
      singer: LocalizedText.fromValue(map['singer']),
      categoryId: Fs.stringOrNull(map['categoryId']),
      durationSec: parseKirtanDurationSeconds(map['durationSec']),
      sizeBytes: _positiveOrNull(Fs.integerOrNull(map['sizeBytes'])),
      lyrics: LocalizedText.fromValue(map['lyrics']),
      coverUrl: Fs.stringOrNull(map['coverUrl']),
      order: Fs.integerOrNull(map['order']),
      isActive: Fs.boolean(map['isActive'], fallback: true),
      isFeatured: Fs.boolean(map['isFeatured'], fallback: false),
      createdAt: Fs.dateTime(map['createdAt']),
    );
  }

  final String id;
  final LocalizedText title;

  /// Rachayita, e.g. Premanand Swami.
  final LocalizedText poet;
  final LocalizedText singer;
  final String? categoryId;

  /// Media reference: https URL, `gs://` URL or a Storage path.
  final String audioUrl;
  final int? durationSec;
  final int? sizeBytes;
  final LocalizedText lyrics;
  final String? coverUrl;
  final int? order;
  final bool isActive;
  final bool isFeatured;
  final DateTime? createdAt;

  /// True when the item can be offered for playback.
  bool get isPlayable => audioUrl.isNotEmpty;

  Duration? get duration =>
      durationSec == null ? null : Duration(seconds: durationSec!);

  /// Poet if known, otherwise the singer.
  LocalizedText get artist => poet.isNotEmpty ? poet : singer;

  /// `poet · singer` (skipping empty or identical parts) in [languageCode].
  String credits(String languageCode) {
    final String p = poet.resolve(languageCode);
    final String s = singer.resolve(languageCode);
    if (p.isEmpty) return s;
    if (s.isEmpty || s == p) return p;
    return '$p · $s';
  }

  /// True if title, poet or singer contains [query] in any language.
  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    return title.matches(query) || poet.matches(query) || singer.matches(query);
  }

  /// JSON-safe map used by the offline downloads index. Round-trips through
  /// [Kirtan.fromMap].
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title.toMap(),
    'poet': poet.toMap(),
    'singer': singer.toMap(),
    'categoryId': categoryId,
    'audioUrl': audioUrl,
    'durationSec': durationSec,
    'sizeBytes': sizeBytes,
    'lyrics': lyrics.toMap(),
    'coverUrl': coverUrl,
    'order': order,
    'isActive': isActive,
    'isFeatured': isFeatured,
    'createdAt': createdAt?.millisecondsSinceEpoch,
  };

  /// Sort: ascending `order` (missing last), then English title, then id.
  static int compare(Kirtan a, Kirtan b) {
    final int byOrder = compareByOrder(a.order, b.order);
    if (byOrder != 0) return byOrder;
    final int byTitle = a.title
        .resolve('en')
        .toLowerCase()
        .compareTo(b.title.resolve('en').toLowerCase());
    return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
  }

  @override
  bool operator ==(Object other) =>
      other is Kirtan &&
      other.id == id &&
      other.title == title &&
      other.poet == poet &&
      other.singer == singer &&
      other.categoryId == categoryId &&
      other.audioUrl == audioUrl &&
      other.durationSec == durationSec &&
      other.sizeBytes == sizeBytes &&
      other.lyrics == lyrics &&
      other.coverUrl == coverUrl &&
      other.order == order &&
      other.isActive == isActive &&
      other.isFeatured == isFeatured &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    poet,
    singer,
    categoryId,
    audioUrl,
    durationSec,
    sizeBytes,
    lyrics,
    coverUrl,
    order,
    isActive,
    isFeatured,
    createdAt,
  );

  @override
  String toString() => 'Kirtan($id, ${title.resolve('en')})';
}

int? _positiveOrNull(int? value) => value != null && value > 0 ? value : null;

/// Parses a duration typed by hand in the console: a number of seconds
/// (`275`, `275.4`, `"275"`) or a clock string (`"4:35"`, `"1:02:45"`).
/// Returns null for anything missing, invalid or not positive.
int? parseKirtanDurationSeconds(Object? value) {
  if (value is num) {
    return value > 0 && value.isFinite ? value.round() : null;
  }
  if (value is! String) return null;
  final String text = value.trim();
  if (text.isEmpty) return null;
  if (text.contains(':')) {
    final List<String> parts = text.split(':');
    if (parts.length > 3) return null;
    int total = 0;
    for (final String part in parts) {
      final int? n = int.tryParse(part.trim());
      if (n == null || n < 0) return null;
      total = total * 60 + n;
    }
    return total > 0 ? total : null;
  }
  final double? seconds = double.tryParse(text);
  return seconds != null && seconds > 0 && seconds.isFinite
      ? seconds.round()
      : null;
}

const Set<String> _audioExtensions = <String>{
  '.mp3',
  '.m4a',
  '.aac',
  '.mp4',
  '.ogg',
  '.oga',
  '.opus',
  '.wav',
  '.flac',
};

/// File extension (with the dot, lower case) of an audio media reference,
/// e.g. `.m4a` for `kirtans/aarti/jay-sadguru.m4a` or a Firebase download URL.
/// Falls back to `.mp3` for anything unknown.
String kirtanAudioExtension(String audioRef) {
  final String name = _lastPathSegment(audioRef);
  final int dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '.mp3';
  final String ext = name.substring(dot).toLowerCase();
  return _audioExtensions.contains(ext) ? ext : '.mp3';
}

/// Human title derived from a file name, used when an auto-created document
/// has no title yet: `kirtans/aarti/Jay_Sadguru-Swami.mp3` → `Jay Sadguru Swami`.
String kirtanTitleFromAudioRef(String audioRef) {
  String name = _lastPathSegment(audioRef);
  final int dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  return name
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Last path segment of an https/gs URL or a Storage path, percent-decoded
/// (Firebase download URLs encode the object path as `kirtans%2Fa%2Fb.mp3`).
String _lastPathSegment(String ref) {
  String path = ref.trim();
  if (path.isEmpty) return '';
  final Uri? uri = Uri.tryParse(path);
  if (uri != null && uri.hasScheme) path = uri.path;
  try {
    path = Uri.decodeComponent(path);
  } catch (_) {
    // Malformed escapes: keep the raw text.
  }
  final int slash = path.lastIndexOf('/');
  return slash >= 0 ? path.substring(slash + 1) : path;
}
