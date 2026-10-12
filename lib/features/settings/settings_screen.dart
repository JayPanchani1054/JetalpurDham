import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/services/download_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/widgets/language_button.dart';
import '../events/application/notification_service.dart';
import '../kirtan/application/kirtan_stream_cache.dart';

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
          const _StreamCacheTile(),
          ListTile(
            leading: const Icon(Icons.image_rounded),
            title: Text(l10n.settingsClearCache),
            onTap: () async {
              await DefaultCacheManager().emptyCache();
              PaintingBinding.instance.imageCache.clear();
              if (context.mounted) context.showSnack(l10n.settingsCacheCleared);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report_outlined),
            title: Text(l10n.settingsCrashReports),
            subtitle: Text(l10n.settingsCrashReportsDesc),
            value: ref.watch(crashReportsEnabledProvider),
            onChanged: (bool value) async {
              await ref
                  .read(crashReportsEnabledProvider.notifier)
                  .setEnabled(value);
              await _applyCrashReports(value);
            },
          ),
          header(l10n.settingsAboutApp),
          const _FeedbackTile(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsPrivacyPolicy),
            trailing: const Icon(Icons.open_in_new_rounded, size: 20),
            onTap: () async {
              final String url =
                  ref.read(appConfigValueProvider).privacyPolicyUrl ??
                  kDefaultPrivacyPolicyUrl;
              if (!await Launcher.url(url) && context.mounted) {
                context.showOpenLinkError();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: Text(l10n.settingsLegalNotices),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              final PackageInfo? info = ref.read(_packageInfoProvider).value;
              showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: info?.version,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Image.asset('assets/icons/splash_logo.png', width: 72),
                ),
              );
            },
          ),
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

/// Opens an e-mail to the temple (or a WhatsApp chat when no e-mail is set)
/// with the app version, platform and OS version filled in. Hidden until
/// `config/app` has an e-mail address or a WhatsApp number.
class _FeedbackTile extends ConsumerWidget {
  const _FeedbackTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppConfig config = ref.watch(appConfigValueProvider);
    final String? email = config.email;
    final String? whatsApp = config.whatsapp;
    if (email == null && whatsApp == null) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.feedback_outlined),
      title: Text(l10n.settingsSendFeedback),
      subtitle: Text(l10n.settingsSendFeedbackDesc),
      trailing: const Icon(Icons.open_in_new_rounded, size: 20),
      onTap: () async {
        PackageInfo? info;
        try {
          info = await ref.read(_packageInfoProvider.future);
        } catch (error, stack) {
          AppLogger.error('Package info unavailable', error, stack);
        }
        final String subject = l10n.settingsFeedbackSubject;
        final String details = _feedbackDetails(l10n, info);
        bool opened = false;
        if (email != null) {
          // Room to write above the details.
          opened = await Launcher.email(
            email,
            subject: subject,
            body: '\n\n\n---\n$details',
          );
        }
        if (!opened && whatsApp != null) {
          opened = await Launcher.whatsApp(
            whatsApp,
            message: '$subject\n$details\n\n',
          );
        }
        if (!opened && context.mounted) context.showOpenLinkError();
      },
    );
  }
}

/// App version, platform and OS version, so the temple can reproduce a
/// problem a devotee reports.
String _feedbackDetails(AppLocalizations l10n, PackageInfo? info) {
  final String app = info == null
      ? l10n.appTitle
      : '${l10n.appTitle} · '
            '${l10n.settingsAppVersion('${info.version} (${info.buildNumber})')}';
  final String platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    final TargetPlatform other => other.name,
  };
  final String os = kIsWeb
      ? 'Web'
      : '$platform · ${Platform.operatingSystemVersion}';
  return '$app\n$os';
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

final FutureProvider<int> _streamCacheSizeProvider = FutureProvider<int>(
  (Ref ref) => ref.watch(kirtanStreamCacheProvider).size(),
);

/// Kirtans cached while streaming (instant replays). Not covered by the
/// image cache, so it gets its own entry.
class _StreamCacheTile extends ConsumerWidget {
  const _StreamCacheTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int bytes = ref.watch(_streamCacheSizeProvider).value ?? 0;
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.graphic_eq_rounded),
      title: Text(l10n.settingsStreamCache),
      subtitle: Text(
        '${l10n.settingsStreamCacheDesc} · ${Formatters.bytes(bytes)}',
      ),
      trailing: bytes == 0
          ? null
          : TextButton(
              onPressed: () async {
                await ref.read(kirtanStreamCacheProvider).clear();
                ref.invalidate(_streamCacheSizeProvider);
                if (context.mounted) {
                  context.showSnack(l10n.settingsCacheCleared);
                }
              },
              child: Text(l10n.settingsRemoveAll),
            ),
    );
  }
}

/// Turns Crashlytics collection on/off right away (no-op until Firebase is
/// configured, and always off in debug builds).
Future<void> _applyCrashReports(bool enabled) async {
  try {
    if (Firebase.apps.isEmpty) return;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      enabled && !kDebugMode,
    );
  } catch (error, stack) {
    AppLogger.error('Updating crash report setting failed', error, stack);
  }
}
