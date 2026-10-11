import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_spacing.dart';

/// Long text collapsed to [collapsedLines] with a "Read more" toggle.
class ExpandableText extends StatefulWidget {
  const ExpandableText(
    this.text, {
    super.key,
    this.collapsedLines = 6,
    this.style,
  });

  final String text;
  final int collapsedLines;
  final TextStyle? style;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final TextStyle style =
        widget.style ?? Theme.of(context).textTheme.bodyLarge!;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final bool overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AnimatedSize(
              duration: AppDurations.medium,
              alignment: Alignment.topCenter,
              child: _expanded || !overflows
                  ? SelectableText(widget.text, style: style)
                  : Text(
                      widget.text,
                      style: style,
                      maxLines: widget.collapsedLines,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (overflows)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? context.l10n.showLess : context.l10n.readMore,
                ),
              ),
          ],
        );
      },
    );
  }
}
