import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/event_schedule.dart';
import '../domain/temple_event.dart';

/// Localized label and icon for each [EventType].
extension EventTypeLabels on EventType {
  String label(AppLocalizations l10n) => switch (this) {
    EventType.utsav => l10n.eventTypeUtsav,
    EventType.katha => l10n.eventTypeKatha,
    EventType.announcement => l10n.eventTypeAnnouncement,
    EventType.other => l10n.eventTypeOther,
  };

  IconData get icon => switch (this) {
    EventType.utsav => Icons.celebration_rounded,
    EventType.katha => Icons.record_voice_over_rounded,
    EventType.announcement => Icons.campaign_rounded,
    EventType.other => Icons.event_rounded,
  };
}

/// "Today", "Tomorrow", "In 3 days", "Ongoing" — or null for past/undated.
extension EventRelativeLabels on EventRelative {
  String? label(AppLocalizations l10n) => switch (when) {
    EventWhen.today => l10n.eventToday,
    EventWhen.tomorrow => l10n.eventTomorrow,
    EventWhen.inDays => l10n.eventInDays(days),
    EventWhen.ongoing => l10n.eventOngoing,
    EventWhen.past || EventWhen.undated => null,
  };
}

/// Shared Hero tag so the banner flies from the list card to the detail page.
String eventHeroTag(String eventId) => 'event-banner-$eventId';
