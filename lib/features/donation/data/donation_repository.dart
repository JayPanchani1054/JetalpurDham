import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/donation_config.dart';
import '../domain/donation_request.dart';

/// The `config/donation` document as last seen by the device.
@immutable
class DonationConfigSnapshot {
  const DonationConfigSnapshot({required this.config, required this.fromCache});

  /// Null when the document does not exist (yet).
  final DonationConfig? config;

  /// True when served from the offline cache. A missing document that comes
  /// from the cache only means "not downloaded yet", not "not configured".
  final bool fromCache;

  /// Payment details can be shown.
  bool get isAvailable =>
      config != null && config!.enabled && config!.hasPaymentDetails;

  /// The document is missing only because the device has never been online.
  bool get isWaitingForNetwork => config == null && fromCache;
}

/// Live `config/donation` (served from the offline cache without internet).
final StreamProvider<DonationConfigSnapshot> donationConfigProvider =
    StreamProvider<DonationConfigSnapshot>((Ref ref) {
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.config)
          .doc(FirestorePaths.donationConfigDoc)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic>? data = doc.data();
            DonationConfig? config;
            if (data != null) {
              try {
                config = DonationConfig.fromMap(data);
              } catch (error, stack) {
                // Defensive: parsing never throws, but a bad document must
                // never break the screen.
                AppLogger.error('Bad config/donation document', error, stack);
              }
            }
            return DonationConfigSnapshot(
              config: config,
              fromCache: doc.metadata.isFromCache,
            );
          });
    });

/// Result of [DonationRepository.submit].
enum DonationSubmitResult {
  /// The server confirmed the request.
  sent,

  /// No confirmation in time (usually offline). The write is persisted on the
  /// device and Firestore syncs it automatically once online.
  queued,
}

/// Writes devotees' donation details to `donation_requests`.
class DonationRepository {
  DonationRepository({
    required this._addDocument,
    required this._appVersion,
    this.ackTimeout = const Duration(seconds: 8),
  });

  /// Adds a document and completes when the server acknowledges it.
  final Future<void> Function(Map<String, Object?> data) _addDocument;

  /// App version, e.g. `1.0.0+1`.
  final Future<String> Function() _appVersion;

  /// How long to wait for the server before reporting [DonationSubmitResult.queued].
  final Duration ackTimeout;

  /// Submits [request]. Throws when the write is rejected (e.g. invalid data);
  /// returns [DonationSubmitResult.queued] when the server did not answer in
  /// time, because with offline persistence `add()` only completes after the
  /// server acknowledges the write — while it is already safely stored locally.
  Future<DonationSubmitResult> submit(
    DonationRequest request, {
    Duration? timeout,
    Object? createdAt,
  }) async {
    String version;
    try {
      version = await _appVersion().timeout(const Duration(seconds: 2));
    } catch (_) {
      version = 'unknown';
    }
    final Map<String, Object?> data = request.toFirestore(
      appVersion: version,
      createdAt: createdAt ?? FieldValue.serverTimestamp(),
    );
    final Future<void> write = _addDocument(data);
    try {
      await write.timeout(timeout ?? ackTimeout);
      return DonationSubmitResult.sent;
    } on TimeoutException {
      // Keep listening so a late rejection is logged instead of being an
      // unhandled error.
      unawaited(
        write.then<void>(
          (_) => AppLogger.info('Queued donation request synced'),
          onError: (Object error, StackTrace stack) => AppLogger.error(
            'Queued donation request was rejected',
            error,
            stack,
          ),
        ),
      );
      return DonationSubmitResult.queued;
    }
  }
}

Future<String> _packageVersion() async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version}+${info.buildNumber}';
}

final Provider<DonationRepository> donationRepositoryProvider =
    Provider<DonationRepository>((Ref ref) {
      final FirebaseFirestore firestore = ref.watch(firestoreProvider);
      return DonationRepository(
        addDocument: (Map<String, Object?> data) =>
            firestore.collection(FirestorePaths.donationRequests).add(data),
        appVersion: _packageVersion,
      );
    });
