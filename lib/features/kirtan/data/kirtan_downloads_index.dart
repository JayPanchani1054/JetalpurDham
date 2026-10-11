import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/services/download_service.dart';
import '../domain/kirtan.dart';

/// A kirtan saved for offline listening, with everything needed to show and
/// play it without internet.
@immutable
class DownloadedKirtan {
  const DownloadedKirtan({
    required this.kirtan,
    required this.extension,
    this.sizeBytes = 0,
    this.downloadedAt,
  });

  final Kirtan kirtan;

  /// Extension of the local file (`.mp3`), part of its [DownloadKey].
  final String extension;
  final int sizeBytes;
  final DateTime? downloadedAt;

  DownloadKey get key => kirtanDownloadKey(kirtan.id, extension);

  DownloadedKirtan copyWith({Kirtan? kirtan, int? sizeBytes}) =>
      DownloadedKirtan(
        kirtan: kirtan ?? this.kirtan,
        extension: extension,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        downloadedAt: downloadedAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': kirtan.id,
    'kirtan': kirtan.toJson(),
    'ext': extension,
    'bytes': sizeBytes,
    'at': downloadedAt?.millisecondsSinceEpoch,
  };

  /// Returns null for malformed entries instead of throwing.
  static DownloadedKirtan? fromJson(Object? json) {
    final Map<String, Object?> map = Fs.map(json);
    final String id = Fs.string(map['id']);
    if (id.isEmpty) return null;
    final String ext = Fs.string(map['ext']);
    return DownloadedKirtan(
      kirtan: Kirtan.fromMap(id, Fs.map(map['kirtan'])),
      extension: ext.startsWith('.') && ext.length > 1 ? ext : '.mp3',
      sizeBytes: Fs.integer(map['bytes']),
      downloadedAt: Fs.dateTime(map['at']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DownloadedKirtan &&
      other.kirtan == kirtan &&
      other.extension == extension &&
      other.sizeBytes == sizeBytes &&
      other.downloadedAt == downloadedAt;

  @override
  int get hashCode => Object.hash(kirtan, extension, sizeBytes, downloadedAt);
}

/// Offline index of downloaded kirtans, newest first.
@immutable
class KirtanDownloadsIndex {
  KirtanDownloadsIndex(Iterable<DownloadedKirtan> items)
    : items = List<DownloadedKirtan>.unmodifiable(items),
      _byId = <String, DownloadedKirtan>{
        for (final DownloadedKirtan d in items) d.kirtan.id: d,
      };

  static final KirtanDownloadsIndex empty = KirtanDownloadsIndex(
    const <DownloadedKirtan>[],
  );

  final List<DownloadedKirtan> items;
  final Map<String, DownloadedKirtan> _byId;

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  bool contains(String kirtanId) => _byId.containsKey(kirtanId);
  DownloadedKirtan? operator [](String kirtanId) => _byId[kirtanId];

  int get totalBytes =>
      items.fold<int>(0, (int sum, DownloadedKirtan d) => sum + d.sizeBytes);

  /// Adds or replaces [entry], moving it to the top.
  KirtanDownloadsIndex upsert(DownloadedKirtan entry) =>
      KirtanDownloadsIndex(<DownloadedKirtan>[
        entry,
        ...items.where((DownloadedKirtan d) => d.kirtan.id != entry.kirtan.id),
      ]);

  KirtanDownloadsIndex removeWhere(bool Function(DownloadedKirtan d) test) =>
      KirtanDownloadsIndex(items.where((DownloadedKirtan d) => !test(d)));

  String encode() => jsonEncode(<String, Object?>{
    'v': 1,
    'items': items.map((DownloadedKirtan d) => d.toJson()).toList(),
  });

  /// Parses [raw] from SharedPreferences. Corrupt data yields an empty index.
  static KirtanDownloadsIndex decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final Object? json = jsonDecode(raw);
      final Object? list = json is Map ? json['items'] : json;
      if (list is! List) return empty;
      final List<DownloadedKirtan> parsed = <DownloadedKirtan>[];
      final Set<String> seen = <String>{};
      for (final Object? item in list) {
        final DownloadedKirtan? entry = DownloadedKirtan.fromJson(item);
        if (entry != null && seen.add(entry.kirtan.id)) parsed.add(entry);
      }
      return KirtanDownloadsIndex(parsed);
    } catch (_) {
      return empty;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is KirtanDownloadsIndex && listEquals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);
}

/// The offline file for a kirtan: `kirtans/<id><extension>`.
DownloadKey kirtanDownloadKey(String kirtanId, String extension) => DownloadKey(
  folder: DownloadFolders.kirtans,
  id: kirtanId,
  extension: extension,
);
