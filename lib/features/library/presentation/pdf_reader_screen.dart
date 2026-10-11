import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';

/// TODO(feature-agent): placeholder until the feature is implemented.
class PdfReaderScreen extends StatelessWidget {
  const PdfReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.libraryTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
