import 'package:flutter/services.dart';

/// Haptic feedback that never delays or breaks the action it accompanies
/// (platform errors are ignored, e.g. on devices without a vibrator).
abstract final class DonationHaptics {
  /// Light tick for primary taps.
  static void tap() => HapticFeedback.selectionClick().ignore();

  /// A request was submitted successfully.
  static void success() => HapticFeedback.mediumImpact().ignore();

  /// Validation or submission failed.
  static void error() => HapticFeedback.heavyImpact().ignore();
}
