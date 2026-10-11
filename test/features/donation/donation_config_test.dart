import 'package:flutter_test/flutter_test.dart';
import 'package:jetalpur_dham/core/models/localized_text.dart';
import 'package:jetalpur_dham/features/donation/data/donation_repository.dart';
import 'package:jetalpur_dham/features/donation/domain/donation_config.dart';

void main() {
  group('DonationConfig.fromMap', () {
    test('parses a complete document', () {
      final DonationConfig config = DonationConfig.fromMap(<String, Object?>{
        'enabled': true,
        'title': <String, Object?>{'en': 'Seva', 'gu': 'સેવા'},
        'message': 'Support the temple',
        'note': <String, Object?>{'en': '80G exemption available'},
        'upiId': ' jetalpurdham@sbi ',
        'payeeName': 'Shree Swaminarayan Mandir',
        'qrImageUrl': 'config/donation-qr.png',
        'bank': <String, Object?>{
          'accountName': 'Shree Swaminarayan Mandir Jetalpur',
          'accountNumber': '1234 5678 9012',
          'ifsc': 'sbin0001234',
          'bankName': 'State Bank of India',
          'branch': 'Jetalpur',
          'accountType': 'Savings',
        },
        'contactPhone': '+91 98765 43210',
        'contactWhatsapp': '919876543210',
        'contactEmail': 'office@jetalpurdham.org',
        'purposes': <Object?>[
          'General seva',
          <String, Object?>{'en': 'Annakut', 'gu': 'અન્નકૂટ'},
          '',
          42,
        ],
      });

      expect(config.enabled, isTrue);
      expect(config.title.resolve('gu'), 'સેવા');
      expect(config.message.resolve('hi'), 'Support the temple');
      expect(config.note.resolve('en'), '80G exemption available');
      expect(config.upiId, 'jetalpurdham@sbi');
      expect(config.payeeName, 'Shree Swaminarayan Mandir');
      expect(config.qrImageUrl, 'config/donation-qr.png');
      expect(config.bank.ifsc, 'SBIN0001234');
      expect(config.bank.isUsable, isTrue);
      expect(config.contactPhone, '+91 98765 43210');
      expect(config.contactWhatsapp, '919876543210');
      expect(config.contactEmail, 'office@jetalpurdham.org');
      expect(config.purposes, hasLength(2));
      expect(config.purposes[1].resolve('gu'), 'અન્નકૂટ');
      expect(config.hasQr, isTrue);
      expect(config.hasPaymentDetails, isTrue);
      expect(
        config.upiUri,
        'upi://pay?pa=jetalpurdham@sbi'
        '&pn=Shree%20Swaminarayan%20Mandir&cu=INR',
      );
    });

    test('an empty document is enabled but has nothing to pay with', () {
      final DonationConfig config = DonationConfig.fromMap(
        const <String, Object?>{},
      );
      expect(config.enabled, isTrue);
      expect(config.hasQr, isFalse);
      expect(config.bank.isUsable, isFalse);
      expect(config.hasPaymentDetails, isFalse);
      expect(config.upiUri, isNull);
      expect(config.purposes, isEmpty);
      expect(config.title.isEmpty, isTrue);
    });

    test('tolerates wrong types from hand-edited documents', () {
      final DonationConfig config = DonationConfig.fromMap(<String, Object?>{
        'enabled': 'false',
        'upiId': 12345,
        'payeeName': <String>['x'],
        'qrImageUrl': '   ',
        'bank': 'not a map',
        'contactPhone': 9876543210,
        'purposes': 'Only one',
      });
      expect(config.enabled, isFalse);
      expect(config.upiId, isNull, reason: 'not a valid UPI ID');
      expect(config.payeeName, isNull);
      expect(config.qrImageUrl, isNull);
      expect(config.bank, BankDetails.empty);
      expect(config.contactPhone, '9876543210');
      expect(config.purposes.single.resolve('en'), 'Only one');
    });

    test('numeric account numbers are accepted', () {
      final BankDetails bank = BankDetails.fromValue(<String, Object?>{
        'accountNumber': 12345678901,
      });
      expect(bank.accountNumber, '12345678901');
      expect(bank.isUsable, isTrue);
    });

    test('a QR image alone is enough to show the payment card', () {
      final DonationConfig config = DonationConfig.fromMap(<String, Object?>{
        'qrImageUrl': 'https://example.com/qr.png',
      });
      expect(config.hasQr, isTrue);
      expect(config.upiUri, isNull);
      expect(config.hasPaymentDetails, isTrue);
    });
  });

  group('BankDetails.fields', () {
    test('lists only filled fields in display order', () {
      const BankDetails bank = BankDetails(
        accountType: 'Savings',
        accountNumber: '111',
        accountName: 'Mandir',
      );
      expect(bank.fields, <(BankField, String)>[
        (BankField.accountName, 'Mandir'),
        (BankField.accountNumber, '111'),
        (BankField.accountType, 'Savings'),
      ]);
    });
  });

  group('UPI', () {
    test('validates UPI IDs', () {
      expect(isValidUpiId('jetalpurdham@sbi'), isTrue);
      expect(isValidUpiId('9876543210@ybl'), isTrue);
      expect(isValidUpiId('shree.mandir-1_x@okhdfcbank'), isTrue);
      expect(isValidUpiId('no-at-sign'), isFalse);
      expect(isValidUpiId('two@@signs'), isFalse);
      expect(isValidUpiId('space in@sbi'), isFalse);
      expect(isValidUpiId('a@b'), isFalse);
    });

    test('builds the deep link, omitting an empty payee name', () {
      expect(buildUpiUri('temple@sbi'), 'upi://pay?pa=temple@sbi&cu=INR');
      expect(buildUpiUri('temple@sbi', '  '), 'upi://pay?pa=temple@sbi&cu=INR');
      expect(
        buildUpiUri('temple@sbi', 'Shree & Mandir'),
        'upi://pay?pa=temple@sbi&pn=Shree%20%26%20Mandir&cu=INR',
      );
    });
  });

  test('formatBankDetails writes one "Label: value" per line', () {
    expect(
      formatBankDetails(<(String, String)>[
        ('Account name', 'Mandir'),
        ('IFSC code', 'SBIN0001234'),
      ]),
      'Account name: Mandir\nIFSC code: SBIN0001234',
    );
    expect(formatBankDetails(const <(String, String)>[]), '');
  });

  group('DonationContact.resolve', () {
    test('prefers donation contacts and falls back to temple contacts', () {
      final DonationConfig config = DonationConfig.fromMap(<String, Object?>{
        'contactPhone': '111',
      });
      final DonationContact contact = DonationContact.resolve(
        config,
        fallbackPhone: '999',
        fallbackWhatsapp: '919999999999',
        fallbackEmail: '  ',
      );
      expect(
        contact,
        const DonationContact(phone: '111', whatsapp: '919999999999'),
      );
      expect(contact.hasAny, isTrue);
    });

    test('works without a donation document', () {
      expect(
        DonationContact.resolve(null, fallbackEmail: 'a@b.org'),
        const DonationContact(email: 'a@b.org'),
      );
      expect(DonationContact.resolve(null).hasAny, isFalse);
    });
  });

  group('DonationConfigSnapshot', () {
    test('is available only when enabled with payment details', () {
      final DonationConfig ready = DonationConfig.fromMap(<String, Object?>{
        'upiId': 'temple@sbi',
      });
      final DonationConfig disabled = DonationConfig.fromMap(<String, Object?>{
        'enabled': false,
        'upiId': 'temple@sbi',
      });
      expect(
        DonationConfigSnapshot(config: ready, fromCache: true).isAvailable,
        isTrue,
      );
      expect(
        DonationConfigSnapshot(config: disabled, fromCache: false).isAvailable,
        isFalse,
      );
      expect(
        const DonationConfigSnapshot(
          config: DonationConfig(),
          fromCache: false,
        ).isAvailable,
        isFalse,
      );
    });

    test('a missing document from the cache means "waiting for network"', () {
      const DonationConfigSnapshot cached = DonationConfigSnapshot(
        config: null,
        fromCache: true,
      );
      const DonationConfigSnapshot server = DonationConfigSnapshot(
        config: null,
        fromCache: false,
      );
      expect(cached.isWaitingForNetwork, isTrue);
      expect(cached.isAvailable, isFalse);
      expect(server.isWaitingForNetwork, isFalse);
      expect(server.isAvailable, isFalse);
    });
  });

  test('LocalizedText purposes resolve per language', () {
    final DonationConfig config = DonationConfig.fromMap(<String, Object?>{
      'purposes': <Object?>[
        <String, Object?>{'gu': 'ગૌ સેવા', 'hi': 'गौ सेवा'},
      ],
    });
    final LocalizedText purpose = config.purposes.single;
    expect(purpose.resolve('hi'), 'गौ सेवा');
    // English falls back to Gujarati when not provided.
    expect(purpose.resolve('en'), 'ગૌ સેવા');
  });
}
