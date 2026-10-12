import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/models/localized_text.dart';

/// Temple bank account shown in the "Bank Transfer" card. Every field is
/// optional because staff fill the `config/donation.bank` map by hand.
@immutable
class BankDetails {
  const BankDetails({
    this.accountName,
    this.accountNumber,
    this.ifsc,
    this.bankName,
    this.branch,
    this.accountType,
  });

  factory BankDetails.fromValue(Object? value) {
    final Map<String, Object?> map = Fs.map(value);
    return BankDetails(
      accountName: Fs.stringOrNull(map['accountName']),
      // Numbers pasted as a Firestore number would lose leading zeros, but are
      // still accepted; spaces are kept as typed for readability.
      accountNumber: Fs.stringOrNull(map['accountNumber']),
      ifsc: Fs.stringOrNull(map['ifsc'])?.toUpperCase(),
      bankName: Fs.stringOrNull(map['bankName']),
      branch: Fs.stringOrNull(map['branch']),
      accountType: Fs.stringOrNull(map['accountType']),
    );
  }

  static const BankDetails empty = BankDetails();

  final String? accountName;
  final String? accountNumber;
  final String? ifsc;
  final String? bankName;
  final String? branch;
  final String? accountType;

  /// A transfer is only possible with at least an account number.
  bool get isUsable => accountNumber != null;

  /// The filled-in fields in display order, paired with their [BankField].
  List<(BankField, String)> get fields => <(BankField, String)>[
    if (accountName != null) (BankField.accountName, accountName!),
    if (accountNumber != null) (BankField.accountNumber, accountNumber!),
    if (ifsc != null) (BankField.ifsc, ifsc!),
    if (bankName != null) (BankField.bankName, bankName!),
    if (branch != null) (BankField.branch, branch!),
    if (accountType != null) (BankField.accountType, accountType!),
  ];

  @override
  bool operator ==(Object other) =>
      other is BankDetails &&
      other.accountName == accountName &&
      other.accountNumber == accountNumber &&
      other.ifsc == ifsc &&
      other.bankName == bankName &&
      other.branch == branch &&
      other.accountType == accountType;

  @override
  int get hashCode => Object.hash(
    accountName,
    accountNumber,
    ifsc,
    bankName,
    branch,
    accountType,
  );
}

/// The rows of the bank card. Labels are localized in the presentation layer.
enum BankField {
  accountName,
  accountNumber,
  ifsc,
  bankName,
  branch,
  accountType,
}

/// The `config/donation` document (see docs/DATA_MODEL.md).
@immutable
class DonationConfig {
  const DonationConfig({
    this.enabled = true,
    this.title = const LocalizedText.empty(),
    this.message = const LocalizedText.empty(),
    this.note = const LocalizedText.empty(),
    this.upiId,
    this.payeeName,
    this.qrImageUrl,
    this.bank = BankDetails.empty,
    this.contactPhone,
    this.contactWhatsapp,
    this.contactEmail,
    this.purposes = const <LocalizedText>[],
    this.webUrl,
  });

  /// Parses the document. Never throws; a missing `enabled` counts as `true`.
  factory DonationConfig.fromMap(Map<String, Object?> map) {
    final String? upiId = Fs.stringOrNull(map['upiId']);
    return DonationConfig(
      enabled: Fs.boolean(map['enabled'], fallback: true),
      title: LocalizedText.fromValue(map['title']),
      message: LocalizedText.fromValue(map['message']),
      note: LocalizedText.fromValue(map['note']),
      upiId: upiId != null && isValidUpiId(upiId) ? upiId : null,
      payeeName: Fs.stringOrNull(map['payeeName']),
      qrImageUrl: Fs.stringOrNull(map['qrImageUrl']),
      bank: BankDetails.fromValue(map['bank']),
      contactPhone: Fs.stringOrNull(map['contactPhone']),
      contactWhatsapp: Fs.stringOrNull(map['contactWhatsapp']),
      contactEmail: Fs.stringOrNull(map['contactEmail']),
      purposes: _parsePurposes(map['purposes']),
      webUrl: _webUrl(map['webUrl']),
    );
  }

  final bool enabled;
  final LocalizedText title;
  final LocalizedText message;
  final LocalizedText note;
  final String? upiId;
  final String? payeeName;
  final String? qrImageUrl;
  final BankDetails bank;
  final String? contactPhone;
  final String? contactWhatsapp;
  final String? contactEmail;
  final List<LocalizedText> purposes;

  /// The temple's own donation web page. On iPhone the app links here instead
  /// of showing payment details (App Store guideline 3.2.2(iv)).
  final String? webUrl;

  /// `upi://pay?...` link for "Pay with UPI app" and the generated QR.
  String? get upiUri => upiUriWithPayee(null);

  /// Like [upiUri], but uses [fallbackPayeeName] (e.g. the temple's name)
  /// when staff left `payeeName` empty: the UPI linking spec lists `pn` as
  /// mandatory and some UPI apps refuse a link without it.
  String? upiUriWithPayee(String? fallbackPayeeName) {
    final String? id = upiId;
    if (id == null) return null;
    final String fallback = fallbackPayeeName?.trim() ?? '';
    return buildUpiUri(id, payeeName ?? (fallback.isEmpty ? null : fallback));
  }

  /// True when a QR (official image or generated from the UPI ID) can be shown.
  bool get hasQr => qrImageUrl != null || upiId != null;

  /// True when there is anything to pay with.
  bool get hasPaymentDetails => hasQr || bank.isUsable;

  static List<LocalizedText> _parsePurposes(Object? value) {
    final List<Object?> raw = value is List
        ? List<Object?>.of(value)
        : <Object?>[value];
    return raw
        .map(LocalizedText.fromValue)
        .where((LocalizedText t) => t.isNotEmpty)
        .toList(growable: false);
  }
}

/// Phone, WhatsApp and e-mail offered next to "Contact Now".
///
/// Uses the donation-specific contacts from `config/donation` and falls back
/// to the temple's general contacts (`config/app`), so devotees can always
/// reach the office — even before the donation document is filled in.
@immutable
class DonationContact {
  const DonationContact({this.phone, this.whatsapp, this.email});

  factory DonationContact.resolve(
    DonationConfig? config, {
    String? fallbackPhone,
    String? fallbackWhatsapp,
    String? fallbackEmail,
  }) => DonationContact(
    phone: config?.contactPhone ?? _blankToNull(fallbackPhone),
    whatsapp: config?.contactWhatsapp ?? _blankToNull(fallbackWhatsapp),
    email: config?.contactEmail ?? _blankToNull(fallbackEmail),
  );

  final String? phone;
  final String? whatsapp;
  final String? email;

  bool get hasAny => phone != null || whatsapp != null || email != null;

  static String? _blankToNull(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) =>
      other is DonationContact &&
      other.phone == phone &&
      other.whatsapp == whatsapp &&
      other.email == email;

  @override
  int get hashCode => Object.hash(phone, whatsapp, email);
}

/// UPI virtual payment address, e.g. `jetalpurdham@sbi`.
final RegExp _upiIdPattern = RegExp(r'^[\w.\-]{2,256}@[A-Za-z0-9.\-]{2,64}$');

bool isValidUpiId(String value) => _upiIdPattern.hasMatch(value.trim());

/// Builds the standard UPI deep link:
/// `upi://pay?pa=<upiId>&pn=<payeeName>&cu=INR`.
///
/// The UPI ID is kept verbatim (UPI apps expect a literal `@`); the payee name
/// is percent-encoded and left out when empty.
String buildUpiUri(String upiId, [String? payeeName]) {
  final String pa = upiId.trim();
  final String pn = payeeName?.trim() ?? '';
  final StringBuffer uri = StringBuffer('upi://pay?pa=$pa');
  if (pn.isNotEmpty) uri.write('&pn=${Uri.encodeComponent(pn)}');
  uri.write('&cu=INR');
  return uri.toString();
}

/// Plain-text block for "Copy all details", one `Label: value` per line.
String formatBankDetails(Iterable<(String label, String value)> rows) =>
    rows.map(((String, String) row) => '${row.$1}: ${row.$2}').join('\n');

String? _webUrl(Object? value) {
  final String? url = Fs.stringOrNull(value);
  if (url == null) return null;
  final Uri? uri = Uri.tryParse(url);
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? url
      : null;
}
