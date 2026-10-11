import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/donation/data/donation_repository.dart';
import 'package:jetalpur_dham/features/donation/domain/donation_request.dart';

const DonationRequest _request = DonationRequest(
  name: 'Ramesh Patel',
  phone: '+919876543210',
  method: DonationMethod.upi,
  language: 'en',
  platform: 'android',
  amount: 501,
);

const Object _serverTime = Object();

void main() {
  test('returns sent when the server acknowledges the write', () async {
    final List<Map<String, Object?>> written = <Map<String, Object?>>[];
    final DonationRepository repository = DonationRepository(
      addDocument: (Map<String, Object?> data) async => written.add(data),
      appVersion: () async => '1.2.3+4',
    );

    final DonationSubmitResult result = await repository.submit(
      _request,
      createdAt: _serverTime,
    );

    expect(result, DonationSubmitResult.sent);
    expect(written, hasLength(1));
    expect(written.single['appVersion'], '1.2.3+4');
    expect(written.single['status'], 'new');
    expect(written.single['createdAt'], same(_serverTime));
    expect(written.single['amount'], 501);
  });

  test('treats a missing acknowledgement as queued (offline)', () async {
    final Completer<void> ack = Completer<void>();
    final DonationRepository repository = DonationRepository(
      addDocument: (Map<String, Object?> data) => ack.future,
      appVersion: () async => '1.0.0',
      ackTimeout: const Duration(milliseconds: 20),
    );

    final DonationSubmitResult result = await repository.submit(
      _request,
      createdAt: _serverTime,
    );
    expect(result, DonationSubmitResult.queued);

    // A late rejection must not surface as an unhandled error.
    ack.completeError(StateError('permission-denied'));
    await Future<void>.delayed(Duration.zero);
  });

  test('a per-call timeout overrides the default', () async {
    final DonationRepository repository = DonationRepository(
      addDocument: (Map<String, Object?> data) => Completer<void>().future,
      appVersion: () async => '1.0.0',
      ackTimeout: const Duration(minutes: 1),
    );
    final DonationSubmitResult result = await repository.submit(
      _request,
      timeout: const Duration(milliseconds: 10),
      createdAt: _serverTime,
    );
    expect(result, DonationSubmitResult.queued);
  });

  test('rethrows when the write is rejected immediately', () async {
    final DonationRepository repository = DonationRepository(
      addDocument: (Map<String, Object?> data) =>
          Future<void>.error(StateError('permission-denied')),
      appVersion: () async => '1.0.0',
    );
    await expectLater(
      repository.submit(_request, createdAt: _serverTime),
      throwsStateError,
    );
  });

  test('still submits when the app version cannot be read', () async {
    Map<String, Object?>? written;
    final DonationRepository repository = DonationRepository(
      addDocument: (Map<String, Object?> data) async => written = data,
      appVersion: () => Future<String>.error(Exception('no plugin')),
    );
    await repository.submit(_request, createdAt: _serverTime);
    expect(written?['appVersion'], 'unknown');
  });
}
