import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n/app_language.dart';
import 'core/l10n/l10n.dart';
import 'core/l10n/language_controller.dart';
import 'core/legal/licenses.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_links.dart';
import 'core/theme/app_theme.dart';
import 'features/events/application/notification_service.dart';

class JetalpurDhamApp extends ConsumerStatefulWidget {
  const JetalpurDhamApp({super.key, this.router});

  /// Injected in tests; production builds create the default router.
  final GoRouter? router;

  @override
  ConsumerState<JetalpurDhamApp> createState() => _JetalpurDhamAppState();
}

class _JetalpurDhamAppState extends ConsumerState<JetalpurDhamApp> {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  void initState() {
    super.initState();
    DeepLinks.attach(_router);
    registerAppLicenses();
    _syncNotifications();
  }

  void _syncNotifications() {
    NotificationService.instance.syncSubscription(
      language: ref.read(languageProvider),
      enabled: ref.read(notificationsEnabledProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(languageProvider);
    // Keep the push-topic subscription in step with language and the toggle.
    ref.listen<AppLanguage>(languageProvider, (_, _) => _syncNotifications());
    ref.listen<bool>(
      notificationsEnabledProvider,
      (_, _) => _syncNotifications(),
    );

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(language),
      darkTheme: AppTheme.dark(language),
      locale: language.locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      routerConfig: _router,
      builder: (BuildContext context, Widget? child) {
        // Respect the user's font size, but cap it so layouts never break.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.4),
          ),
          // Packages that still use package:flutter/material.dart (maps,
          // photo viewer, progress bar…) read the theme through this bridge.
          // ignore: deprecated_member_use
          child: MaterialUiCompatibilityBridge(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
