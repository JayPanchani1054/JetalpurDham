import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/widgets/expandable_text.dart';
import '../../core/widgets/language_button.dart';
import '../splash/splash_screen.dart';

/// Temple history, darshan timings, address and contact options — all driven
/// by the `config/app` document.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppConfig config = ref.watch(appConfigValueProvider);
    final ThemeData theme = Theme.of(context);
    final String about = config.about.of(context);
    final String address = config.address.of(context);

    Future<void> run(Future<bool> Function() action) async {
      if (!await action() && context.mounted) context.showOpenLinkError();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
        actions: const <Widget>[LanguageButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          Padding(
            padding: AppSpacing.pagePadding,
            child: ClipRRect(
              borderRadius: AppRadius.lgAll,
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(
                      SplashScreen.murtiAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(gradient: AppColors.imageScrim),
                    ),
                    Positioned(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.deityName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            config.templeName.isEmpty
                                ? l10n.templeName
                                : config.templeName.of(context),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
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
          if (about.isNotEmpty)
            _Section(
              icon: Icons.history_edu_rounded,
              title: l10n.aboutHistory,
              child: ExpandableText(about, collapsedLines: 8),
            ),
          if (config.darshanTimings.isNotEmpty)
            _Section(
              icon: Icons.schedule_rounded,
              title: l10n.aboutDarshanTimings,
              child: Column(
                children: <Widget>[
                  for (final DarshanTiming timing in config.darshanTimings)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs + 2,
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
          _Section(
            icon: Icons.location_on_rounded,
            title: l10n.aboutAddress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (address.isNotEmpty)
                  SelectableText(address, style: theme.textTheme.bodyLarge),
                if (config.hasLocation) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonalIcon(
                    onPressed: () => run(
                      () => Launcher.directions(
                        config.latitude!,
                        config.longitude!,
                      ),
                    ),
                    icon: const Icon(Icons.directions_rounded),
                    label: Text(l10n.aboutGetDirections),
                  ),
                ],
              ],
            ),
          ),
          if (config.phone != null ||
              config.whatsapp != null ||
              config.email != null ||
              config.website != null)
            _Section(
              icon: Icons.contact_phone_rounded,
              title: l10n.aboutContact,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  if (config.phone != null)
                    _ContactChip(
                      icon: Icons.call_rounded,
                      label: l10n.aboutCall,
                      onTap: () => run(() => Launcher.phone(config.phone!)),
                    ),
                  if (config.whatsapp != null)
                    _ContactChip(
                      icon: Icons.chat_rounded,
                      label: l10n.aboutWhatsApp,
                      onTap: () => run(
                        () => Launcher.whatsApp(
                          config.whatsapp!,
                          message: l10n.jaySwaminarayan,
                        ),
                      ),
                    ),
                  if (config.email != null)
                    _ContactChip(
                      icon: Icons.email_rounded,
                      label: l10n.aboutEmail,
                      onTap: () => run(() => Launcher.email(config.email!)),
                    ),
                  if (config.website != null)
                    _ContactChip(
                      icon: Icons.language_rounded,
                      label: l10n.aboutWebsite,
                      onTap: () => run(() => Launcher.url(config.website!)),
                    ),
                ],
              ),
            ),
          if (config.youtube != null ||
              config.facebook != null ||
              config.instagram != null)
            _Section(
              icon: Icons.favorite_rounded,
              title: l10n.aboutFollowUs,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  if (config.youtube != null)
                    _ContactChip(
                      icon: Icons.smart_display_rounded,
                      label: 'YouTube',
                      onTap: () => run(() => Launcher.url(config.youtube!)),
                    ),
                  if (config.facebook != null)
                    _ContactChip(
                      icon: Icons.facebook_rounded,
                      label: 'Facebook',
                      onTap: () => run(() => Launcher.url(config.facebook!)),
                    ),
                  if (config.instagram != null)
                    _ContactChip(
                      icon: Icons.camera_alt_rounded,
                      label: 'Instagram',
                      onTap: () => run(() => Launcher.url(config.instagram!)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onPressed: onTap,
  );
}
