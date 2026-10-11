import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/events_repository.dart';
import '../../domain/event_schedule.dart';
import '../../domain/temple_event.dart';
import 'event_card.dart';

/// Home section: header + upcoming utsav cards (hidden when there are none).
///
/// A skeleton is shown only during the very first load; errors and an empty
/// list simply hide the section so Home always looks complete.
class HomeUpcomingEvents extends ConsumerWidget {
  const HomeUpcomingEvents({super.key});

  static const int _maxCards = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TempleEvent>> value = ref.watch(
      upcomingEventsProvider,
    );
    final List<TempleEvent>? events = value.value;
    if (events == null) {
      return value.hasError ? const SizedBox.shrink() : const _Skeleton();
    }
    if (events.isEmpty) return const SizedBox.shrink();

    final DateTime today = ref.watch(eventsTodayProvider);
    final List<TempleEvent> shown = events.length > _maxCards
        ? events.sublist(0, _maxCards)
        : events;
    final _CardMetrics metrics = _CardMetrics.of(context);
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l10n.homeUpcomingTitle,
          actionLabel: l10n.seeAll,
          onAction: () {
            HapticFeedback.selectionClick();
            context.go(Routes.events);
          },
        ),
        SizedBox(
          height: metrics.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.pagePadding,
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) => SizedBox(
              width: metrics.width,
              child: _HomeEventCard(event: shown[index], today: today),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card size for the horizontal list. The height follows the user's text
/// size so the two-line title never overflows.
class _CardMetrics {
  const _CardMetrics(this.width, this.imageHeight, this.titleLine);

  factory _CardMetrics.of(BuildContext context) {
    final double width = (MediaQuery.sizeOf(context).width * 0.72).clamp(
      240.0,
      320.0,
    );
    final TextStyle style = Theme.of(context).textTheme.titleSmall!;
    final double line =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 15) *
        (style.height ?? 1.4);
    return _CardMetrics(width, width * 9 / 16, line);
  }

  final double width;
  final double imageHeight;
  final double titleLine;

  static const double _padding = AppSpacing.md;

  double get titleBlock => titleLine * 2 + 2;

  /// Image + padding + two title lines (+ a hair of slack for rounding).
  double get height => imageHeight + _padding * 2 + titleBlock + 2;
}

class _HomeEventCard extends StatelessWidget {
  const _HomeEventCard({required this.event, required this.today});

  final TempleEvent event;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _CardMetrics metrics = _CardMetrics.of(context);
    final DateTime? start = event.startAt;
    return EventTapCard(
      onTap: () {
        HapticFeedback.selectionClick();
        context.go(Routes.event(event.id));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: metrics.imageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                EventBanner(event: event),
                if (start != null)
                  PositionedDirectional(
                    start: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: EventDateBadge(date: start, compact: true),
                  ),
                PositionedDirectional(
                  end: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  start: AppSpacing.xxl * 2,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: EventRelativeChip(
                      relative: relativeEventTime(event, today),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(_CardMetrics._padding),
            child: SizedBox(
              height: metrics.titleBlock,
              child: Text(
                event.titleIn(context.appLanguage.code),
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final _CardMetrics metrics = _CardMetrics.of(context);
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xl,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: SkeletonBox(width: 180, height: 22),
          ),
          SizedBox(
            height: metrics.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: AppSpacing.pagePadding,
              itemCount: 2,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, _) => SkeletonBox(
                width: metrics.width,
                height: metrics.height,
                borderRadius: AppRadius.lgAll,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
