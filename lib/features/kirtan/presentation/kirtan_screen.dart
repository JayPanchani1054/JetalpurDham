import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/menu_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../application/kirtan_player_controller.dart';
import '../data/kirtan_repository.dart';
import '../domain/kirtan.dart';
import '../domain/kirtan_queries.dart';
import 'widgets/kirtan_tile.dart';

/// Kirtan tab: search, category chips, Play all / Shuffle and the full list.
/// Tapping a row plays the list exactly as filtered, starting from that row.
class KirtanScreen extends ConsumerStatefulWidget {
  const KirtanScreen({super.key});

  @override
  ConsumerState<KirtanScreen> createState() => _KirtanScreenState();
}

class _KirtanScreenState extends ConsumerState<KirtanScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _categoryId;

  // Memoised filter result (the list can hold hundreds of kirtans).
  List<Kirtan>? _filterSource;
  String _filterQuery = '';
  String? _filterCategory;
  List<Kirtan> _filtered = const <Kirtan>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted && value.trim() != _query) {
        setState(() => _query = value.trim());
      }
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  void _selectCategory(String? id) {
    if (id == _categoryId) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _categoryId = id);
  }

  List<Kirtan> _filter(List<Kirtan> all, String? categoryId) {
    if (!identical(all, _filterSource) ||
        _query != _filterQuery ||
        categoryId != _filterCategory) {
      _filterSource = all;
      _filterQuery = _query;
      _filterCategory = categoryId;
      _filtered = filterKirtans(all, query: _query, categoryId: categoryId);
    }
    return _filtered;
  }

  void _play(List<Kirtan> list, int index) {
    final Kirtan tapped = list[index];
    unawaited(HapticFeedback.selectionClick());
    // Tapping the kirtan that is already loaded opens the player.
    if (ref.read(currentKirtanProvider)?.id == tapped.id) {
      unawaited(context.push<void>(Routes.player));
      return;
    }
    unawaited(
      ref
          .read(kirtanPlayerProvider.notifier)
          .playKirtans(list, startIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<Kirtan>> kirtans = ref.watch(kirtansProvider);
    final List<KirtanCategory> allCategories =
        ref.watch(kirtanCategoriesProvider).value ?? const <KirtanCategory>[];

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: Text(l10n.kirtanTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.kirtanDownloads,
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: () => context.go(Routes.kirtanDownloads),
          ),
          const LanguageButton(),
        ],
      ),
      body: AsyncValueView<List<Kirtan>>(
        value: kirtans,
        onRetry: () => ref.invalidate(kirtansProvider),
        loading: const _KirtanListSkeleton(),
        isEmpty: (List<Kirtan> list) => list.isEmpty,
        empty: EmptyState(
          icon: Icons.library_music_outlined,
          title: l10n.kirtanEmpty,
        ),
        data: (List<Kirtan> all) {
          final List<KirtanCategory> categories = categoriesInUse(
            allCategories,
            all,
          );
          // A category that disappeared from the console falls back to All.
          final String? categoryId =
              categories.any((KirtanCategory c) => c.id == _categoryId)
              ? _categoryId
              : null;
          final List<Kirtan> visible = _filter(all, categoryId);
          return Column(
            children: <Widget>[
              _SearchField(
                controller: _search,
                onChanged: _onQueryChanged,
                onClear: _clearSearch,
              ),
              if (categories.isNotEmpty)
                _CategoryChips(
                  categories: categories,
                  selectedId: categoryId,
                  onSelected: _selectCategory,
                ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: l10n.kirtanNoResults,
                        action: _query.isEmpty
                            ? null
                            : FilledButton.tonal(
                                onPressed: _clearSearch,
                                child: Text(l10n.clearSearch),
                              ),
                      )
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        itemCount: visible.length + 1,
                        itemBuilder: (BuildContext context, int i) {
                          if (i == 0) {
                            return KirtanPlayAllHeader(
                              label: l10n.kirtanCount(visible.length),
                              onPlayAll: () => ref
                                  .read(kirtanPlayerProvider.notifier)
                                  .playAll(visible),
                              onShuffle: () => ref
                                  .read(kirtanPlayerProvider.notifier)
                                  .playAll(visible, shuffle: true),
                            );
                          }
                          final Kirtan kirtan = visible[i - 1];
                          return KirtanTile(
                            key: ValueKey<String>(kirtan.id),
                            kirtan: kirtan,
                            onTap: () => _play(visible, i - 1),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: SearchBar(
        controller: controller,
        hintText: l10n.kirtanSearchHint,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        leading: const Icon(Icons.search_rounded),
        trailing: <Widget>[
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (BuildContext context, TextEditingValue value, _) =>
                value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.clearSearch,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClear,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<KirtanCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.textScalerOf(context).scale(15) + 40;
    return SizedBox(
      height: height.clamp(52.0, 72.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.xs,
        ),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final KirtanCategory? category = i == 0 ? null : categories[i - 1];
          final String? id = category?.id;
          return Center(
            child: ChoiceChip(
              label: Text(
                category == null ? context.l10n.all : category.name.of(context),
              ),
              selected: selectedId == id,
              onSelected: (_) => onSelected(id),
            ),
          );
        },
      ),
    );
  }
}

/// "12 kirtans" with large Play all and Shuffle buttons.
class KirtanPlayAllHeader extends StatelessWidget {
  const KirtanPlayAllHeader({
    super.key,
    required this.label,
    required this.onPlayAll,
    required this.onShuffle,
    this.icon = Icons.library_music_outlined,
  });

  final String label;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    void tap(VoidCallback action) {
      unawaited(HapticFeedback.selectionClick());
      action();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => tap(onPlayAll),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    l10n.kirtanPlayAll,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => tap(onShuffle),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: Text(
                    l10n.kirtanShuffle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KirtanListSkeleton extends StatelessWidget {
  const _KirtanListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Skeleton(
            child: SkeletonBox(
              height: 52,
              borderRadius: BorderRadius.all(Radius.circular(26)),
            ),
          ),
        ),
        Skeleton(
          child: SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.sm,
              ),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, int i) => SkeletonBox(
                width: i == 0 ? 56 : 88,
                height: 36,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
        ),
        const Expanded(child: SkeletonList()),
      ],
    );
  }
}
