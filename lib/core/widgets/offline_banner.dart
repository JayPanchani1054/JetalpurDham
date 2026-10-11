import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/connectivity_service.dart';
import '../theme/app_spacing.dart';

/// Slim banner shown while the device is offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool online = ref.watch(isOnlineProvider).value ?? true;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      child: online
          ? const SizedBox(width: double.infinity)
          : Material(
              color: scheme.inverseSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 18,
                      color: scheme.onInverseSurface,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        context.l10n.offlineBanner,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onInverseSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
