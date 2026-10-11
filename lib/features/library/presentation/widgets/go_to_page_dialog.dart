import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../domain/library_queries.dart';

/// Asks for a page number between 1 and [pageCount]. Returns the page, or
/// null when cancelled.
Future<int?> showGoToPageDialog(
  BuildContext context, {
  required int currentPage,
  required int pageCount,
}) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext context) =>
        _GoToPageDialog(currentPage: currentPage, pageCount: pageCount),
  );
}

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.currentPage, required this.pageCount});

  final int currentPage;
  final int pageCount;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.currentPage}')
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: '${widget.currentPage}'.length,
        );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final int? page = parsePageInput(_controller.text, widget.pageCount);
    if (page == null) {
      setState(() => _error = context.l10n.readerInvalidPage(widget.pageCount));
      return;
    }
    Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.find_in_page_rounded),
      title: Text(l10n.readerGoToPage),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.go,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(7),
        ],
        style: Theme.of(context).textTheme.titleLarge,
        decoration: InputDecoration(
          labelText: l10n.libraryReaderPageInputLabel(widget.pageCount),
          errorText: _error,
          errorMaxLines: 2,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.libraryReaderGo)),
      ],
    );
  }
}
