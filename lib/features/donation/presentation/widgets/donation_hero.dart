import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Saffron gradient welcome card at the top of the donation screen.
class DonationHero extends StatelessWidget {
  const DonationHero({
    super.key,
    required this.headline,
    required this.message,
  });

  final String headline;
  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: ClipRRect(
        borderRadius: AppRadius.xlAll,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: <Widget>[
              // Soft decorative glyph; purely visual.
              Positioned(
                right: -18,
                bottom: -22,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    size: 140,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.jaySwaminarayan,
                      style: text.titleSmall?.copyWith(
                        color: AppColors.goldLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      headline,
                      style: text.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      style: text.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
