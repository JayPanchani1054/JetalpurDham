import 'package:material_ui/material_ui.dart';

import '../../l10n/gen/app_localizations.dart';
import 'app_language.dart';

export '../../l10n/gen/app_localizations.dart';

extension L10nX on BuildContext {
  /// Shortcut for `AppLocalizations.of(context)`.
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// The language currently shown in the UI.
  AppLanguage get appLanguage =>
      AppLanguage.fromCode(Localizations.localeOf(this).languageCode);
}
