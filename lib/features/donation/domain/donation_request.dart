import 'package:flutter/foundation.dart';

/// How the devotee made the offering. [code] is the value stored in
/// `donation_requests.method` (see firestore.rules).
enum DonationMethod {
  upi('upi'),
  bank('bank'),
  cash('cash'),
  cheque('cheque'),
  other('other');

  const DonationMethod(this.code);

  final String code;
}

/// Field limits mirrored from `isValidDonationRequest` in firestore.rules.
/// The form enforces them so a request is never rejected by the server
/// (which, for an offline write, would fail silently after the user left).
abstract final class DonationLimits {
  static const int nameMin = 2;
  static const int nameMax = 80;
  static const int emailMax = 254;
  static const int purposeMax = 200;
  static const int transactionRefMax = 120;
  static const int messageMax = 500;
  static const int platformMax = 20;
  static const int appVersionMax = 40;
  static const int amountMin = 1;
  static const int amountMax = 10000000;
}

/// A devotee's "I have donated / please contact me" submission, written to
/// `donation_requests` (create-only; devotees cannot read it back).
@immutable
class DonationRequest {
  const DonationRequest({
    required this.name,
    required this.phone,
    required this.method,
    required this.language,
    required this.platform,
    this.email,
    this.amount,
    this.purpose,
    this.transactionRef,
    this.message,
  });

  final String name;

  /// Normalized phone, e.g. `+919876543210` (see [DonationValidators]).
  final String phone;
  final DonationMethod method;

  /// UI language code (`en` · `gu` · `hi`).
  final String language;

  /// `android` · `ios` · … (see [platformName]).
  final String platform;
  final String? email;
  final int? amount;
  final String? purpose;
  final String? transactionRef;
  final String? message;

  /// The exact document written to Firestore. Optional fields that are null
  /// or blank are omitted, and every text is trimmed and capped to the length
  /// the security rules allow.
  ///
  /// [createdAt] is `FieldValue.serverTimestamp()` in production; it is a
  /// parameter so this stays a pure, testable function.
  Map<String, Object?> toFirestore({
    required String appVersion,
    required Object createdAt,
  }) {
    final String? emailValue = _clean(email, DonationLimits.emailMax);
    final String? purposeValue = _clean(purpose, DonationLimits.purposeMax);
    final String? refValue = _clean(
      transactionRef,
      DonationLimits.transactionRefMax,
    );
    final String? messageValue = _clean(message, DonationLimits.messageMax);
    final int? amountValue =
        amount != null &&
            amount! >= DonationLimits.amountMin &&
            amount! <= DonationLimits.amountMax
        ? amount
        : null;
    final String? languageValue = const <String>{
      'en',
      'gu',
      'hi',
    }.contains(language) ? language : null;
    final String? platformValue = _clean(platform, DonationLimits.platformMax);
    final String? versionValue = _clean(
      appVersion,
      DonationLimits.appVersionMax,
    );
    return <String, Object?>{
      'name': _clean(name, DonationLimits.nameMax) ?? '',
      'phone': phone.trim(),
      'email': ?emailValue,
      'amount': ?amountValue,
      'purpose': ?purposeValue,
      'method': method.code,
      'transactionRef': ?refValue,
      'message': ?messageValue,
      'language': ?languageValue,
      'platform': ?platformValue,
      'appVersion': ?versionValue,
      'status': 'new',
      'createdAt': createdAt,
    };
  }

  static String? _clean(String? value, int max) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return text.length <= max ? text : text.substring(0, max).trim();
  }
}

/// Platform label stored with each request so staff can help with app issues.
String platformName(TargetPlatform platform, {bool isWeb = false}) {
  if (isWeb) return 'web';
  return switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

/// Validation and normalization for the "Share donation details" form. Each
/// validator returns a [DonationFieldError] (localized by the UI) or null.
abstract final class DonationValidators {
  static final RegExp _separators = RegExp(r'[\s\-().]');
  static final RegExp _digitsOnly = RegExp(r'^\d+$');
  static final RegExp _email = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
    caseSensitive: false,
  );

  static DonationFieldError? name(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return DonationFieldError.required;
    if (text.length < DonationLimits.nameMin ||
        text.length > DonationLimits.nameMax) {
      return DonationFieldError.invalidName;
    }
    return null;
  }

  static DonationFieldError? phone(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return DonationFieldError.required;
    return normalizePhone(text) == null ? DonationFieldError.invalidPhone : null;
  }

  static DonationFieldError? email(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > DonationLimits.emailMax || !_email.hasMatch(text)) {
      return DonationFieldError.invalidEmail;
    }
    return null;
  }

  static DonationFieldError? amount(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return parseAmount(text) == null ? DonationFieldError.invalidAmount : null;
  }

  static DonationFieldError? method(DonationMethod? value) =>
      value == null ? DonationFieldError.required : null;

  /// Normalizes a phone number to E.164, or returns null when invalid.
  ///
  /// Indian numbers: 10 digits starting with 6–9, optionally prefixed with
  /// `+91`, `91`, `0091` or `0` → `+91XXXXXXXXXX`.
  /// Devotees abroad may enter any international number starting with `+`
  /// (or `00`) followed by 8–15 digits → `+<digits>`.
  static String? normalizePhone(String input) {
    final String compact = input.trim().replaceAll(_separators, '');
    if (compact.isEmpty) return null;

    String digits;
    bool international = false;
    if (compact.startsWith('+')) {
      digits = compact.substring(1);
      international = true;
    } else if (compact.startsWith('00')) {
      digits = compact.substring(2);
      international = true;
    } else {
      digits = compact;
    }
    if (!_digitsOnly.hasMatch(digits)) return null;

    if (international) {
      if (digits.startsWith('91')) {
        return _indianMobile(digits.substring(2));
      }
      if (digits.length < 8 || digits.length > 15 || digits.startsWith('0')) {
        return null;
      }
      return '+$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return _indianMobile(digits.substring(2));
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return _indianMobile(digits.substring(1));
    }
    return _indianMobile(digits);
  }

  static String? _indianMobile(String digits) {
    if (digits.length != 10) return null;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return null;
    return '+91$digits';
  }

  /// Parses an amount in whole rupees. Accepts `1001`, `1,001`, `₹ 1,00,000`
  /// and `501.00`. Returns null when not a whole number in the allowed range.
  static int? parseAmount(String input) {
    String text = input.trim().replaceAll(RegExp(r'[\s,₹]'), '');
    if (text.toLowerCase().startsWith('rs')) {
      text = text.substring(2).replaceFirst(RegExp(r'^\.'), '');
    }
    final RegExpMatch? match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(
      text,
    );
    if (match == null) return null;
    final String? paise = match.group(2);
    if (paise != null && int.parse(paise) != 0) return null;
    final int? value = int.tryParse(match.group(1)!);
    if (value == null ||
        value < DonationLimits.amountMin ||
        value > DonationLimits.amountMax) {
      return null;
    }
    return value;
  }
}

/// Validation failures, localized by the form.
enum DonationFieldError {
  required,
  invalidName,
  invalidPhone,
  invalidEmail,
  invalidAmount,
}
