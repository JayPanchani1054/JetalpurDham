import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/donation/application/donation_qr_saver.dart';
import 'package:jetalpur_dham/features/donation/domain/donation_config.dart';

void main() {
  test('buildQrPainter encodes a UPI link and rejects oversized data', () {
    expect(
      buildQrPainter(buildUpiUri('temple@sbi', 'Shree Mandir')),
      isNotNull,
    );
    expect(buildQrPainter('x' * 5000), isNull);
  });

  test('renderQrPng produces an opaque square PNG', () async {
    final Uint8List bytes = await renderQrPng(
      buildUpiUri('temple@sbi', 'Shree Mandir'),
      size: 256,
    );
    // PNG signature.
    expect(bytes.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);

    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    expect(image.width, 256);
    expect(image.height, 256);

    // The quiet-zone corner is white, never transparent, so the saved QR
    // scans from dark-themed gallery apps too.
    final ByteData? pixels = await image.toByteData();
    expect(pixels, isNotNull);
    expect(pixels!.getUint32(0), 0xFFFFFFFF);
    image.dispose();
    codec.dispose();
  });

  test('renderQrPng throws for data that cannot be encoded', () async {
    await expectLater(renderQrPng('x' * 5000), throwsArgumentError);
  });
}
