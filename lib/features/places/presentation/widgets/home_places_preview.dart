import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../data/places_repository.dart';
import '../../domain/prasadi_place.dart';
import 'place_cards.dart';
import 'place_ui.dart';
import 'places_skeletons.dart';

/// Home section: header + horizontal cards of prasadi places. Hidden when
/// there are no places (or they could not be loaded).
class HomePlacesPreview extends ConsumerWidget {
  const HomePlacesPreview({super.key});

  static const double _cardWidth = 220;
  static const double _imageHeight = _cardWidth * 9 / 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PrasadiPlace>> value = ref.watch(placesProvider);
    final List<PrasadiPlace>? places = value.value;
    // While Riverpod retries a failed load the value is "loading with an
    // error": keep the section hidden instead of showing a long skeleton.
    final bool loading = places == null && value.isLoading && !value.hasError;
    if (!loading && (places == null || places.isEmpty)) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = context.l10n;
    final double height =
        _imageHeight + 30 + 66 * placesTextScale(context).clamp(1.0, 1.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l10n.homePlacesTitle,
          actionLabel: l10n.seeAll,
          onAction: () => context.go(Routes.places),
        ),
        if (places == null)
          PlacesRowSkeleton(height: height, cardWidth: _cardWidth)
        else
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.pagePadding,
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) =>
                  _HomePlaceCard(place: places[index], width: _cardWidth),
            ),
          ),
      ],
    );
  }
}

class _HomePlaceCard extends StatelessWidget {
  const _HomePlaceCard({required this.place, required this.width});

  final PrasadiPlace place;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String description = place.shortDescription.of(context);
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            context.go(Routes.place(place.id));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: HomePlacesPreview._imageHeight,
                // Different navigator than the detail page: no Hero here.
                child: PlaceCoverImage(place: place, hero: false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm + 2,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            place.category.icon,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              place.name.of(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
