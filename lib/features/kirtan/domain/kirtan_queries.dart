import 'kirtan.dart';

/// Pure list operations used by the kirtan screens. Kept free of Flutter and
/// Firebase so they are cheap to unit test and safe to run on every rebuild.

/// Active, playable kirtans sorted by `order`, then title.
List<Kirtan> sortActiveKirtans(Iterable<Kirtan> kirtans) {
  final List<Kirtan> list =
      kirtans.where((Kirtan k) => k.isActive && k.isPlayable).toList()
        ..sort(Kirtan.compare);
  return List<Kirtan>.unmodifiable(list);
}

/// Active categories sorted by `order`, then name.
List<KirtanCategory> sortActiveCategories(Iterable<KirtanCategory> items) {
  final List<KirtanCategory> list =
      items.where((KirtanCategory c) => c.isActive).toList()
        ..sort(KirtanCategory.compare);
  return List<KirtanCategory>.unmodifiable(list);
}

/// Featured kirtans for Home: those marked `isFeatured`, or the first
/// [fallbackCount] kirtans when none are marked.
List<Kirtan> selectFeaturedKirtans(
  List<Kirtan> sorted, {
  int fallbackCount = 8,
}) {
  final List<Kirtan> featured = sorted
      .where((Kirtan k) => k.isFeatured)
      .toList(growable: false);
  if (featured.isNotEmpty) return featured;
  return sorted.take(fallbackCount).toList(growable: false);
}

/// Kirtans in [categoryId] (all when null) whose title, poet or singer
/// matches [query] in any language.
List<Kirtan> filterKirtans(
  List<Kirtan> kirtans, {
  String query = '',
  String? categoryId,
}) {
  final String q = query.trim();
  if (q.isEmpty && categoryId == null) return kirtans;
  return kirtans
      .where(
        (Kirtan k) =>
            (categoryId == null || k.categoryId == categoryId) && k.matches(q),
      )
      .toList(growable: false);
}

/// Categories that contain at least one of [kirtans], so a chip never leads
/// to an empty list.
List<KirtanCategory> categoriesInUse(
  List<KirtanCategory> categories,
  List<Kirtan> kirtans,
) {
  final Set<String> used = <String>{
    for (final Kirtan k in kirtans)
      if (k.categoryId != null) k.categoryId!,
  };
  return categories
      .where((KirtanCategory c) => used.contains(c.id))
      .toList(growable: false);
}

/// Index of the kirtan to start from when [startIndex] in [original] was
/// requested but only [playable] items could be queued.
///
/// With [strict] the requested kirtan itself must be playable (a tapped row);
/// otherwise the first playable item at or after it is used (Play all).
/// Returns null when nothing suitable is playable.
int? resolveStartIndex({
  required List<Kirtan> original,
  required int startIndex,
  required List<Kirtan> playable,
  required bool strict,
}) {
  if (original.isEmpty || playable.isEmpty) return null;
  final int start = startIndex.clamp(0, original.length - 1);
  final Map<String, int> positions = <String, int>{
    for (int i = 0; i < playable.length; i++) playable[i].id: i,
  };
  final int? exact = positions[original[start].id];
  if (exact != null || strict) return exact;
  for (int offset = 1; offset < original.length; offset++) {
    final int? next =
        positions[original[(start + offset) % original.length].id];
    if (next != null) return next;
  }
  return null;
}

/// Queue positions in play order starting with [current]. [order] is the
/// player's effective order (shuffled or not); with [wrap] (repeat all) the
/// items played before [current] follow at the end.
List<int> upcomingQueueOrder(
  List<int> order,
  int current, {
  required bool wrap,
}) {
  final int position = order.indexOf(current);
  if (position < 0) return <int>[current];
  return <int>[
    ...order.sublist(position),
    if (wrap) ...order.sublist(0, position),
  ];
}
