import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_language.dart';

/// Text stored in Firestore in several languages.
///
/// Admins may store either a plain string (used for every language) or a map
/// such as `{"en": "...", "gu": "...", "hi": "..."}`. Missing translations
/// gracefully fall back to English, then Gujarati, then Hindi.
@immutable
class LocalizedText {
  const LocalizedText(this.values);

  const LocalizedText.empty() : values = const <String, String>{};

  LocalizedText.single(String text)
    : values = <String, String>{AppLanguage.en.code: text};

  /// Parses any Firestore value into a [LocalizedText]. Never throws.
  factory LocalizedText.fromValue(Object? value) {
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty
          ? const LocalizedText.empty()
          : LocalizedText(<String, String>{'*': trimmed});
    }
    if (value is Map) {
      final Map<String, String> parsed = <String, String>{};
      value.forEach((Object? key, Object? text) {
        if (key is String && text is String && text.trim().isNotEmpty) {
          parsed[key.toLowerCase()] = text.trim();
        }
      });
      return LocalizedText(parsed);
    }
    return const LocalizedText.empty();
  }

  final Map<String, String> values;

  static const List<String> _fallbackOrder = <String>['en', 'gu', 'hi'];

  bool get isEmpty => values.isEmpty;
  bool get isNotEmpty => values.isNotEmpty;

  /// Returns the text for [languageCode] with sensible fallbacks.
  String resolve(String languageCode) {
    final String? exact = values[languageCode] ?? values['*'];
    if (exact != null) return exact;
    for (final String code in _fallbackOrder) {
      final String? text = values[code];
      if (text != null) return text;
    }
    return values.isEmpty ? '' : values.values.first;
  }

  /// Resolves using the locale of [context].
  String of(BuildContext context) =>
      resolve(Localizations.localeOf(context).languageCode);

  /// True if any translation contains [query] (case-insensitive). Used for
  /// search so users find content regardless of the script they type in.
  bool matches(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return values.values.any((String v) => v.toLowerCase().contains(q));
  }

  Map<String, String> toMap() => Map<String, String>.of(values);

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map(
      (MapEntry<String, String> e) => Object.hash(e.key, e.value),
    ),
  );

  @override
  String toString() => 'LocalizedText($values)';
}
