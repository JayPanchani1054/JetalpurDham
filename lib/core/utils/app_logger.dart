import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Central logging. In release builds errors go to Crashlytics as non-fatal
/// reports; in debug they are printed.
abstract final class AppLogger {
  static bool crashlyticsReady = false;

  static void info(String message) {
    if (kDebugMode) debugPrint('[JetalpurDham] $message');
    if (crashlyticsReady) FirebaseCrashlytics.instance.log(message);
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[JetalpurDham] ERROR $message: $error');
      if (stack != null) debugPrint(stack.toString());
    }
    if (crashlyticsReady) {
      FirebaseCrashlytics.instance
          .recordError(error ?? message, stack, reason: message)
          .ignore();
    }
  }
}
