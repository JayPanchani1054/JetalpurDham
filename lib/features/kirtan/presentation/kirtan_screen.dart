import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';

/// TODO(feature-agent): placeholder until the feature is implemented.
class KirtanScreen extends StatelessWidget {
  const KirtanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.kirtanTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
