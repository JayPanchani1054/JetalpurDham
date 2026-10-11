import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('haptic in test', (WidgetTester tester) async {
    Object? err;
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      err = e;
    }
    // ignore: avoid_print
    print('haptic error: $err');
    expect(find.byType(BottomSheet), findsNothing);
  });
}
