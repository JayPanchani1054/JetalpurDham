import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/ui_feedback.dart';
import '../../domain/donation_config.dart';
import '../donation_labels.dart';
import 'donation_card.dart';

/// Step 2 — "Bank Transfer": each detail copyable on its own, plus
/// "Copy all details" for pasting into a banking app or a message.
class BankDetailsCard extends StatelessWidget {
  const BankDetailsCard({super.key, required this.bank});

  final BankDetails bank;

  /// Numbers are copied without the spaces staff may add for readability.
  static bool _isNumber(BankField field) =>
      field == BankField.accountNumber || field == BankField.ifsc;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<(BankField, String)> fields = bank.fields;
    return DonationCard(
      icon: Icons.account_balance_rounded,
      title: l10n.donateBankDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < fields.length; i++) ...<Widget>[
            if (i > 0) const Divider(),
            CopyableRow(
              label: l10n.bankFieldLabel(fields[i].$1),
              value: fields[i].$2,
              copyValue: _isNumber(fields[i].$1)
                  ? fields[i].$2.replaceAll(' ', '')
                  : null,
              emphasize: fields[i].$1 == BankField.accountNumber,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => context.copyToClipboard(
              formatBankDetails(
                fields.map(
                  ((BankField, String) f) => (
                    l10n.bankFieldLabel(f.$1),
                    _isNumber(f.$1) ? f.$2.replaceAll(' ', '') : f.$2,
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.copy_all_rounded),
            label: Text(l10n.donateCopyAll),
          ),
        ],
      ),
    );
  }
}
