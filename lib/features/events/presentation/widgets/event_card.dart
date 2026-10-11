import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/event_schedule.dart';
import '../../domain/temple_event.dart';
import '../event_labels.dart';

/// Full-width event card used on the Utsav tab: 16:9 banner with a date
/// badge, type and relative-time chips, title and a two-line summary.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.today});

  final TempleEvent event;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String lang = context.appLanguage.code;
    final String summary = event.shortDescription.resolve(lang);
    final DateTime? start = event.startAt;
    return MergeSemantics(
      child: Card(
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.go(Routes.event(event.id));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Hero(
                      tag: eventHeroTag(event.id),
                      child: EventBanner(event: event),
                    ),
                    if (start != null)
                      PositionedDirectional(
                        start: AppSpacing.md,
                        top: AppSpacing.md,
                        child: EventDateBadge(date: start),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        EventTypeChip(type: event.type),
                        EventRelativeChip(
                          relative: relativeEventTime(event, today),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      event.titleIn(lang),
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

/// The event banner, or a warm saffron artwork with the type icon when the
/// temple has not uploaded one.
class EventBanner extends StatelessWidget {
  const EventBanner({super.key, required this.event});

  final TempleEvent event;

  @override
  Widget build(BuildContext context) {
    final String? url = event.bannerUrl;
    if (url == null || url.isEmpty) {
      return DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Center(
          child: Icon(
            event.type.icon,
            size: 56,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      );
    }
    return AppNetworkImage(url: url, placeholderIcon: event.type.icon);
  }
}

/// Calendar-style badge (day number over short month) placed on banners.
class EventDateBadge extends StatelessWidget {
  const EventDateBadge({super.key, required this.date, this.compact = false});

  final DateTime date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String locale = context.appLanguage.code;
    final String day = Formatters.day(date, locale);
    final String month = Formatters.shortMonth(date, locale);
    return Semantics(
      label: Formatters.longDate(date, locale),
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minWidth: compact ? 48 : 56),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: compact ? AppSpacing.xs : AppSpacing.sm - 2,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.mdAll,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              day.isEmpty ? '${date.day}' : day,
              style:
                  (compact
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
            ),
            if (month.isNotEmpty)
              Text(
                month,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small pill with the event type (Utsav, Katha…).
class EventTypeChip extends StatelessWidget {
  const EventTypeChip({super.key, required this.type});

  final EventType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return EventPill(
      icon: type.icon,
      label: type.label(context.l10n),
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
    );
  }
}

/// "Today" / "Tomorrow" / "In 3 days" / "Ongoing" pill; nothing for past.
class EventRelativeChip extends StatelessWidget {
  const EventRelativeChip({super.key, required this.relative});

  final EventRelative relative;

  @override
  Widget build(BuildContext context) {
    final String? label = relative.label(context.l10n);
    if (label == null) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool now = relative.isNow;
    return EventPill(
      icon: now ? Icons.fiber_manual_record_rounded : Icons.schedule_rounded,
      iconSize: now ? 12 : 16,
      label: label,
      background: now ? scheme.primary : scheme.primaryContainer,
      foreground: now ? scheme.onPrimary : scheme.onPrimaryContainer,
    );
  }
}

/// Non-interactive rounded label with an icon.
class EventPill extends StatelessWidget {
  const EventPill({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.iconSize = 16,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: iconSize, color: foreground),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder with the same shape as [EventCard] (wrap in [Skeleton]).
class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: SkeletonBox(
            height: double.infinity,
            borderRadius: AppRadius.lgAll,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SkeletonBox(
            width: 120,
            height: 24,
            borderRadius: AppRadius.lgAll,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 18),
        SizedBox(height: AppSpacing.sm),
        FractionallySizedBox(
          widthFactor: 0.6,
          alignment: AlignmentDirectional.centerStart,
          child: SkeletonBox(height: 14),
        ),
      ],
    );
  }
}
