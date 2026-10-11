import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/share_app.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../data/events_repository.dart';
import '../domain/event_schedule.dart';
import '../domain/temple_event.dart';
import '../domain/temple_time.dart';
import 'event_labels.dart';
import 'widgets/event_card.dart';

/// One utsav / katha: banner, date, time, venue, Watch Live, View Photos,
/// Share and the full description.
///
/// Opened from the list or directly from a push notification
/// (`/events/<id>`), in which case the event is fetched on its own.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EventLookup> lookup = ref.watch(
      eventLookupProvider(eventId),
    );
    // The list (if already loaded) lets the page appear instantly while the
    // single-document listener starts.
    final TempleEvent? fromList = ref.watch(
      eventsProvider.select(
        (AsyncValue<List<TempleEvent>> value) => _find(value.value, eventId),
      ),
    );
    final EventLookup? result = lookup.value;
    final TempleEvent? event =
        result?.event ??
        (result == null || result.isUnavailableOffline ? fromList : null);

    if (event != null) return _EventDetailView(event: event);

    void retry() => ref.invalidate(eventLookupProvider(eventId));
    if (result == null) {
      return lookup.hasError
          ? _MessageScaffold(child: ErrorState(onRetry: retry))
          : const _LoadingScaffold();
    }
    if (result.isUnavailableOffline) {
      return _MessageScaffold(
        child: ErrorState(message: context.l10n.errorNetwork, onRetry: retry),
      );
    }
    return _MessageScaffold(
      child: EmptyState(
        icon: Icons.event_busy_rounded,
        title: context.l10n.eventNotFound,
        action: FilledButton.icon(
          onPressed: () => context.go(Routes.events),
          icon: const Icon(Icons.celebration_rounded),
          label: Text(context.l10n.eventsBrowseAll),
        ),
      ),
    );
  }

  static TempleEvent? _find(List<TempleEvent>? events, String id) {
    if (events == null) return null;
    for (final TempleEvent event in events) {
      if (event.id == id) return event;
    }
    return null;
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.eventsTitle),
      actions: const <Widget>[LanguageButton()],
    ),
    body: child,
  );
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const <Widget>[LanguageButton()]),
      body: Skeleton(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.page),
          children: const <Widget>[
            EventCardSkeleton(),
            SizedBox(height: AppSpacing.xl),
            SkeletonBox(height: 120, borderRadius: AppRadius.lgAll),
            SizedBox(height: AppSpacing.xl),
            SkeletonBox(height: 52, borderRadius: AppRadius.mdAll),
          ],
        ),
      ),
    );
  }
}

class _EventDetailView extends ConsumerStatefulWidget {
  const _EventDetailView({required this.event});

  final TempleEvent event;

  @override
  ConsumerState<_EventDetailView> createState() => _EventDetailViewState();
}

class _EventDetailViewState extends ConsumerState<_EventDetailView> {
  static const double _maxContentWidth = 720;

  final ScrollController _scroll = ScrollController();
  double _collapseOffset = 200;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Rebuilds only when the app bar flips between "over the banner" (white
  /// icons) and "collapsed" (theme colors).
  void _onScroll() {
    final bool collapsed =
        _scroll.hasClients && _scroll.offset >= _collapseOffset;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final TempleEvent event = widget.event;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final String lang = context.appLanguage.code;
    final DateTime today = ref.watch(eventsTodayProvider);
    final EventRelative relative = relativeEventTime(event, today);

    final Size screen = MediaQuery.sizeOf(context);
    final double bannerHeight = math.min(
      screen.width * 9 / 16,
      screen.height * 0.42,
    );
    _collapseOffset = math.max(0, bannerHeight - kToolbarHeight - 24);

    final bool dark = theme.brightness == Brightness.dark;
    final Color barForeground = _collapsed ? scheme.onSurface : Colors.white;
    final SystemUiOverlayStyle overlay = _collapsed && !dark
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;

    final String title = event.titleIn(lang);
    final String body = event.body.resolve(lang);
    final String venue = event.location.resolve(lang);
    final String? dateText = _dateText(event, lang);
    final String? timeText = _timeText(event, lang, l10n);
    // "Watch Live" only while the event is upcoming or happening (undated
    // announcements keep their link too).
    final String? liveUrl = relative.when == EventWhen.past
        ? null
        : event.liveUrl;
    final String? albumId = event.albumId;
    final double side = math.max(
      AppSpacing.page,
      (screen.width - _maxContentWidth) / 2,
    );

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: bannerHeight,
            backgroundColor: scheme.surface,
            foregroundColor: barForeground,
            iconTheme: IconThemeData(color: barForeground),
            actionsIconTheme: IconThemeData(color: barForeground),
            systemOverlayStyle: overlay.copyWith(
              statusBarColor: Colors.transparent,
            ),
            // Only shown (and read by screen readers) once the banner has
            // scrolled away; the large title below is the heading until then.
            title: ExcludeSemantics(
              excluding: !_collapsed,
              child: AnimatedOpacity(
                opacity: _collapsed ? 1 : 0,
                duration: AppDurations.fast,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            actions: <Widget>[
              Builder(
                builder: (BuildContext context) => IconButton(
                  tooltip: l10n.share,
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => _share(context, event),
                ),
              ),
              LanguageButton(foregroundColor: barForeground),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Hero(
                    tag: eventHeroTag(event.id),
                    child: EventBanner(event: event),
                  ),
                  // Keeps the white toolbar icons readable on bright banners.
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
                            colors: <Color>[
                              Color(0x73000000),
                              Color(0x00000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              side,
              AppSpacing.xl,
              side,
              AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    EventTypeChip(type: event.type),
                    EventRelativeChip(relative: relative),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: SelectableText(
                    title,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                if (dateText != null || timeText != null || venue.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          children: <Widget>[
                            if (dateText != null)
                              _InfoRow(
                                icon: Icons.calendar_month_rounded,
                                label: l10n.eventDate,
                                value: dateText,
                              ),
                            if (timeText != null)
                              _InfoRow(
                                icon: Icons.schedule_rounded,
                                label: l10n.eventTime,
                                value: timeText,
                              ),
                            if (venue.isNotEmpty)
                              _InfoRow(
                                icon: Icons.place_rounded,
                                label: l10n.eventLocation,
                                value: venue,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                if (liveUrl != null) ...<Widget>[
                  FilledButton.icon(
                    onPressed: () => _openLive(context, liveUrl),
                    icon: const Icon(Icons.live_tv_rounded),
                    label: Text(l10n.eventWatchLive),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (albumId != null) ...<Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.go(Routes.album(albumId));
                    },
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(l10n.eventViewPhotos),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Builder(
                  builder: (BuildContext context) => OutlinedButton.icon(
                    onPressed: () => _share(context, event),
                    icon: const Icon(Icons.share_rounded),
                    label: Text(l10n.share),
                  ),
                ),
                if (body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.eventsDetails,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(
                    body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      height: 1.7,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLive(BuildContext context, String url) async {
    HapticFeedback.selectionClick().ignore();
    final bool opened = await Launcher.url(url);
    if (!opened && context.mounted) context.showOpenLinkError();
  }

  Future<void> _share(BuildContext context, TempleEvent event) async {
    HapticFeedback.selectionClick().ignore();
    final AppLocalizations l10n = context.l10n;
    final String lang = context.appLanguage.code;
    final String link =
        ref.read(appConfigValueProvider).shareUrl ?? kDefaultShareUrl;
    final String? date = _dateText(event, lang)?.replaceAll('\n', ' ');
    final String? time = _timeText(event, lang, l10n);
    final String text = buildEventShareText(
      title: event.titleIn(lang),
      when: <String?>[date, time].whereType<String>().join(', '),
      venue: event.location.resolve(lang),
      excerpt: eventExcerpt(event.body.resolve(lang)),
      footer: '${l10n.jaySwaminarayan}\n${l10n.templeName}\n$link',
    );
    final RenderObject? box = context.findRenderObject();
    final Rect? origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: event.titleIn(lang),
          sharePositionOrigin: origin,
        ),
      );
    } catch (error, stack) {
      AppLogger.error('Event share failed', error, stack);
      if (context.mounted) context.showSnack(l10n.errorGeneric);
    }
  }

  /// "Sunday, 12 October 2026", or a two-line range for multi-day utsav.
  static String? _dateText(TempleEvent event, String locale) {
    final DateTime? start = event.startAt;
    if (start == null) return null;
    final String from = Formatters.longDate(start, locale);
    final DateTime? end = event.endAt;
    if (end != null && event.isMultiDay) {
      return '$from –\n${Formatters.longDate(end, locale)}';
    }
    return from;
  }

  /// "7:30 PM" or "7:30 PM – 10:00 PM"; null when no time was entered.
  /// Times are temple (India) time: phones set to another time zone get an
  /// "(India time)" hint so devotees abroad are not misled.
  static String? _timeText(
    TempleEvent event,
    String locale,
    AppLocalizations l10n,
  ) {
    final DateTime? start = event.startAt;
    if (start == null || !hasTimeOfDay(start)) return null;
    String text = Formatters.time(start, locale);
    if (text.isEmpty) return null;
    final DateTime? end = event.endAt;
    if (end != null &&
        !event.isMultiDay &&
        hasTimeOfDay(end) &&
        end.isAfter(start)) {
      final String until = Formatters.time(end, locale);
      if (until.isNotEmpty) text = '$text – $until';
    }
    return TempleTime.isDeviceOutsideIndia()
        ? l10n.eventsIndiaTime(text)
        : text;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(value, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
