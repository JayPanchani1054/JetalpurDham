import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../firebase/firestore_parsing.dart';
import '../models/localized_text.dart';

/// One row of the darshan timetable, e.g. "Mangla Aarti — 5:30 AM".
class DarshanTiming {
  const DarshanTiming({required this.label, required this.time});

  factory DarshanTiming.fromMap(Map<String, Object?> map) => DarshanTiming(
    label: LocalizedText.fromValue(map['label']),
    time: Fs.string(map['time']),
  );

  final LocalizedText label;
  final String time;
}

/// Temple-wide settings stored in `config/app`. Every field is optional so the
/// app works before the document is filled in.
class AppConfig {
  const AppConfig({
    this.templeName = const LocalizedText.empty(),
    this.tagline = const LocalizedText.empty(),
    this.about = const LocalizedText.empty(),
    this.address = const LocalizedText.empty(),
    this.latitude,
    this.longitude,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.youtube,
    this.facebook,
    this.instagram,
    this.darshanTimings = const <DarshanTiming>[],
    this.heroImageUrl,
    this.featuredAlbumId,
    this.shareUrl,
  });

  factory AppConfig.fromMap(Map<String, Object?> map) {
    final GeoPoint? location = Fs.geoPoint(map['location']);
    return AppConfig(
      templeName: LocalizedText.fromValue(map['templeName']),
      tagline: LocalizedText.fromValue(map['tagline']),
      about: LocalizedText.fromValue(map['about']),
      address: LocalizedText.fromValue(map['address']),
      latitude: location?.latitude,
      longitude: location?.longitude,
      phone: Fs.stringOrNull(map['phone']),
      whatsapp: Fs.stringOrNull(map['whatsapp']),
      email: Fs.stringOrNull(map['email']),
      website: Fs.stringOrNull(map['website']),
      youtube: Fs.stringOrNull(map['youtube']),
      facebook: Fs.stringOrNull(map['facebook']),
      instagram: Fs.stringOrNull(map['instagram']),
      darshanTimings: Fs.mapList(map['darshanTimings'])
          .map(DarshanTiming.fromMap)
          .where((DarshanTiming t) => t.time.isNotEmpty)
          .toList(growable: false),
      heroImageUrl: Fs.stringOrNull(map['heroImageUrl']),
      featuredAlbumId: Fs.stringOrNull(map['featuredAlbumId']),
      shareUrl: Fs.stringOrNull(map['shareUrl']),
    );
  }

  /// Defaults used until `config/app` is available.
  static const AppConfig fallback = AppConfig(
    latitude: 22.8895,
    longitude: 72.5956,
    featuredAlbumId: 'avsar-200',
  );

  final LocalizedText templeName;
  final LocalizedText tagline;
  final LocalizedText about;
  final LocalizedText address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;
  final String? youtube;
  final String? facebook;
  final String? instagram;
  final List<DarshanTiming> darshanTimings;

  /// Optional remote image for the home hero; the bundled murti image is used
  /// when empty.
  final String? heroImageUrl;

  /// Album highlighted on the home screen (defaults to "avsar-200").
  final String? featuredAlbumId;

  /// Store/landing page link used by "Share App".
  final String? shareUrl;

  bool get hasLocation => latitude != null && longitude != null;
}

/// Live `config/app` document (served from the offline cache when offline).
final StreamProvider<AppConfig> appConfigProvider = StreamProvider<AppConfig>((
  Ref ref,
) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.config)
      .doc(FirestorePaths.appConfigDoc)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic>? data = doc.data();
        if (data == null) return AppConfig.fallback;
        final AppConfig config = AppConfig.fromMap(data);
        return config.hasLocation
            ? config
            : AppConfig.fromMap(<String, Object?>{
                ...data,
                'location': const GeoPoint(22.8895, 72.5956),
              });
      });
});

/// The config value, falling back to defaults while loading or on error.
final Provider<AppConfig> appConfigValueProvider = Provider<AppConfig>(
  (Ref ref) => ref.watch(appConfigProvider).value ?? AppConfig.fallback,
);
