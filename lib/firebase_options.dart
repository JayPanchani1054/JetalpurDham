// PLACEHOLDER — regenerate with the FlutterFire CLI for your Firebase project:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-firebase-project-id> \
//       --platforms=android,ios --android-package-name=com.jetalpurdham.app \
//       --ios-bundle-id=com.jetalpurdham.app
//
// That command overwrites this file and adds google-services.json /
// GoogleService-Info.plist. See docs/FIREBASE_SETUP.md.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// True until `flutterfire configure` has replaced this placeholder file.
  static const bool isPlaceholder = true;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'jetalpur-dham',
    storageBucket: 'jetalpur-dham.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'jetalpur-dham',
    storageBucket: 'jetalpur-dham.firebasestorage.app',
    iosBundleId: 'com.jetalpurdham.app',
  );
}
