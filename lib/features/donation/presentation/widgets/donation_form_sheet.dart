import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/models/localized_text.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/preferences.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/utils/ui_feedback.dart';
import '../../data/donation_repository.dart';
import '../../domain/donation_request.dart';
import '../donation_haptics.dart';
import '../donation_labels.dart';

/// Opens the "Share donation details" form above the bottom navigation bar.
Future<void> showDonationFormSheet(
  BuildContext context, {
  required List<LocalizedText> purposes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (BuildContext context) => DonationFormSheet(purposes: purposes),
  );
}

/// Device-only memory of the donor's contact details, so a returning devotee
/// does not have to type them again. Never leaves the phone except inside a
/// submitted request.
abstract final class _DonorPrefs {
  static const String name = 'donation.donorName';
  static const String phone = 'donation.donorPhone';
  static const String email = 'donation.donorEmail';
}

class DonationFormSheet extends ConsumerStatefulWidget {
  const DonationFormSheet({super.key, required this.purposes});

  /// Options from `config/donation.purposes`; "General seva" when empty.
  final List<LocalizedText> purposes;

  @override
  ConsumerState<DonationFormSheet> createState() => _DonationFormSheetState();
}

class _DonationFormSheetState extends ConsumerState<DonationFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _transactionRef = TextEditingController();
  final TextEditingController _message = TextEditingController();

  int _purposeIndex = 0;
  DonationMethod? _method;
  bool _submitting = false;
  bool _failed = false;
  bool _autovalidate = false;
  DonationSubmitResult? _result;

  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final SharedPreferences? prefs = _prefs;
    if (prefs != null) {
      _name.text = prefs.getString(_DonorPrefs.name) ?? '';
      _phone.text = prefs.getString(_DonorPrefs.phone) ?? '';
      _email.text = prefs.getString(_DonorPrefs.email) ?? '';
    }
  }

  /// Forgets the donor details remembered on this phone and empties the
  /// fields they filled.
  Future<void> _clearSavedDetails() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(_DonorPrefs.name);
      await prefs.remove(_DonorPrefs.phone);
      await prefs.remove(_DonorPrefs.email);
    }
    if (!mounted) return;
    setState(() {
      _name.clear();
      _phone.clear();
      _email.clear();
    });
    context.showSnack(context.l10n.donateSavedCleared);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _amount.dispose();
    _transactionRef.dispose();
    _message.dispose();
    super.dispose();
  }

  /// Purpose stored for staff: the English text when available, so requests
  /// are easy to group regardless of the devotee's app language.
  String _purposeForStaff() {
    if (widget.purposes.isEmpty) {
      return lookupAppLocalizations(const Locale('en')).donatePurposeGeneral;
    }
    final int index = _purposeIndex.clamp(0, widget.purposes.length - 1);
    return widget.purposes[index].resolve('en');
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final String language = Localizations.localeOf(context).languageCode;
    setState(() {
      _autovalidate = true;
      _failed = false;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      DonationHaptics.error();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    DonationHaptics.tap();

    final DonationRequest request = DonationRequest(
      name: _name.text.trim(),
      phone: DonationValidators.normalizePhone(_phone.text)!,
      email: _email.text.trim(),
      amount: DonationValidators.parseAmount(_amount.text),
      purpose: _purposeForStaff(),
      method: _method!,
      transactionRef: _method == DonationMethod.cash
          ? null
          : _transactionRef.text.trim(),
      message: _message.text.trim(),
      language: language,
      platform: platformName(defaultTargetPlatform, isWeb: kIsWeb),
    );
    final String phoneAsTyped = _phone.text.trim();
    final SharedPreferences? prefs = _prefs;
    // Offline, the write is stored locally at once; no need to wait long for
    // a server acknowledgement that cannot arrive.
    final bool online = ref.read(isOnlineProvider).value ?? true;
    // Dragging the sheet's handle closes it even while sending (it bypasses
    // PopScope). Keep what is needed to still confirm on the screen below.
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final AppLocalizations l10n = context.l10n;

    try {
      final DonationSubmitResult result = await ref
          .read(donationRepositoryProvider)
          .submit(
            request,
            timeout: online ? null : const Duration(milliseconds: 1500),
          );
      await _rememberDonor(prefs, request, phoneAsTyped);
      if (!mounted) {
        _notifyClosedSheet(
          messenger,
          result == DonationSubmitResult.queued
              ? l10n.donateSuccessQueued
              : l10n.donateSuccessBody,
        );
        return;
      }
      setState(() {
        _submitting = false;
        _result = result;
      });
      DonationHaptics.success();
    } catch (error, stack) {
      AppLogger.error('Donation request failed', error, stack);
      if (!mounted) {
        _notifyClosedSheet(messenger, l10n.errorGeneric);
        return;
      }
      setState(() {
        _submitting = false;
        _failed = true;
      });
      DonationHaptics.error();
    }
  }

  /// Shows the outcome on the donation screen when the sheet was closed
  /// before the request finished.
  static void _notifyClosedSheet(
    ScaffoldMessengerState? messenger,
    String message,
  ) {
    if (messenger == null || !messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Saves the donor's contact details on this phone for next time.
  /// Values are passed in because the sheet may be closed by now.
  static Future<void> _rememberDonor(
    SharedPreferences? prefs,
    DonationRequest request,
    String phoneAsTyped,
  ) async {
    if (prefs == null) return;
    try {
      await prefs.setString(_DonorPrefs.name, request.name);
      await prefs.setString(_DonorPrefs.phone, phoneAsTyped);
      final String email = request.email ?? '';
      if (email.isEmpty) {
        await prefs.remove(_DonorPrefs.email);
      } else {
        await prefs.setString(_DonorPrefs.email, email);
      }
    } catch (error, stack) {
      AppLogger.error('Could not remember donor details', error, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DonationSubmitResult? result = _result;
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        // Keeps the focused field above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AnimatedSwitcher(
          duration: AppDurations.medium,
          child: result == null
              ? _buildForm(context)
              : _SuccessView(
                  key: const ValueKey<String>('success'),
                  queued: result == DonationSubmitResult.queued,
                ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<String> purposeLabels = widget.purposes.isEmpty
        ? <String>[l10n.donatePurposeGeneral]
        : widget.purposes
              .map((LocalizedText p) => p.of(context))
              .toList(growable: false);
    const SizedBox gap = SizedBox(height: AppSpacing.lg);

    return SingleChildScrollView(
      key: const ValueKey<String>('form'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.donateFormTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.donateContactSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _name,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: '${l10n.donateName} *',
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.name],
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(DonationLimits.nameMax),
                ],
                validator: (String? v) =>
                    l10n.donationFieldError(DonationValidators.name(v)),
              ),
              gap,
              TextFormField(
                controller: _phone,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: '${l10n.donatePhone} *',
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.telephoneNumber],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (String? v) =>
                    l10n.donationFieldError(DonationValidators.phone(v)),
              ),
              gap,
              TextFormField(
                controller: _email,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: l10n.donateEmail,
                  prefixIcon: const Icon(Icons.email_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const <String>[AutofillHints.email],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(DonationLimits.emailMax),
                ],
                validator: (String? v) =>
                    l10n.donationFieldError(DonationValidators.email(v)),
              ),
              gap,
              TextFormField(
                controller: _amount,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: l10n.donateAmount,
                  prefixIcon: const Icon(Icons.currency_rupee_rounded),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: (String? v) =>
                    l10n.donationFieldError(DonationValidators.amount(v)),
              ),
              gap,
              DropdownButtonFormField<int>(
                initialValue: _purposeIndex.clamp(0, purposeLabels.length - 1),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.donatePurpose,
                  prefixIcon: const Icon(Icons.volunteer_activism_rounded),
                ),
                items: <DropdownMenuItem<int>>[
                  for (int i = 0; i < purposeLabels.length; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(
                        purposeLabels[i],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (int? i) => setState(() => _purposeIndex = i ?? 0),
              ),
              gap,
              _MethodField(
                value: _method,
                enabled: !_submitting,
                onChanged: (DonationMethod m) => setState(() => _method = m),
              ),
              AnimatedSize(
                duration: AppDurations.medium,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _method == DonationMethod.cash
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: TextFormField(
                          controller: _transactionRef,
                          enabled: !_submitting,
                          decoration: InputDecoration(
                            labelText: l10n.donateTxnRef,
                            prefixIcon: const Icon(Icons.receipt_long_rounded),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          inputFormatters: <TextInputFormatter>[
                            LengthLimitingTextInputFormatter(
                              DonationLimits.transactionRefMax,
                            ),
                          ],
                        ),
                      ),
              ),
              gap,
              TextFormField(
                controller: _message,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: l10n.donateMessage,
                  alignLabelWithHint: true,
                ),
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 5,
                maxLength: DonationLimits.messageMax,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
              ),
              AnimatedSize(
                duration: AppDurations.medium,
                alignment: Alignment.topCenter,
                child: _failed
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _ErrorBanner(message: l10n.errorGeneric),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${l10n.donatePrivacyNotice} ${l10n.donateRememberHint}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: <Widget>[
                  TextButton(
                    onPressed: () async {
                      final String url =
                          ref.read(appConfigValueProvider).privacyPolicyUrl ??
                          kDefaultPrivacyPolicyUrl;
                      if (!await Launcher.url(url) && context.mounted) {
                        context.showOpenLinkError();
                      }
                    },
                    child: Text(l10n.settingsPrivacyPolicy),
                  ),
                  TextButton(
                    onPressed: _submitting ? null : _clearSavedDetails,
                    child: Text(l10n.donateClearSaved),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
                onPressed: _submitting ? null : _submit,
                child: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: _submitting
                      ? Row(
                          key: const ValueKey<bool>(true),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(l10n.donateSubmitting),
                          ],
                        )
                      : Row(
                          key: const ValueKey<bool>(false),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.send_rounded, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(child: Text(l10n.donateSubmit)),
                          ],
                        ),
                ),
              ),
              // Room below the button so it never sits on the sheet's edge.
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Required payment-method choice as large chips (easier than a dropdown).
class _MethodField extends StatelessWidget {
  const _MethodField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final DonationMethod? value;
  final bool enabled;
  final ValueChanged<DonationMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return FormField<DonationMethod>(
      initialValue: value,
      validator: (DonationMethod? selected) =>
          l10n.donationFieldError(DonationValidators.method(selected)),
      builder: (FormFieldState<DonationMethod> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${l10n.donateMethod} *', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final DonationMethod method in DonationMethod.values)
                  ChoiceChip(
                    label: Text(l10n.donationMethodLabel(method)),
                    selected: value == method,
                    onSelected: enabled
                        ? (bool selected) {
                            if (!selected) return;
                            DonationHaptics.tap();
                            onChanged(method);
                            field.didChange(method);
                          }
                        : null,
                  ),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  left: AppSpacing.md,
                ),
                child: Text(
                  field.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: AppRadius.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated "Thank you" shown after submitting.
class _SuccessView extends StatelessWidget {
  const _SuccessView({super.key, required this.queued});

  /// The request is stored on the phone and will sync when online.
  final bool queued;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (BuildContext context, double t, Widget? child) =>
                  Transform.scale(scale: t, child: child),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              l10n.donateSuccessTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!queued)
            Text(
              l10n.donateSuccessBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            )
          else ...<Widget>[
            // Not confirmed by the server yet (offline or a slow network):
            // say it is saved and will be sent, never "received".
            const SizedBox(height: AppSpacing.xs),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: AppRadius.mdAll,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.cloud_upload_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.donateSuccessQueued,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }
}
