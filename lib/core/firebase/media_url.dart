import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'firebase_providers.dart';

/// Resolves media references stored in Firestore into downloadable HTTPS URLs.
///
/// Admins may paste any of:
///  * a full `https://` URL (Storage download URL, YouTube thumbnail, CDN…)
///  * a `gs://bucket/path/file.jpg` URL copied from the Storage console
///  * a bare Storage path such as `gallery/avsar-200/photo1.jpg`
///
/// Firebase Storage is only touched for `gs://` URLs and Storage paths, so
/// direct `https://` media keeps working even if Firebase failed to start.
class MediaUrlResolver {
  MediaUrlResolver(FirebaseStorage Function() storage) : _storage = storage;

  final FirebaseStorage Function() _storage;
  final Map<String, Future<String>> _cache = <String, Future<String>>{};

  /// True when [raw] can be used directly without a Storage lookup.
  static bool isDirect(String raw) =>
      raw.startsWith('https://') || raw.startsWith('http://');

  Future<String> resolve(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return Future<String>.error(ArgumentError('empty url'));
    if (isDirect(value)) return Future<String>.value(value);
    return _cache[value] ??= _lookup(value);
  }

  Future<String> _lookup(String value) async {
    try {
      final FirebaseStorage storage = _storage();
      final Reference ref = value.startsWith('gs://')
          ? storage.refFromURL(value)
          : storage.ref(value.startsWith('/') ? value.substring(1) : value);
      return await ref.getDownloadURL();
    } catch (_) {
      // Allow a later retry instead of caching the failure forever.
      scheduleMicrotask(() => _cache.remove(value));
      rethrow;
    }
  }
}

final Provider<MediaUrlResolver> mediaUrlResolverProvider =
    Provider<MediaUrlResolver>(
      (Ref ref) => MediaUrlResolver(() => ref.read(firebaseStorageProvider)),
    );

/// Resolved HTTPS URL for a media reference. Cached for the app session.
final FutureProviderFamily<String, String> mediaUrlProvider =
    FutureProvider.family<String, String>(
      (Ref ref, String raw) => ref.watch(mediaUrlResolverProvider).resolve(raw),
    );
