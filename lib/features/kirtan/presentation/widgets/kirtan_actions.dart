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
  unawaited(HapticFeedback.selectionClick());
  final KirtanPlayerController controller = ref.read(
    kirtanPlayerProvider.notifier,
  );
  if (ref.read(currentKirtanProvider)?.id == list[index].id) {
    if (!ref.read(kirtanIsPlayingProvider)) {
      unawaited(controller.togglePlayPause());
    }
    unawaited(context.push<void>(Routes.player));
    return;
  }
  unawaited(controller.playKirtans(list, startIndex: index));
}
