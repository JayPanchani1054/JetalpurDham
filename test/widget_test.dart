import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/models/localized_text.dart';

void main() {
  test('LocalizedText falls back to English', () {
    final LocalizedText text = LocalizedText.fromValue(<String, Object?>{
      'en': 'Kirtan',
      'gu': 'કીર્તન',
    });
    expect(text.resolve('gu'), 'કીર્તન');
    expect(text.resolve('hi'), 'Kirtan');
  });
}
