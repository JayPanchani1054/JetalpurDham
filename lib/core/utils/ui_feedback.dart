import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';

extension UiFeedbackX on BuildContext {
  /// Shows a short message at the bottom of the screen, replacing any current one.
  void showSnack(String message, {SnackBarAction? action}) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  /// Copies [text] and confirms with a snackbar + light haptic.
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    await HapticFeedback.selectionClick();
    if (mounted) showSnack(l10n.copied);
  }

  /// Standard message when a link/app could not be opened.
  void showOpenLinkError() => showSnack(l10n.errorOpenLink);
}
