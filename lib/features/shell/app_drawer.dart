import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/share_app.dart';
import '../../core/widgets/menu_button.dart';

/// Side menu with every section of the app and a language switcher.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String location = GoRouterState.of(context).uri.path;

    void open(String route) {
      shellScaffoldKey.currentState?.closeDrawer();
      HapticFeedback.selectionClick();
      context.go(route);
    }

    Widget item(
      IconData icon,
      String label,
      String route, {
      bool exact = false,
    }) {
      final bool selected = exact
          ? location == route
          : location.startsWith(route);
      return _DrawerItem(
        icon: icon,
        label: label,
        selected: selected,
        onTap: () => open(route),
      );
    }

    return NavigationDrawer(
      tilePadding: EdgeInsets.zero,
      children: <Widget>[
        const _DrawerHeader(),
        const SizedBox(height: AppSpacing.sm),
        item(Icons.home_rounded, l10n.navHome, Routes.home, exact: true),
        item(Icons.music_note_rounded, l10n.featureKirtan, Routes.kirtan),
        item(Icons.place_rounded, l10n.featurePlaces, Routes.places),
        item(Icons.photo_library_rounded, l10n.drawerGallery, Routes.gallery),
        item(Icons.menu_book_rounded, l10n.libraryTitle, Routes.library),
        item(Icons.celebration_rounded, l10n.featureEvents, Routes.events),
        item(
          Icons.volunteer_activism_rounded,
          l10n.featureDonate,
          Routes.donate,
        ),
        const _SectionDivider(),
        item(
          Icons.download_done_rounded,
          l10n.drawerDownloads,
          Routes.kirtanDownloads,
        ),
        item(Icons.account_balance_rounded, l10n.drawerAbout, Routes.about),
        item(Icons.settings_rounded, l10n.drawerSettings, Routes.settings),
        _DrawerItem(
          icon: Icons.share_rounded,
          label: l10n.drawerShareApp,
          onTap: () {
            shellScaffoldKey.currentState?.closeDrawer();
            shareApp(context, ref.read(appConfigValueProvider));
          },
        ),
        const _SectionDivider(),
        const _DrawerLanguageSelector(),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: AppRadius.lgAll,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldLight, width: 2),
                image: const DecorationImage(
                  image: AssetImage('assets/images/murti.jpg'),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.jaySwaminarayan,
                    style: text.labelLarge?.copyWith(
                      color: AppColors.goldLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    context.l10n.templeShortName,
                    style: text.titleLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      child: ListTile(
        selected: selected,
        selectedTileColor: scheme.primaryContainer,
        selectedColor: scheme.onPrimaryContainer,
        shape: const StadiumBorder(),
        leading: Icon(icon),
        title: Text(label, style: Theme.of(context).textTheme.titleSmall),
        minVerticalPadding: AppSpacing.sm,
        onTap: onTap,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.sm,
    ),
    child: Divider(),
  );
}

class _DrawerLanguageSelector extends ConsumerWidget {
  const _DrawerLanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage current = ref.watch(languageProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.translate_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.l10n.language,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppLanguage>(
              showSelectedIcon: false,
              segments: <ButtonSegment<AppLanguage>>[
                for (final AppLanguage language in AppLanguage.values)
                  ButtonSegment<AppLanguage>(
                    value: language,
                    label: Text(
                      language.nativeName,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: language.fontFamily,
                        fontFamilyFallback: language.fontFallback,
                      ),
                    ),
                  ),
              ],
              selected: <AppLanguage>{current},
              onSelectionChanged: (Set<AppLanguage> selection) {
                HapticFeedback.selectionClick();
                ref
                    .read(languageProvider.notifier)
                    .setLanguage(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}
