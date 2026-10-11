import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/preferences.dart';
import 'app_language.dart';

/// The UI language. Persisted across launches; English by default.
final NotifierProvider<LanguageController, AppLanguage> languageProvider =
    NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);

class LanguageController extends Notifier<AppLanguage> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppLanguage build() =>
      AppLanguage.fromCode(_prefs.getString(PrefKeys.language));

  Future<void> setLanguage(AppLanguage language) async {
    if (language == state) return;
    state = language;
    await _prefs.setString(PrefKeys.language, language.code);
  }
}

/// Whether the user wants utsav/katha push notifications. Defaults to on.
final NotifierProvider<NotificationsEnabledController, bool>
notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledController, bool>(
      NotificationsEnabledController.new,
    );

class NotificationsEnabledController extends Notifier<bool> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  bool build() => _prefs.getBool(PrefKeys.notificationsEnabled) ?? true;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _prefs.setBool(PrefKeys.notificationsEnabled, enabled);
  }
}
