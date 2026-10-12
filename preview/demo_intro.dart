import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:jetalpur_dham/core/l10n/l10n.dart';
import 'package:jetalpur_dham/core/router/routes.dart';
import 'package:jetalpur_dham/core/theme/app_spacing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows [DemoIntroSheet] once, shortly after the demo leaves the splash
/// screen, so testers know they are looking at sample content.
///
/// Demo build only: it wraps the unchanged production app from the outside
/// and opens the sheet on the router's root navigator.
class DemoIntroHost extends StatefulWidget {
  const DemoIntroHost({
    super.key,
    required this.router,
    required this.prefs,
    required this.child,
    this.delay = const Duration(milliseconds: 700),
  });

  /// SharedPreferences key that remembers the sheet was already shown.
  static const String shownKey = 'demo.introShown';

  final GoRouter router;
  final SharedPreferences prefs;
  final Widget child;

  /// Pause after the first real screen appears, so the sheet does not cover
  /// the splash-to-home transition.
  final Duration delay;

  @override
  State<DemoIntroHost> createState() => _DemoIntroHostState();
}

class _DemoIntroHostState extends State<DemoIntroHost> {
  Timer? _timer;
  bool _scheduled = false;

  GoRouterDelegate get _delegate => widget.router.routerDelegate;

  @override
  void initState() {
    super.initState();
    if (widget.prefs.getBool(DemoIntroHost.shownKey) ?? false) return;
    _delegate.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    final String path = _delegate.currentConfiguration.uri.path;
    if (_scheduled || path.isEmpty || path == Routes.splash) return;
    _scheduled = true;
    _delegate.removeListener(_onRouteChanged);
    _timer = Timer(widget.delay, _show);
  }

  void _show() {
    final BuildContext? navigatorContext =
        _delegate.navigatorKey.currentContext;
    if (!mounted || navigatorContext == null) return;
    unawaited(widget.prefs.setBool(DemoIntroHost.shownKey, true));
    unawaited(
      showModalBottomSheet<void>(
        context: navigatorContext,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const DemoIntroSheet(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _delegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Friendly first-launch note: this is a demo, which content is real, and
/// which features are switched off.
class DemoIntroSheet extends StatelessWidget {
  const DemoIntroSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final TextStyle? bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.explore_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: AppRadius.smAll,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                l10n.demoBadge.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.demoIntroTitle,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.demoIntroBody,
            style: bodyStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.demoIntroDisabled,
            style: bodyStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.demoIntroStart),
            ),
          ),
        ],
      ),
    );
  }
}
