import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/features/donation/domain/donation_request.dart';

/// Field names allowed by `isValidDonationRequest` in firestore.rules.
const Set<String> _allowedKeys = <String>{
  'name',
  'phone',
  'email',
  'amount',
  'purpose',
  'method',
  'transactionRef',
  'message',
  'language',
  'platform',
  'appVersion',
  'status',
  'createdAt',
};

const Object _serverTime = Object();

void main() {
  group('DonationValidators.normalizePhone', () {
    test('accepts 10-digit Indian mobiles with optional prefixes', () {
      for (final String input in <String>[
        '9876543210',
        '98765 43210',
        '98765-43210',
        '+91 98765 43210',
        '+919876543210',
        '919876543210',
        '09876543210',
        '0091 98765 43210',
        ' (+91) 98765-43210 ',
      ]) {
        expect(
          DonationValidators.normalizePhone(input),
          '+919876543210',
          reason: input,
        );
      }
    });

    test('accepts international numbers for devotees abroad', () {
      expect(
        DonationValidators.normalizePhone('+44 7700 900123'),
        '+447700900123',
      );
      expect(
        DonationValidators.normalizePhone('001 415 555 0100'),
        '+14155550100',
      );
    });

    test('rejects invalid numbers', () {
      for (final String input in <String>[
        '',
        '12345',
        '1234567890', // Indian mobiles start with 6-9
        '98765432101', // 11 digits without a 0 prefix
        '+91 12345 67890',
        '+91 98765',
        '98765abcde',
        '+0123456789',
        '+1234567', // too short
        '+1234567890123456', // too long
        '++919876543210',
      ]) {
        expect(DonationValidators.normalizePhone(input), isNull, reason: input);
      }
    });

    test('phone validator distinguishes empty from invalid', () {
      expect(DonationValidators.phone(''), DonationFieldError.required);
      expect(DonationValidators.phone('  '), DonationFieldError.required);
      expect(DonationValidators.phone('123'), DonationFieldError.invalidPhone);
      expect(DonationValidators.phone('9876543210'), isNull);
    });
  });

  group('DonationValidators.parseAmount', () {
    test('accepts whole rupees in common formats', () {
      expect(DonationValidators.parseAmount('1001'), 1001);
      expect(DonationValidators.parseAmount('1,001'), 1001);
      expect(DonationValidators.parseAmount('1,00,000'), 100000);
      expect(DonationValidators.parseAmount('₹ 501'), 501);
      expect(DonationValidators.parseAmount('Rs. 251'), 251);
      expect(DonationValidators.parseAmount('501.00'), 501);
      expect(DonationValidators.parseAmount('10000000'), 10000000);
    });

    test('rejects non-amounts and values outside the allowed range', () {
      expect(DonationValidators.parseAmount('0'), isNull);
      expect(DonationValidators.parseAmount('10000001'), isNull);
      expect(DonationValidators.parseAmount('501.50'), isNull);
      expect(DonationValidators.parseAmount('-5'), isNull);
      expect(DonationValidators.parseAmount('abc'), isNull);
      expect(DonationValidators.parseAmount('99999999999999999999999'), isNull);
    });

    test('amount is optional', () {
      expect(DonationValidators.amount(null), isNull);
      expect(DonationValidators.amount(''), isNull);
      expect(DonationValidators.amount('x'), DonationFieldError.invalidAmount);
    });
  });

  group('other validators', () {
    test('name is required and at least two characters', () {
      expect(DonationValidators.name(null), DonationFieldError.required);
      expect(DonationValidators.name('  '), DonationFieldError.required);
      expect(DonationValidators.name(' A '), DonationFieldError.invalidName);
      expect(DonationValidators.name('Om'), isNull);
      expect(DonationValidators.name('x' * 81), DonationFieldError.invalidName);
    });

    test('email is optional but must look valid', () {
      expect(DonationValidators.email(''), isNull);
      expect(DonationValidators.email('bhakt@example.com'), isNull);
      expect(
        DonationValidators.email('bhakt@example'),
        DonationFieldError.invalidEmail,
      );
      expect(
        DonationValidators.email('bhakt example.com'),
        DonationFieldError.invalidEmail,
      );
      expect(
        DonationValidators.email('${'a' * 250}@b.com'),
        DonationFieldError.invalidEmail,
      );
    });

    test('method is required', () {
      expect(DonationValidators.method(null), DonationFieldError.required);
      expect(DonationValidators.method(DonationMethod.upi), isNull);
    });
  });

  group('DonationRequest.toFirestore', () {
    test('writes required fields and omits blank optional ones', () {
      const DonationRequest request = DonationRequest(
        name: '  Ramesh Patel ',
        phone: '+919876543210',
        method: DonationMethod.cash,
        language: 'gu',
        platform: 'android',
        email: '  ',
        transactionRef: '',
      );
      final Map<String, Object?> data = request.toFirestore(
        appVersion: '1.0.0+1',
        createdAt: _serverTime,
      );
      expect(data, <String, Object?>{
        'name': 'Ramesh Patel',
        'phone': '+919876543210',
        'method': 'cash',
        'language': 'gu',
        'platform': 'android',
        'appVersion': '1.0.0+1',
        'status': 'new',
        'createdAt': _serverTime,
      });
      expect(data.values, isNot(contains(null)));
    });

    test('includes every filled field, all allowed by the rules', () {
      const DonationRequest request = DonationRequest(
        name: 'Ramesh Patel',
        phone: '+919876543210',
        method: DonationMethod.upi,
        language: 'en',
        platform: 'ios',
        email: 'ramesh@example.com',
        amount: 1001,
        purpose: 'Annakut',
        transactionRef: 'UTR123',
        message: 'Jay Swaminarayan',
      );
      final Map<String, Object?> data = request.toFirestore(
        appVersion: '1.0.0+1',
        createdAt: _serverTime,
      );
      expect(data.keys.toSet(), _allowedKeys);
      expect(data['amount'], 1001);
      expect(data['method'], 'upi');
      expect(data['email'], 'ramesh@example.com');
      expect(data['purpose'], 'Annakut');
      expect(data['transactionRef'], 'UTR123');
      expect(data['message'], 'Jay Swaminarayan');
    });

    test('caps text to the lengths the security rules accept', () {
      final DonationRequest request = DonationRequest(
        name: 'N' * 200,
        phone: '+919876543210',
        method: DonationMethod.other,
        language: 'fr',
        platform: 'a-very-long-platform-name',
        message: 'm' * 2000,
        purpose: 'p' * 500,
        transactionRef: 't' * 500,
        amount: 0,
      );
      final Map<String, Object?> data = request.toFirestore(
        appVersion: 'v' * 100,
        createdAt: _serverTime,
      );
      expect((data['name']! as String).length, DonationLimits.nameMax);
      expect((data['message']! as String).length, DonationLimits.messageMax);
      expect((data['purpose']! as String).length, DonationLimits.purposeMax);
      expect(
        (data['transactionRef']! as String).length,
        DonationLimits.transactionRefMax,
      );
      expect((data['platform']! as String).length, DonationLimits.platformMax);
      expect(
        (data['appVersion']! as String).length,
        DonationLimits.appVersionMax,
      );
      expect(data.containsKey('language'), isFalse, reason: 'not en/gu/hi');
      expect(data.containsKey('amount'), isFalse, reason: 'below minimum');
    });
  });

  test('platformName maps target platforms to stable labels', () {
    expect(platformName(TargetPlatform.android), 'android');
    expect(platformName(TargetPlatform.iOS), 'ios');
    expect(platformName(TargetPlatform.android, isWeb: true), 'web');
  });

  test('method codes match the data contract', () {
    expect(DonationMethod.values.map((DonationMethod m) => m.code), <String>[
      'upi',
      'bank',
      'cash',
      'cheque',
      'other',
    ]);
  });
}
