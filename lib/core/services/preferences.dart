import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synchronous access to SharedPreferences. The instance is created in
/// `bootstrap()` and injected with `overrideWithValue`.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw UnimplementedError(
        'sharedPreferencesProvider must be overridden in bootstrap()',
      ),
    );

/// Keys for every value persisted in SharedPreferences, kept in one place to
/// avoid collisions between features.
abstract final class PrefKeys {
  static const String language = 'app.language';
  static const String notificationsEnabled = 'app.notificationsEnabled';
  static const String notificationPromptShown = 'app.notificationPromptShown';
  static const String crashReportsEnabled = 'app.crashReportsEnabled';
  static const String kirtanDownloadsIndex = 'kirtan.downloadsIndex';
  static const String kirtanLastQueue = 'kirtan.lastQueue';
  static const String libraryDownloadsIndex = 'library.downloadsIndex';
  static const String libraryLastPagePrefix = 'library.lastPage.';
}
