import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';

/// Key of the root shell [Scaffold] that owns the navigation drawer.
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>(
  debugLabel: 'shellScaffold',
);

/// Opens the app drawer (menu). Use as `AppBar.leading` on tab screens, which
/// sit in their own nested Scaffold.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.menu,
      icon: Icon(Icons.menu_rounded, color: color),
      onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
    );
  }
}
