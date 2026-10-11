import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart' show QrPainter;

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/utils/ui_feedback.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../application/donation_qr_saver.dart';
import '../../domain/donation_config.dart';
import '../donation_haptics.dart';
import 'donation_card.dart';

/// Step 1 — "Scan & Pay": the temple QR, UPI ID and the two actions.
class QrPayCard extends ConsumerStatefulWidget {
  const QrPayCard({super.key, required this.config});

  final DonationConfig config;

  @override
  ConsumerState<QrPayCard> createState() => _QrPayCardState();
}

class _QrPayCardState extends ConsumerState<QrPayCard> {
  bool _saving = false;

  /// UPI intents only work reliably on Android; iOS users scan the QR.
  static bool get _canOpenUpiApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The `upi://pay` link, with the temple's name as payee when staff left
  /// `payeeName` empty. Used for the button, the generated QR and the saved
  /// QR so all three always match.
  String? _upiUri(String templeNameEn) {
    final String fallback = templeNameEn.isNotEmpty
        ? templeNameEn
        : lookupAppLocalizations(const Locale('en')).templeName;
    return widget.config.upiUriWithPayee(fallback);
  }

  Future<void> _payWithUpiApp(String uri) async {
    DonationHaptics.tap();
    final bool opened = await Launcher.url(uri);
    if (!opened && mounted) context.showSnack(context.l10n.donateNoUpiApp);
  }

  Future<void> _saveQr(String? upiUri) async {
    if (_saving) return;
    setState(() => _saving = true);
    DonationHaptics.tap();
    final QrSaveOutcome outcome = await ref
        .read(donationQrSaverProvider)
        .save(imageUrl: widget.config.qrImageUrl, upiUri: upiUri);
    if (!mounted) return;
    setState(() => _saving = false);
    final AppLocalizations l10n = context.l10n;
    context.showSnack(switch (outcome) {
      QrSaveOutcome.saved => l10n.donateQrSaved,
      QrSaveOutcome.denied => l10n.donateQrPermissionDenied,
      QrSaveOutcome.failed => l10n.errorGeneric,
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DonationConfig config = widget.config;
    final String? payee = config.payeeName;
    final String? upiUri = _upiUri(
      ref.watch(
        appConfigValueProvider.select(
          (AppConfig app) => app.templeName.resolve('en'),
        ),
      ),
    );

    return DonationCard(
      icon: Icons.qr_code_2_rounded,
      title: l10n.donateScanQr,
      subtitle: l10n.donateScanQrHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: _QrFrame(imageUrl: config.qrImageUrl, upiUri: upiUri),
            ),
          ),
          if (payee != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              payee,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
          if (config.upiId != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            CopyableRow(label: l10n.donateUpiId, value: config.upiId!),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_canOpenUpiApp && upiUri != null) ...<Widget>[
            FilledButton.icon(
              onPressed: () => _payWithUpiApp(upiUri),
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: Text(l10n.donatePayWithUpi),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _saveQr(upiUri),
            icon: AnimatedSwitcher(
              duration: AppDurations.fast,
              child: _saving
                  ? const SizedBox.square(
                      key: ValueKey<bool>(true),
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      key: ValueKey<bool>(false),
                    ),
            ),
            label: Text(l10n.donateSaveQr),
          ),
        ],
      ),
    );
  }
}

/// White, rounded frame for the QR. It stays white in dark mode on purpose:
/// scanners need dark modules on a light background.
class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.imageUrl, required this.upiUri});

  final String? imageUrl;
  final String? upiUri;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget qr = imageUrl != null
        ? AppNetworkImage(
            url: imageUrl,
            fit: BoxFit.contain,
            placeholderIcon: Icons.qr_code_2_rounded,
            // Decoded at display size (already pixel-exact on screen): staff
            // may upload a large printed standee, which at full resolution
            // would cost tens of MB of memory. "Save QR" saves the original.
            // Not downloaded yet and offline (or a broken link): the same
            // payment still works with a QR generated from the UPI ID.
            fallback: upiUri == null ? null : _GeneratedQr(data: upiUri!),
          )
        : _GeneratedQr(data: upiUri!);
    return Semantics(
      image: true,
      label: context.l10n.donateQrLabel,
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ClipRRect(borderRadius: AppRadius.smAll, child: qr),
          ),
        ),
      ),
    );
  }
}

/// QR generated on the device from the `upi://pay` link.
class _GeneratedQr extends StatefulWidget {
  const _GeneratedQr({required this.data});

  final String data;

  @override
  State<_GeneratedQr> createState() => _GeneratedQrState();
}

class _GeneratedQrState extends State<_GeneratedQr> {
  QrPainter? _painter;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(_GeneratedQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _build();
  }

  void _build() => _painter = buildQrPainter(widget.data);

  @override
  Widget build(BuildContext context) {
    final QrPainter? painter = _painter;
    if (painter == null) {
      return const Center(
        child: Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.black26),
      );
    }
    // Extra white margin (the QR "quiet zone") so every scanner locks on.
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: RepaintBoundary(
          child: CustomPaint(painter: painter, size: Size.infinite),
        ),
      ),
    );
  }
}
