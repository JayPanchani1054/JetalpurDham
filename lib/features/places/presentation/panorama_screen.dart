import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';

/// TODO(feature-agent): placeholder until the feature is implemented.
class PanoramaScreen extends StatelessWidget {
  const PanoramaScreen({
    super.key,
    required this.placeId,
    this.initialIndex = 0,
  });

  final String placeId;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.placeView360)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
