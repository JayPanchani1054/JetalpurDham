import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/services/preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/language_button.dart';
import '../../core/widgets/menu_button.dart';
import '../events/application/notification_service.dart';
import '../events/presentation/widgets/home_upcoming_events.dart';
import '../gallery/presentation/widgets/home_gallery_preview.dart';
import '../kirtan/presentation/widgets/home_featured_kirtans.dart';
import '../places/presentation/widgets/home_places_preview.dart';
import '../splash/splash_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _promptTimer;

  @override
  void initState() {
    super.initState();
    _promptTimer = Timer(
      const Duration(milliseconds: 1500),
      _maybeAskForNotifications,
    );
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    super.dispose();
  }

  /// Asks once, in context, before triggering the OS permission dialog.
  Future<void> _maybeAskForNotifications() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(PrefKeys.notificationPromptShown) ?? false) return;
    if (await NotificationService.instance.isPermissionDetermined()) return;
    if (!mounted) return;
    await prefs.setBool(PrefKeys.notificationPromptShown, true);
    if (!mounted) return;
    // Apple's guidance for pre-permission screens: one "Continue" button that
    // always leads to the system alert, with no way to skip it. Android keeps
    // a "Not now" option.
    final bool apple = defaultTargetPlatform == TargetPlatform.iOS;
    final bool? allow = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isDismissible: !apple,
      enableDrag: !apple,
      builder: (BuildContext context) => _NotificationPrompt(allowSkip: !apple),
    );
    if (apple || (allow ?? false)) {
      await NotificationService.instance.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double heroHeight = (MediaQuery.sizeOf(context).height * 0.5).clamp(
      320.0,
      520.0,
    );
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          _HeroAppBar(expandedHeight: heroHeight),
          const SliverToBoxAdapter(child: _QuickActions()),
          const SliverToBoxAdapter(child: HomeUpcomingEvents()),
          const SliverToBoxAdapter(child: HomeFeaturedKirtans()),
          const SliverToBoxAdapter(child: HomeGalleryPreview()),
          const SliverToBoxAdapter(child: HomePlacesPreview()),
          const SliverToBoxAdapter(child: _DonateBanner()),
          const SliverToBoxAdapter(child: _DarshanTimingsCard()),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }
}

class _HeroAppBar extends ConsumerWidget {
  const _HeroAppBar({required this.expandedHeight});

  final double expandedHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String? remoteHero = ref.watch(appConfigValueProvider).heroImageUrl;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      backgroundColor: AppColors.saffron,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      leading: const MenuButton(color: Colors.white),
      title: Text(l10n.templeShortName),
      titleTextStyle: text.titleLarge?.copyWith(color: Colors.white),
      actions: const <Widget>[LanguageButton(foregroundColor: Colors.white)],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (remoteHero != null)
              AppNetworkImage(url: remoteHero, alignment: Alignment.topCenter)
            else
              Image.asset(
                SplashScreen.murtiAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.imageScrim),
            ),
            // Keeps the toolbar icons readable over bright photos.
            const Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x66000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.xl,
              child: Semantics(
                container: true,
                label: '${l10n.jaySwaminarayan}. ${l10n.deityName}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.homeGreeting,
                      style: text.titleMedium?.copyWith(
                        color: AppColors.goldLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.homeHeroSubtitle,
                      style: text.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.templeName,
                      style: text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(
    this.icon,
    this.label,
    this.subtitle,
    this.route,
    this.color,
  );

  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final Color color;
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String featuredAlbum =
        ref.watch(appConfigValueProvider).featuredAlbumId ?? 'avsar-200';
    final List<_QuickAction> actions = <_QuickAction>[
      _QuickAction(
        Icons.music_note_rounded,
        l10n.featureKirtan,
        l10n.featureKirtanDesc,
        Routes.kirtan,
        const Color(0xFFC2410C),
      ),
      _QuickAction(
        Icons.place_rounded,
        l10n.featurePlaces,
        l10n.featurePlacesDesc,
        Routes.places,
        const Color(0xFF8C1C13),
      ),
      _QuickAction(
        Icons.photo_library_rounded,
        l10n.featureGallery,
        l10n.featureGalleryDesc,
        Routes.album(featuredAlbum),
        const Color(0xFFA16207),
      ),
      _QuickAction(
        Icons.menu_book_rounded,
        l10n.featureLibrary,
        l10n.featureLibraryDesc,
        Routes.library,
        const Color(0xFF9A3412),
      ),
      _QuickAction(
        Icons.celebration_rounded,
        l10n.featureEvents,
        l10n.featureEventsDesc,
        Routes.events,
        const Color(0xFFB45309),
      ),
      _QuickAction(
        Icons.volunteer_activism_rounded,
        l10n.featureDonate,
        l10n.featureDonateDesc,
        Routes.donate,
        const Color(0xFF7C2D12),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        0,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double gap = AppSpacing.md;
          final int columns = constraints.maxWidth >= 560 ? 6 : 3;
          final double width =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final _QuickAction action in actions)
                SizedBox(
                  width: width,
                  child: _QuickActionTile(action: action),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color tint = dark
        ? Color.lerp(action.color, Colors.white, 0.45)!
        : action.color;
    return Card(
      child: InkWell(
        onTap: () => context.go(action.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: dark ? 0.18 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: tint, size: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonateBanner extends StatelessWidget {
  const _DonateBanner();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        0,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: AppRadius.lgAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.homeDonateTitle,
                      style: text.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.homeDonateBody,
                      style: text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.maroon,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => context.go(Routes.donate),
                      icon: const Icon(Icons.volunteer_activism_rounded),
                      label: Text(l10n.homeDonateCta),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarshanTimingsCard extends ConsumerWidget {
  const _DarshanTimingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppConfig config = ref.watch(appConfigValueProvider);
    if (config.darshanTimings.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        0,
      ),
      child: Card(
        child: InkWell(
          onTap: () => context.go(Routes.about),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      context.l10n.homeDarshanTimings,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (final DarshanTiming timing in config.darshanTimings)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            timing.label.of(context),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        Text(
                          timing.time,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationPrompt extends StatelessWidget {
  const _NotificationPrompt({required this.allowSkip});

  final bool allowSkip;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Padding(
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
              Icons.notifications_active_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.notificationPermissionTitle,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.notificationPermissionBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.notificationAllow),
            ),
          ),
          if (allowSkip) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.notificationLater),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
