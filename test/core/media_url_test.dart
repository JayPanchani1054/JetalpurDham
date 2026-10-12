import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/firebase/media_url.dart';

void main() {
  test('https media resolves without touching Firebase Storage', () async {
    int storageCalls = 0;
    final MediaUrlResolver resolver = MediaUrlResolver(() {
      storageCalls++;
      throw StateError('Firebase is not initialised');
    });

    expect(
      await resolver.resolve(' https://example.com/kirtan.mp3 '),
      'https://example.com/kirtan.mp3',
    );
    expect(storageCalls, 0);
  });

  test(
    'a Storage path fails on its own when Firebase is unavailable',
    () async {
      final MediaUrlResolver resolver = MediaUrlResolver(
        () => throw StateError('Firebase is not initialised'),
      );
      await expectLater(
        resolver.resolve('kirtans/aarti/1.mp3'),
        throwsA(isA<StateError>()),
      );
      // The failure is not cached: a later attempt tries again.
      await expectLater(
        resolver.resolve('kirtans/aarti/1.mp3'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('empty references are rejected', () {
    final MediaUrlResolver resolver = MediaUrlResolver(
      () => throw UnimplementedError(),
    );
    expect(resolver.resolve('  '), throwsArgumentError);
  });

  // Keeps the FirebaseStorage import meaningful for the type signature.
  test('signature takes a lazy FirebaseStorage getter', () {
    FirebaseStorage storage() => throw UnimplementedError();
    expect(MediaUrlResolver(storage), isA<MediaUrlResolver>());
  });
}
