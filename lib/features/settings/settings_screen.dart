import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/services/download_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/widgets/language_button.dart';
import '../events/application/notification_service.dart';

final FutureProviderFamily<int, String> _folderSizeProvider =
    FutureProvider.family<int, String>(
      (Ref ref, String folder) =>
          ref.watch(downloadServiceProvider).folderSize(folder),
    );

final FutureProvider<PackageInfo> _packageInfoProvider =
    FutureProvider<PackageInfo>((Ref ref) => PackageInfo.fromPlatform());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppLanguage language = ref.watch(languageProvider);
    final bool notifications = ref.watch(notificationsEnabledProvider);
    final ThemeData theme = Theme.of(context);

    Widget header(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: const <Widget>[LanguageButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          header(l10n.settingsLanguage),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(language.nativeName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLanguagePicker(context),
          ),
          header(l10n.settingsNotifications),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: Text(l10n.settingsNotifications),
            subtitle: Text(l10n.settingsNotificationsDesc),
            value: notifications,
            onChanged: (bool value) async {
              await ref
                  .read(notificationsEnabledProvider.notifier)
                  .setEnabled(value);
              // Someone who tapped "Not now" earlier gets the OS prompt now.
              if (value) await NotificationService.instance.requestPermission();
            },
          ),
          header(l10n.settingsStorage),
          _StorageTile(
            icon: Icons.music_note_rounded,
            title: l10n.settingsDownloadedKirtans,
            folder: DownloadFolders.kirtans,
          ),
          _StorageTile(
            icon: Icons.menu_book_rounded,
            title: l10n.settingsDownloadedBooks,
            folder: DownloadFolders.books,
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded),
            title: Text(l10n.settingsClearCache),
            onTap: () async {
              await DefaultCacheManager().emptyCache();
              PaintingBinding.instance.imageCache.clear();
              if (context.mounted) context.showSnack(l10n.settingsCacheCleared);
            },
          ),
          header(l10n.settingsAboutApp),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.templeName),
            subtitle: Text(
              ref
                      .watch(_packageInfoProvider)
                      .whenOrNull(
                        data: (PackageInfo info) => l10n.settingsAppVersion(
                          '${info.version} (${info.buildNumber})',
                        ),
                      ) ??
                  '',
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageTile extends ConsumerWidget {
  const _StorageTile({
    required this.icon,
    required this.title,
    required this.folder,
  });

  final IconData icon;
  final String title;
  final String folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<int> size = ref.watch(_folderSizeProvider(folder));
    final int bytes = size.value ?? 0;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(Formatters.bytes(bytes)),
      trailing: bytes == 0
          ? null
          : TextButton(
              onPressed: () async {
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    content: Text(context.l10n.settingsConfirmDelete),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.remove),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await ref
                    .read(downloadManagerProvider.notifier)
                    .clearFolder(folder);
                ref.invalidate(_folderSizeProvider(folder));
              },
              child: Text(context.l10n.settingsRemoveAll),
            ),
    );
  }
}
