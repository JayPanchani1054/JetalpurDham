import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/ui_feedback.dart';

/// Rounded card with an icon + title header, used for each donation step.
class DonationCard extends StatelessWidget {
  const DonationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm + 2),
                    child: Icon(
                      icon,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

/// A "label / value" row that copies the value when tapped anywhere — a large,
/// forgiving target for elderly devotees — with an explicit copy icon.
class CopyableRow extends StatelessWidget {
  const CopyableRow({
    super.key,
    required this.label,
    required this.value,
    this.copyValue,
    this.emphasize = false,
  });

  final String label;
  final String value;

  /// What is copied; defaults to [value] (e.g. account number without spaces).
  final String? copyValue;

  /// Larger, monospaced-looking value for numbers that are typed elsewhere.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String copyLabel = context.l10n.donateCopyLabel(label);
    return Semantics(
      button: true,
      label: '$label, $value',
      hint: copyLabel,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: () => context.copyToClipboard(copyValue ?? value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget + AppSpacing.md,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        value,
                        style:
                            (emphasize
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.titleMedium)
                                ?.copyWith(
                                  letterSpacing: emphasize ? 1.2 : null,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: copyLabel,
                  icon: const Icon(Icons.copy_rounded),
                  color: scheme.primary,
                  onPressed: () => context.copyToClipboard(copyValue ?? value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Calm inline message shown in place of the payment cards.
class DonationInfoCard extends StatelessWidget {
  const DonationInfoCard({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 40, color: scheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
