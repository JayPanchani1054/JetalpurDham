import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/kirtan.dart';
import '../domain/kirtan_queries.dart';

/// Live, offline-cached kirtan categories (active only, sorted on device).
final StreamProvider<List<KirtanCategory>> kirtanCategoriesProvider =
    StreamProvider<List<KirtanCategory>>((Ref ref) {
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.kirtanCategories)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                sortActiveCategories(
                  _parse(snapshot, KirtanCategory.fromMap, 'category'),
                ),
          );
    });

/// Live, offline-cached kirtans: active and playable, sorted by `order` then
/// title. No server-side ordering/filtering, so a missing field can never make
/// a kirtan vanish and no composite index is required.
final StreamProvider<List<Kirtan>> kirtansProvider =
    StreamProvider<List<Kirtan>>((Ref ref) {
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.kirtans)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                sortActiveKirtans(_parse(snapshot, Kirtan.fromMap, 'kirtan')),
          );
    });

/// Kirtans for the Home screen (`isFeatured`, falling back to the first 8).
final Provider<AsyncValue<List<Kirtan>>> featuredKirtansProvider =
    Provider<AsyncValue<List<Kirtan>>>(
      (Ref ref) => ref.watch(kirtansProvider).whenData(selectFeaturedKirtans),
    );

List<T> _parse<T>(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  T Function(String id, Map<String, Object?> data) parse,
  String label,
) {
  final List<T> items = <T>[];
  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
    try {
      items.add(parse(doc.id, doc.data()));
    } catch (error, stack) {
      // One malformed document must never hide the rest of the list.
      AppLogger.error('Skipping malformed $label ${doc.id}', error, stack);
    }
  }
  return items;
}
