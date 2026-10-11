import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/models/localized_text.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/utils/ui_feedback.dart';
import '../../domain/donation_config.dart';
import 'donation_card.dart';
import 'donation_form_sheet.dart';

/// Step 3 — "Contact Now": share the donation details with the temple
/// office, or call / WhatsApp / e-mail them directly.
class ContactSection extends StatelessWidget {
  const ContactSection({
    super.key,
    required this.contact,
    required this.purposes,
  });

  final DonationContact contact;
  final List<LocalizedText> purposes;

  Future<void> _run(BuildContext context, Future<bool> Function() action) async {
    await HapticFeedback.selectionClick();
    if (!await action() && context.mounted) context.showOpenLinkError();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? phone = contact.phone;
    final String? whatsapp = contact.whatsapp;
    final String? email = contact.email;

    return DonationCard(
      icon: Icons.support_agent_rounded,
      title: l10n.donateFormTitle,
      subtitle: l10n.donateContactSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: () async {
              await HapticFeedback.selectionClick();
              if (!context.mounted) return;
              await showDonationFormSheet(context, purposes: purposes);
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(l10n.donateContactNow),
          ),
          if (phone != null || whatsapp != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                if (phone != null)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          _run(context, () => Launcher.phone(phone)),
                      icon: const Icon(Icons.call_rounded),
                      label: Text(l10n.donateCall),
                    ),
                  ),
                if (phone != null && whatsapp != null)
                  const SizedBox(width: AppSpacing.md),
                if (whatsapp != null)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _run(
                        context,
                        () => Launcher.whatsApp(
                          whatsapp,
                          message: l10n.donateWhatsAppMessage,
                        ),
                      ),
                      icon: const Icon(Icons.chat_rounded),
                      label: Text(l10n.donateWhatsApp),
                    ),
                  ),
              ],
            ),
          ],
          if (email != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => _run(
                context,
                () => Launcher.email(email, subject: l10n.donateFormTitle),
              ),
              icon: const Icon(Icons.email_rounded),
              label: Text(l10n.donateEmailButton),
            ),
          ],
        ],
      ),
    );
  }
}
