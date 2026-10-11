import '../../../core/l10n/l10n.dart';
import '../domain/donation_config.dart';
import '../domain/donation_request.dart';

/// Localized labels for the donation domain types.
extension DonationLabelsX on AppLocalizations {
  String bankFieldLabel(BankField field) => switch (field) {
    BankField.accountName => donateAccountName,
    BankField.accountNumber => donateAccountNumber,
    BankField.ifsc => donateIfsc,
    BankField.bankName => donateBankName,
    BankField.branch => donateBranch,
    BankField.accountType => donateAccountType,
  };

  String donationMethodLabel(DonationMethod method) => switch (method) {
    DonationMethod.upi => donateMethodUpi,
    DonationMethod.bank => donateMethodBank,
    DonationMethod.cash => donateMethodCash,
    DonationMethod.cheque => donateMethodCheque,
    DonationMethod.other => donateMethodOther,
  };

  String? donationFieldError(DonationFieldError? error) => switch (error) {
    null => null,
    DonationFieldError.required => donateRequired,
    DonationFieldError.invalidName => donateInvalidName,
    DonationFieldError.invalidPhone => donateInvalidPhone,
    DonationFieldError.invalidEmail => donateInvalidEmail,
    DonationFieldError.invalidAmount => donateInvalidAmount,
  };
}
