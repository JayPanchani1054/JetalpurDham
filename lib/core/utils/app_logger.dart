import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Central logging. In release builds errors go to Crashlytics as non-fatal
/// reports; in debug they are printed.
abstract final class AppLogger {
  static bool crashlyticsReady = false;

  /// Diagnostic builds for testers: `--dart-define=JD_VERBOSE_LOGS=true`
  /// prints logs in release mode too (visible via `adb logcat` / the browser
  /// console).
  static const bool verbose = bool.fromEnvironment('JD_VERBOSE_LOGS');
  static bool get _print => kDebugMode || verbose;

  static void info(String message) {
    if (_print) debugPrint('[JetalpurDham] $message');
    if (crashlyticsReady) FirebaseCrashlytics.instance.log(message);
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    if (_print) {
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
