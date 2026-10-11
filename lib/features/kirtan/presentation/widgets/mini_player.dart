import 'package:material_ui/material_ui.dart';

/// Persistent mini player shown above the bottom navigation bar while a kirtan is loaded. Must render SizedBox.shrink() when nothing is playing.
///
/// TODO(feature-agent): placeholder until the feature is implemented.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
