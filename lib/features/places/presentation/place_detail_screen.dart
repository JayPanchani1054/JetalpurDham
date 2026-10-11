import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';

/// TODO(feature-agent): placeholder until the feature is implemented.
class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.placesTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
