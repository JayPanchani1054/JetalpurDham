import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/router/routes.dart';
import '../../application/kirtan_player_controller.dart';
import '../../domain/kirtan.dart';

/// Row/card tap: plays [list] from [index]. Tapping the kirtan that is
/// already loaded resumes it (if paused) and opens the full player instead of
/// restarting it.
void playKirtanFromList(
  BuildContext context,
  WidgetRef ref,
  List<Kirtan> list,
  int index,
) {
  if (index < 0 || index >= list.length) return;
  HapticFeedback.selectionClick().ignore();
  final KirtanPlayerController controller = ref.read(
    kirtanPlayerProvider.notifier,
  );
  if (ref.read(currentKirtanProvider)?.id == list[index].id) {
    // Never pauses: a double tap on a row that is still loading must not
    // cancel its start.
    unawaited(controller.resume());
    openKirtanPlayer(context);
    return;
  }
  unawaited(controller.playKirtans(list, startIndex: index));
}

DateTime _lastPlayerOpen = DateTime.fromMillisecondsSinceEpoch(0);

/// Opens Now Playing once: repeated taps (common with a double tap) and taps
/// while it is already open are ignored.
void openKirtanPlayer(BuildContext context) {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router == null) return;
  final DateTime now = DateTime.now();
  if (now.difference(_lastPlayerOpen) < const Duration(milliseconds: 800)) {
    return;
  }
  try {
    if (router.state.uri.path == Routes.player) return;
  } catch (_) {
    // No route yet: open it.
  }
  _lastPlayerOpen = now;
  unawaited(router.push<void>(Routes.player));
}
