import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';

/// TODO(feature-agent): placeholder until the feature is implemented.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.kirtanNowPlaying)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
