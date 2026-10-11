import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/gallery_models.dart';
import '../domain/gallery_queries.dart';

/// Live gallery data from Firestore. Everything is read with `snapshots()`
/// so changes made in the Firebase console appear instantly and the offline
/// cache serves previously opened albums without internet.
///
/// No server-side ordering or filtering: a missing field can never hide an
/// album or photo and no composite index is needed. Metadata changes are
/// included so an empty list read from the cache (offline) is replaced as
/// soon as the server answers, even when the answer is the same.

/// Every active album, featured first (see [compareAlbums]).
final StreamProvider<LiveList<Album>> albumsProvider =
    StreamProvider<LiveList<Album>>((Ref ref) {
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.albums)
          .snapshots(includeMetadataChanges: true)
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => LiveList<Album>(
              sortActiveAlbums(
                parseAlbumDocuments(
                  snapshot.docs.map(
                    (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                        MapEntry<String, Map<String, Object?>>(
                          doc.id,
                          doc.data(),
                        ),
                  ),
                ),
              ),
              isFromCache: snapshot.metadata.isFromCache,
            ),
          )
          .distinct();
    });

/// One album document by id (also when hidden, so screens can tell
/// "removed" from "offline").
final StreamProviderFamily<AlbumLookup, String> albumLookupProvider =
    StreamProvider.autoDispose.family<AlbumLookup, String>((
      Ref ref,
      String albumId,
    ) {
      _keepAliveBriefly(ref);
      final String id = albumId.trim();
      // A Firestore document id can never be empty or contain '/'.
      if (!_isValidId(id)) {
        return Stream<AlbumLookup>.value(const AlbumLookup(null));
      }
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.albums)
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
            final Map<String, dynamic>? data = snapshot.data();
            if (!snapshot.exists || data == null) {
              return AlbumLookup(
                null,
                isFromCache: snapshot.metadata.isFromCache,
              );
            }
            return AlbumLookup(
              Album.fromMap(snapshot.id, data),
              isFromCache: snapshot.metadata.isFromCache,
            );
          })
          .distinct();
    });

/// Visible photos of an album, sorted (see [comparePhotos]). Albums may hold
/// hundreds of photos; parsing and sorting them is cheap and done once per
/// change.
final StreamProviderFamily<LiveList<AlbumPhoto>, String> albumPhotosProvider =
    StreamProvider.autoDispose.family<LiveList<AlbumPhoto>, String>((
      Ref ref,
      String albumId,
    ) {
      _keepAliveBriefly(ref);
      final String id = albumId.trim();
      if (!_isValidId(id)) {
        return Stream<LiveList<AlbumPhoto>>.value(
          const LiveList<AlbumPhoto>(<AlbumPhoto>[]),
        );
      }
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.albums)
          .doc(id)
          .collection(FirestorePaths.photos)
          .snapshots(includeMetadataChanges: true)
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                LiveList<AlbumPhoto>(
                  sortVisiblePhotos(
                    parsePhotoDocuments(
                      snapshot.docs.map(
                        (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                            MapEntry<String, Map<String, Object?>>(
                              doc.id,
                              doc.data(),
                            ),
                      ),
                    ),
                  ),
                  isFromCache: snapshot.metadata.isFromCache,
                ),
          )
          .distinct();
    });

/// Parses `id → data` album documents, skipping malformed ones.
List<Album> parseAlbumDocuments(
  Iterable<MapEntry<String, Map<String, Object?>>> documents,
) => _parseAll(documents, Album.fromMap, 'album');

/// Parses `id → data` photo documents, skipping malformed ones.
List<AlbumPhoto> parsePhotoDocuments(
  Iterable<MapEntry<String, Map<String, Object?>>> documents,
) => _parseAll(documents, AlbumPhoto.fromMap, 'photo');

List<T> _parseAll<T>(
  Iterable<MapEntry<String, Map<String, Object?>>> documents,
  T Function(String id, Map<String, Object?> data) parse,
  String label,
) {
  final List<T> items = <T>[];
  for (final MapEntry<String, Map<String, Object?>> doc in documents) {
    try {
      items.add(parse(doc.key, doc.value));
    } catch (error, stack) {
      // One malformed document must never hide the rest of the list.
      AppLogger.error('Skipping malformed $label ${doc.key}', error, stack);
    }
  }
  return items;
}

bool _isValidId(String id) => id.isNotEmpty && !id.contains('/');

/// Keeps an album's listener open for a short while after the last screen
/// leaves, so going back and forth (album ↔ photo ↔ home) is instant and
/// does not re-download anything.
void _keepAliveBriefly(Ref ref) {
  final KeepAliveLink link = ref.keepAlive();
  Timer? timer;
  ref
    ..onCancel(() {
      timer?.cancel();
      timer = Timer(const Duration(minutes: 3), link.close);
    })
    ..onResume(() => timer?.cancel())
    ..onDispose(() => timer?.cancel());
}
