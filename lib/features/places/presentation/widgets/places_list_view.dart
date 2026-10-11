import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/prasadi_place.dart';
import 'place_cards.dart';

/// Scrollable list of large place cards (centered on wide screens).
class PlacesListView extends StatelessWidget {
  const PlacesListView({super.key, required this.places});

  final List<PrasadiPlace> places;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double side = math.max(
          AppSpacing.page,
          (constraints.maxWidth - 720) / 2,
        );
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.sm,
            side,
            AppSpacing.xxl,
          ),
          itemCount: places.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.lg,
                ),
                child: Text(
                  context.l10n.placesSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            final PrasadiPlace place = places[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: PlaceListCard(
                key: ValueKey<String>(place.id),
                place: place,
                onTap: () {
                  HapticFeedback.selectionClick().ignore();
                  context.go(Routes.place(place.id));
                },
              ),
            );
          },
        );
      },
    );
  }
}
