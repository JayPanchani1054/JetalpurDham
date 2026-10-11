import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/menu_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../data/events_repository.dart';
import '../domain/temple_event.dart';
import 'widgets/event_card.dart';

/// Utsav tab: upcoming events (soonest first) and past events (newest first),
/// live from Firestore and readable offline.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const MenuButton(),
          title: Text(l10n.eventsTitle),
          actions: const <Widget>[LanguageButton()],
          bottom: TabBar(
            onTap: (_) => HapticFeedback.selectionClick(),
            tabs: <Widget>[
              Tab(text: l10n.eventsUpcoming),
              Tab(text: l10n.eventsPast),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[_EventsTab(past: false), _EventsTab(past: true)],
        ),
      ),
    );
  }
}

class _EventsTab extends ConsumerWidget {
  const _EventsTab({required this.past});

  final bool past;

  /// Content stays readable on tablets instead of stretching edge to edge.
  static const double _maxContentWidth = 680;

  static EdgeInsets _padding(BoxConstraints constraints) {
    final double side = math.max(
      AppSpacing.page,
      (constraints.maxWidth - _maxContentWidth) / 2,
    );
    return EdgeInsets.fromLTRB(side, AppSpacing.lg, side, AppSpacing.xxl);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<TempleEvent>> events = ref.watch(
      past ? pastEventsProvider : upcomingEventsProvider,
    );
    final DateTime today = ref.watch(eventsTodayProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final EdgeInsets padding = _padding(constraints);
        return AsyncValueView<List<TempleEvent>>(
          value: events,
          onRetry: () => ref.invalidate(eventsProvider),
          loading: _EventListSkeleton(padding: padding),
          isEmpty: (List<TempleEvent> list) => list.isEmpty,
          empty: past
              ? EmptyState(
                  icon: Icons.history_rounded,
                  title: l10n.eventsEmptyPast,
                )
              : EmptyState(
                  icon: Icons.event_available_rounded,
                  title: l10n.eventsEmptyUpcoming,
                  action: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      DefaultTabController.of(context).animateTo(1);
                    },
                    icon: const Icon(Icons.history_rounded),
                    label: Text(l10n.eventsPast),
                  ),
                ),
          data: (List<TempleEvent> list) => ListView.separated(
            key: PageStorageKey<String>(past ? 'events-past' : 'events-next'),
            padding: padding,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (BuildContext context, int index) =>
                EventCard(event: list[index], today: today),
          ),
        );
      },
    );
  }
}

class _EventListSkeleton extends StatelessWidget {
  const _EventListSkeleton({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
        itemBuilder: (_, _) => const EventCardSkeleton(),
      ),
    );
  }
}
