import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'demo_content.g.dart';

/// Where the demo pictures, audio and PDF are served from.
///
/// On the web they sit next to the app (build/web/demo_media). On phones they
/// are loaded from this public repository, so the demo APK needs internet the
/// first time (afterwards the app's caches keep them).
String demoMedia(String name) => kIsWeb
    ? Uri.base.resolve('demo_media/$name').toString()
    : 'https://raw.githubusercontent.com/JayPanchani1054/JetalpurDham/HEAD/'
          'preview/demo_media/$name';

Object? _decode(Object? value) {
  if (value is Map) {
    if (value.containsKey(r'$geopoint')) {
      final List<Object?> p = value[r'$geopoint']! as List<Object?>;
      return GeoPoint((p[0]! as num).toDouble(), (p[1]! as num).toDouble());
    }
    if (value.containsKey(r'$timestamp')) {
      return Timestamp.fromDate(
        DateTime.parse(value[r'$timestamp']! as String),
      );
    }
    return value.map(
      (Object? k, Object? v) =>
          MapEntry<String, Object?>(k.toString(), _decode(v)),
    );
  }
  if (value is List) return value.map(_decode).toList();
  return value;
}

Map<String, Object?> _map(Object? value) =>
    (_decode(value) ?? <String, Object?>{}) as Map<String, Object?>;

/// An in-memory Firestore filled with the real seed data (temple info,
/// prasadi places, categories, Avsar 200) plus sample kirtans, shastras,
/// utsavs and photos, so every screen can be explored without Firebase.
Future<FakeFirebaseFirestore> buildDemoFirestore({DateTime? now}) async {
  final DateTime today = now ?? DateTime.now();
  final FakeFirebaseFirestore db = FakeFirebaseFirestore();

  // 1. The production seed (tools/seed/seed-data.json).
  final Map<String, Object?> seed =
      jsonDecode(kSeedJson) as Map<String, Object?>;
  final Map<String, Object?> collections =
      seed['collections']! as Map<String, Object?>;
  for (final MapEntry<String, Object?> collection in collections.entries) {
    final Map<String, Object?> docs = collection.value! as Map<String, Object?>;
    for (final MapEntry<String, Object?> doc in docs.entries) {
      await db.collection(collection.key).doc(doc.key).set(_map(doc.value));
    }
  }

  // 2. Pictures and 360° views for the prasadi places.
  for (final String id
      in (collections['places']! as Map<String, Object?>).keys) {
    await db.collection('places').doc(id).set(<String, Object?>{
      'images': <String>[demoMedia('place_$id.jpg')],
      if (id == 'nij-mandir-revati-baldevji')
        'panoramaUrls': <String>[demoMedia('pano_nij_mandir.jpg')],
      if (id == 'dev-sarovar')
        'panoramaUrls': <String>[demoMedia('pano_dev_sarovar.jpg')],
    }, SetOptions(merge: true));
  }

  // 3. Sample kirtans (real titles and poets; placeholder tanpura audio).
  final Map<String, Object?> content =
      jsonDecode(kDemoContentJson) as Map<String, Object?>;
  final List<Object?> kirtans = content['kirtans']! as List<Object?>;
  for (int i = 0; i < kirtans.length; i++) {
    final Map<String, Object?> k = _map(kirtans[i]);
    await db.collection('kirtans').doc('demo-kirtan-${i + 1}').set(
      <String, Object?>{
        ...k,
        'singer': <String, String>{
          'en': 'Sample audio (tanpura)',
          'gu': 'નમૂના ઑડિયો (તાનપુરો)',
          'hi': 'नमूना ऑडियो (तानपुरा)',
        },
        'audioUrl': demoMedia(
          i.isEven ? 'tanpura_sa_c_sharp.mp3' : 'tanpura_sa_d.mp3',
        ),
        'durationSec': 40,
        'sizeBytes': 320827,
        if (i == 0)
          'lyrics': <String, String>{
            'en': 'The temple adds the full lyrics of each kirtan here, in Gujarati, Hindi or English.\n\n(This preview plays a tanpura drone in place of the real recording.)',
            'gu': 'મંદિર દરેક કીર્તનના સંપૂર્ણ શબ્દો અહીં ઉમેરશે.\n\n(આ પૂર્વાવલોકનમાં સાચા રેકોર્ડિંગને બદલે તાનપુરો વાગે છે.)',
            'hi': 'मंदिर हर कीर्तन के पूरे बोल यहाँ जोड़ेगा।\n\n(इस पूर्वावलोकन में असली रिकॉर्डिंग की जगह तानपुरा बजता है।)',
          },
        'isActive': true,
        'createdAt': Timestamp.fromDate(today.subtract(Duration(days: i))),
      },
    );
  }

  // 4. Shastras (real names and descriptions; one sample PDF).
  for (final Object? raw in content['books']! as List<Object?>) {
    final Map<String, Object?> b = _map(raw);
    final String id = b.remove('id')! as String;
    await db.collection('books').doc(id).set(<String, Object?>{
      ...b,
      'pdfUrl': demoMedia('sample_shastra.pdf'),
      'pageCount': 6,
      'sizeBytes': 563925,
      'isActive': true,
    });
  }

  // 5. Avsar 200 photos.
  await db.collection('albums').doc('avsar-200').set(<String, Object?>{
    'coverUrl': demoMedia('avsar_01.jpg'),
    'photoCount': 12,
  }, SetOptions(merge: true));
  for (int i = 1; i <= 12; i++) {
    final String n = i.toString().padLeft(2, '0');
    await db
        .collection('albums')
        .doc('avsar-200')
        .collection('photos')
        .doc('avsar-$n')
        .set(<String, Object?>{
          'url': demoMedia('avsar_$n.jpg'),
          'thumbUrl': demoMedia('avsar_${n}_thumb.jpg'),
          'order': i,
          'width': 1280,
          'height': 853,
        });
  }

  // 6. Utsavs: the real Avsar 200 event plus sample upcoming/past ones.
  await db.collection('events').doc('avsar-200').set(<String, Object?>{
    'bannerUrl': demoMedia('banner_avsar.jpg'),
  }, SetOptions(merge: true));
  DateTime day(int offset, [int hour = 0]) =>
      DateTime(today.year, today.month, today.day + offset, hour);
  const Map<String, String> sampleNote = <String, String>{
    'en': 'Sample event for the app preview.',
    'gu': 'એપ પૂર્વાવલોકન માટેનો નમૂનાનો કાર્યક્રમ.',
    'hi': 'ऐप पूर्वावलोकन के लिए नमूना कार्यक्रम।',
  };
  await db.collection('events').doc('demo-katha').set(<String, Object?>{
    'title': <String, String>{
      'en': 'Shrimad Bhagwat Saptah Katha',
      'gu': 'શ્રીમદ્ ભાગવત સપ્તાહ કથા',
      'hi': 'श्रीमद् भागवत सप्ताह कथा',
    },
    'shortDescription': <String, String>{
      'en': 'Seven days of katha with kirtan and aarti every evening.',
      'gu': 'સાત દિવસની કથા, દરરોજ સાંજે કીર્તન અને આરતી.',
      'hi': 'सात दिनों की कथा, हर शाम कीर्तन और आरती।',
    },
    'description': <String, String>{
      'en':
          '${sampleNote['en']}\n\nAll devotees are invited to the katha in the mandir sabha hall. Daily katha 4:00–7:00 PM followed by sandhya aarti. Mahaprasad on the final day.',
      'gu':
          '${sampleNote['gu']}\n\nસર્વે હરિભક્તોને મંદિરના સભામંડપમાં કથાનો લાભ લેવા આમંત્રણ છે. દરરોજ સાંજે ૪:૦૦ થી ૭:૦૦ કથા, ત્યાર બાદ સંધ્યા આરતી. અંતિમ દિવસે મહાપ્રસાદ.',
      'hi':
          '${sampleNote['hi']}\n\nसभी हरिभक्तों को मंदिर के सभा मंडप में कथा का लाभ लेने का निमंत्रण है। प्रतिदिन शाम ४:०० से ७:०० कथा, उसके बाद संध्या आरती। अंतिम दिन महाप्रसाद।',
    },
    'location': <String, String>{
      'en': 'Sabha Mandap, Jetalpur Dham',
      'gu': 'સભામંડપ, જેતલપુર ધામ',
      'hi': 'सभा मंडप, जेतलपुर धाम',
    },
    'bannerUrl': demoMedia('banner_katha.jpg'),
    'startAt': Timestamp.fromDate(day(3, 16)),
    'endAt': Timestamp.fromDate(day(9, 19)),
    'type': 'katha',
    'liveUrl':
        'https://www.youtube.com/results?search_query=Jetalpur+Dham+katha',
    'isActive': true,
  });
  await db.collection('events').doc('demo-annakut').set(<String, Object?>{
    'title': <String, String>{
      'en': 'Annakut Mahotsav',
      'gu': 'અન્નકૂટ મહોત્સવ',
      'hi': 'अन्नकूट महोत्सव',
    },
    'shortDescription': <String, String>{
      'en': 'Darshan of the grand Annakut offered to Shree Revati Baldevji Harikrushna Maharaj.',
      'gu':
          'શ્રી રેવતી બળદેવજી હરિકૃષ્ણ મહારાજને ધરાવેલા ભવ્ય અન્નકૂટનાં દર્શન.',
      'hi': 'श्री रेवती बलदेवजी हरिकृष्ण महाराज को धराए गए भव्य अन्नकूट के दर्शन।',
    },
    'description': sampleNote,
    'bannerUrl': demoMedia('banner_annakut.jpg'),
    'startAt': Timestamp.fromDate(day(28, 7)),
    'type': 'utsav',
    'isActive': true,
  });
  await db.collection('events').doc('demo-sharad-purnima').set(
    <String, Object?>{
      'title': <String, String>{
        'en': 'Sharad Purnima Raas Utsav',
        'gu': 'શરદ પૂર્ણિમા રાસોત્સવ',
        'hi': 'शरद पूर्णिमा रासोत्सव',
      },
      'shortDescription': <String, String>{
        'en': 'Raas, kirtan and doodh-pauva prasad under the full moon.',
        'gu': 'પૂનમની ચાંદનીમાં રાસ, કીર્તન અને દૂધપૌંઆનો પ્રસાદ.',
        'hi': 'पूर्णिमा की चाँदनी में रास, कीर्तन और दूध-पोहे का प्रसाद।',
      },
      'description': sampleNote,
      'bannerUrl': demoMedia('avsar_04.jpg'),
      'startAt': Timestamp.fromDate(day(-6, 20)),
      'type': 'utsav',
      'albumId': 'avsar-200',
      'isActive': true,
    },
  );

  // 7. Donation details — clearly marked samples that cannot receive money.
  await db.collection('config').doc('donation').set(<String, Object?>{
    'enabled': true,
    'message': <String, String>{
      'en': 'Sample details for the app preview — please do not send money to them.',
      'gu': 'એપ પૂર્વાવલોકન માટેની નમૂનાની વિગતો — કૃપા કરી તેમાં રકમ મોકલશો નહીં.',
      'hi': 'ऐप पूर्वावलोकन के लिए नमूना विवरण — कृपया इनमें राशि न भेजें।',
    },
    'upiId': 'jetalpurdham.sample@demo',
    'payeeName': 'SAMPLE — Shree Swaminarayan Mandir',
    'bank': <String, String>{
      'accountName': 'SAMPLE ACCOUNT — not for payment',
      'accountNumber': '0000 0000 0000',
      'ifsc': 'SAMPLE000000',
      'bankName': 'Sample Bank',
      'branch': 'Jetalpur',
      'accountType': 'Savings',
    },
  }, SetOptions(merge: true));

  // 8. Temple contact details shown on About (website from the seed).
  await db.collection('config').doc('app').set(<String, Object?>{
    'featuredAlbumId': 'avsar-200',
  }, SetOptions(merge: true));

  return db;
}
