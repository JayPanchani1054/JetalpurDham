import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import 'app_logger.dart';

/// Default store link; override with `config/app.shareUrl`.
const String kDefaultShareUrl =
    'https://play.google.com/store/apps/details?id=com.jetalpurdham.app';

Future<void> shareApp(BuildContext context, AppConfig config) async {
  final String message = context.l10n.shareAppMessage(
    config.shareUrl ?? kDefaultShareUrl,
  );
  try {
    await SharePlus.instance.share(ShareParams(text: message));
  } catch (error, stack) {
    AppLogger.error('Share failed', error, stack);
  }
}
