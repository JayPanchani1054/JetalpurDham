import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../l10n/language_controller.dart';
import '../theme/app_spacing.dart';

/// Top-right app bar action that switches the app language.
///
/// Shows the current language as a compact chip ("EN" / "ગુ" / "हि") so the
/// control is self-explanatory, and opens [showLanguagePicker] on tap.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key, this.foregroundColor});

  /// Override for use on top of images (e.g. white on the home hero).
  final Color? foregroundColor;

  static const Map<AppLanguage, String> _short = <AppLanguage, String>{
    AppLanguage.en: 'EN',
    AppLanguage.gu: 'ગુ',
    AppLanguage.hi: 'हि',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(languageProvider);
    final Color color =
        foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Tooltip(
        message: context.l10n.chooseLanguage,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          onTap: () => showLanguagePicker(context),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.translate_rounded, size: 18, color: color),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    _short[language]!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing the supported languages in their own scripts.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (BuildContext context) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage current = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.md,
                left: AppSpacing.sm,
              ),
              child: Text(
                context.l10n.chooseLanguage,
                style: theme.textTheme.titleLarge,
              ),
            ),
            for (final AppLanguage language in AppLanguage.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LanguageTile(
                  language: language,
                  selected: language == current,
                  onTap: () async {
                    await HapticFeedback.selectionClick();
                    await ref
                        .read(languageProvider.notifier)
                        .setLanguage(language);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  static const Map<AppLanguage, String> _english = <AppLanguage, String>{
    AppLanguage.en: 'English',
    AppLanguage.gu: 'Gujarati',
    AppLanguage.hi: 'Hindi',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md + 2,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      language.nativeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: language.fontFamily,
                        fontFamilyFallback: language.fontFallback,
                      ),
                    ),
                    if (language != AppLanguage.en)
                      Text(
                        _english[language]!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: scheme.primary,
                        key: const ValueKey<bool>(true),
                      )
                    : Icon(
                        Icons.circle_outlined,
                        color: scheme.outline,
                        key: const ValueKey<bool>(false),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
