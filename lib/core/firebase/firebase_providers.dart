import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase singletons exposed as providers so tests can override them.
final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

final Provider<FirebaseStorage> firebaseStorageProvider =
    Provider<FirebaseStorage>((Ref ref) => FirebaseStorage.instance);

/// Firestore collection and document names. This is the contract with the
/// backend (see docs/DATA_MODEL.md, firestore.rules and functions/).
abstract final class FirestorePaths {
  static const String config = 'config';
  static const String appConfigDoc = 'app';
  static const String donationConfigDoc = 'donation';

  static const String kirtanCategories = 'kirtan_categories';
  static const String kirtans = 'kirtans';
  static const String places = 'places';
  static const String albums = 'albums';
  static const String photos = 'photos'; // sub-collection of albums
  static const String bookCategories = 'book_categories';
  static const String books = 'books';
  static const String events = 'events';
  static const String donationRequests = 'donation_requests';
}
