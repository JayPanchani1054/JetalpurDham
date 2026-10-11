import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/place_queries.dart';
import '../domain/prasadi_place.dart';

/// Live, offline-cached prasadi places: active only, sorted on the device by
/// `order` then name. No server-side ordering/filtering, so a missing field
/// can never make a place vanish and no composite index is required.
final StreamProvider<List<PrasadiPlace>> placesProvider =
    StreamProvider<List<PrasadiPlace>>((Ref ref) {
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.places)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                sortActivePlaces(_parse(snapshot)),
          );
    });

/// One place by id, derived from [placesProvider] (the collection is small,
/// already cached, and this keeps detail and list perfectly in sync).
/// `data(null)` means the place does not exist or is hidden.
final ProviderFamily<AsyncValue<PrasadiPlace?>, String> placeProvider =
    Provider.family<AsyncValue<PrasadiPlace?>, String>(
      (Ref ref, String id) => ref
          .watch(placesProvider)
          .whenData((List<PrasadiPlace> places) => findPlace(places, id)),
    );

List<PrasadiPlace> _parse(QuerySnapshot<Map<String, dynamic>> snapshot) {
  final List<PrasadiPlace> places = <PrasadiPlace>[];
  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
    try {
      places.add(PrasadiPlace.fromMap(doc.id, doc.data()));
    } catch (error, stack) {
      // One malformed document must never hide the rest of the list.
      AppLogger.error('Skipping malformed place ${doc.id}', error, stack);
    }
  }
  return places;
}
