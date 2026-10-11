import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/gallery/presentation/widgets/gallery_hero.dart';
import 'package:material_ui/material_ui.dart';

const Key _small = Key('small');
const Key _large = Key('large');

Widget _hero(Key key, double width, double height) => Hero(
  tag: 'photo',
  flightShuttleBuilder: galleryHeroShuttle,
  child: SizedBox(
    key: key,
    width: width,
    height: height,
    child: const ColoredBox(color: Color(0xFF8C1C13)),
  ),
);

void main() {
  testWidgets('flies with the larger image scaled to cover, both ways', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: _hero(_small, 100, 100),
          ),
        ),
      ),
    );

    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              Scaffold(body: Center(child: _hero(_large, 300, 200))),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-flight the shuttle renders the large hero's child at its own
    // size inside a covering FittedBox.
    final Finder shuttle = find.ancestor(
      of: find.byKey(_large),
      matching: find.byType(FittedBox),
    );
    expect(shuttle, findsOneWidget);
    expect(tester.widget<FittedBox>(shuttle).fit, BoxFit.cover);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.ancestor(of: find.byKey(_large), matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_small), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
