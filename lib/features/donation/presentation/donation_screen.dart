import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/models/localized_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/donation_repository.dart';
import '../domain/donation_config.dart';
import 'widgets/bank_details_card.dart';
import 'widgets/contact_section.dart';
import 'widgets/donation_card.dart';
import 'widgets/donation_hero.dart';
import 'widgets/qr_pay_card.dart';

/// Donation — kept deliberately simple: a welcome card, then
/// 1) Scan & Pay (QR / UPI app), 2) Bank Transfer, 3) Contact Now.
///
/// Everything comes from `config/donation`, live and offline-cached. When the
/// document is missing or disabled, payment details are replaced by a calm
/// "available soon" message while the contact options stay available.
class DonationScreen extends ConsumerWidget {
  const DonationScreen({super.key});

  /// Content width on tablets / landscape, so lines stay readable.
  static const double _maxContentWidth = 640;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DonationConfigSnapshot> snapshot = ref.watch(
      donationConfigProvider,
    );
    final double width = MediaQuery.sizeOf(context).width;
    final double side = math.max(
      AppSpacing.page,
      (width - _maxContentWidth) / 2,
    );
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      side,
      AppSpacing.sm,
      side,
      AppSpacing.xxxl,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.donateTitle),
        actions: const <Widget>[LanguageButton()],
      ),
      body: AnimatedSwitcher(
        duration: AppDurations.medium,
        child: snapshot.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => _DonationSkeleton(padding: padding),
          error: (Object error, StackTrace _) => _DonationBody(
            key: const ValueKey<String>('error'),
            snapshot: null,
            failed: true,
            padding: padding,
          ),
          data: (DonationConfigSnapshot data) => _DonationBody(
            key: const ValueKey<String>('data'),
            snapshot: data,
            failed: false,
            padding: padding,
          ),
        ),
      ),
    );
  }
}

class _DonationBody extends ConsumerWidget {
  const _DonationBody({
    super.key,
    required this.snapshot,
    required this.failed,
    required this.padding,
  });

  final DonationConfigSnapshot? snapshot;

  /// The config could not be loaded (error from the stream).
  final bool failed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DonationConfig? config = snapshot?.config;
    final AppConfig app = ref.watch(appConfigValueProvider);
    final DonationContact contact = DonationContact.resolve(
      config,
      fallbackPhone: app.phone,
      fallbackWhatsapp: app.whatsapp,
      fallbackEmail: app.email,
    );
    final bool available = snapshot?.isAvailable ?? false;
    final String note = available ? config!.note.of(context) : '';
    const SizedBox gap = SizedBox(height: AppSpacing.lg);

    return ListView(
      padding: padding,
      children: <Widget>[
        DonationHero(
          headline: _orFallback(config?.title, context, l10n.donateHeadline),
          message: _orFallback(config?.message, context, l10n.donateSubtitle),
        ),
        gap,
        if (available) ...<Widget>[
          if (config!.hasQr) ...<Widget>[QrPayCard(config: config), gap],
          if (config.bank.isUsable) ...<Widget>[
            BankDetailsCard(bank: config.bank),
            gap,
          ],
          if (note.isNotEmpty) ...<Widget>[_NoteCard(note: note), gap],
        ] else ...<Widget>[
          _UnavailableCard(
            failed: failed,
            waitingForNetwork: snapshot?.isWaitingForNetwork ?? false,
          ),
          gap,
        ],
        ContactSection(
          contact: contact,
          purposes: config?.purposes ?? const <LocalizedText>[],
        ),
      ],
    );
  }

  static String _orFallback(
    LocalizedText? text,
    BuildContext context,
    String fallback,
  ) {
    final String value = text?.of(context) ?? '';
    return value.isEmpty ? fallback : value;
  }
}

/// Shown instead of the payment cards when they cannot be displayed.
class _UnavailableCard extends ConsumerWidget {
  const _UnavailableCard({
    required this.failed,
    required this.waitingForNetwork,
  });

  final bool failed;
  final bool waitingForNetwork;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    if (failed || waitingForNetwork) {
      return DonationInfoCard(
        icon: Icons.cloud_off_rounded,
        message: failed ? l10n.errorGeneric : l10n.errorNetwork,
        action: FilledButton.tonalIcon(
          onPressed: () => ref.invalidate(donationConfigProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retry),
        ),
      );
    }
    return DonationInfoCard(
      icon: Icons.hourglass_top_rounded,
      message: l10n.donateUnavailable,
    );
  }
}

/// Optional note from staff, e.g. 80G tax-exemption details.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, color: scheme.onTertiaryContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SelectableText(
                note,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonationSkeleton extends StatelessWidget {
  const _DonationSkeleton({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        children: const <Widget>[
          SkeletonBox(height: 150, borderRadius: AppRadius.xlAll),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 420, borderRadius: AppRadius.lgAll),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 220, borderRadius: AppRadius.lgAll),
        ],
      ),
    );
  }
}
