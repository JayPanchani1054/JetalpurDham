import 'package:material_ui/material_ui.dart';

/// Languages supported by the app. English is the primary language.
enum AppLanguage {
  en(
    code: 'en',
    nativeName: 'English',
    fontFamily: 'Poppins',
    fontFallback: <String>['HindVadodara', 'Hind'],
  ),
  gu(
    code: 'gu',
    nativeName: 'ગુજરાતી',
    fontFamily: 'HindVadodara',
    fontFallback: <String>['Poppins', 'Hind'],
  ),
  hi(
    code: 'hi',
    nativeName: 'हिन्दी',
    fontFamily: 'Hind',
    fontFallback: <String>['Poppins', 'HindVadodara'],
  );

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.fontFamily,
    required this.fontFallback,
  });

  /// ISO 639-1 code, also used as the key inside localized Firestore fields.
  final String code;

  /// Name of the language written in its own script.
  final String nativeName;

  final String fontFamily;
  final List<String> fontFallback;

  Locale get locale => Locale(code);

  /// FCM topic that carries notifications written in this language.
  String get notificationTopic => 'lang_$code';

  static AppLanguage fromCode(String? code) {
    for (final AppLanguage language in AppLanguage.values) {
      if (language.code == code) return language;
    }
    return AppLanguage.en;
  }

  static List<Locale> get supportedLocales =>
      AppLanguage.values.map((AppLanguage l) => l.locale).toList();
}
