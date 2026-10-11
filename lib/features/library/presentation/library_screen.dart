import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/menu_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/reading_progress_controller.dart';
import '../data/library_repository.dart';
import '../domain/book.dart';
import '../domain/library_queries.dart';
import '../domain/reading_progress.dart';
import 'widgets/book_grid.dart';
import 'widgets/continue_reading_card.dart';
import 'widgets/library_skeletons.dart';

/// Shastra tab: search, filter chips (All · Downloaded · categories), a
/// "Continue reading" card and a grid of scriptures.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  LibraryFilter _filter = LibraryFilter.all;

  // Memoised filter result (recomputed only when an input changes).
  List<Book>? _filterSource;
  String _filterQuery = '';
  LibraryFilter _filterApplied = LibraryFilter.all;
  Set<String>? _filterDownloaded;
  List<Book> _filtered = const <Book>[];

  @override
  void initState() {
    super.initState();
    // Keep the "downloaded" badges and filter in sync with the files on disk
    // whenever the list of books changes.
    ref.listenManual<AsyncValue<List<Book>>>(booksProvider, (
      AsyncValue<List<Book>>? previous,
      AsyncValue<List<Book>> next,
    ) {
      final List<Book>? books = next.value;
      if (books == null || identical(books, previous?.value)) return;
      unawaited(
        syncBookDownloads(
          ref.read(downloadManagerProvider.notifier),
          books.map((Book b) => b.id),
        ),
      );
    }, fireImmediately: true);
  }

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

  void _selectFilter(LibraryFilter filter) {
    if (filter == _filter) return;
    HapticFeedback.selectionClick().ignore();
    setState(() => _filter = filter);
  }

  void _openBook(Book book) {
    HapticFeedback.selectionClick().ignore();
    FocusManager.instance.primaryFocus?.unfocus();
    context.go(Routes.book(book.id));
  }

  void _continueReading(Book book) {
    HapticFeedback.selectionClick().ignore();
    unawaited(context.push(Routes.reader(book.id)));
  }

  List<Book> _visible(
    List<Book> all,
    LibraryFilter filter,
    Set<String> downloaded,
  ) {
    if (!identical(all, _filterSource) ||
        _query != _filterQuery ||
        filter != _filterApplied ||
        !identical(downloaded, _filterDownloaded)) {
      _filterSource = all;
      _filterQuery = _query;
      _filterApplied = filter;
      _filterDownloaded = downloaded;
      _filtered = filterBooks(
        all,
        query: _query,
        filter: filter,
        downloadedIds: downloaded,
      );
    }
    return _filtered;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<Book>> books = ref.watch(booksProvider);
    // Watched here (not inside the data builder, which runs during a child's
    // build) so Riverpod tracks these dependencies on this screen.
    final List<BookCategory> allCategories =
        ref.watch(bookCategoriesProvider).value ?? const <BookCategory>[];
    final Set<String> downloaded = ref.watch(downloadedBookIdsProvider);
    final bool offline = !(ref.watch(isOnlineProvider).value ?? true);

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: Text(l10n.libraryTitle),
        actions: const <Widget>[LanguageButton()],
      ),
      body: AsyncValueView<List<Book>>(
        value: books,
        onRetry: () => ref.invalidate(booksProvider),
        loading: const LibrarySkeleton(),
        isEmpty: (List<Book> list) => list.isEmpty,
        empty: offline
            ? EmptyState(
                icon: Icons.wifi_off_rounded,
                title: l10n.errorNetwork,
                action: FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(booksProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
              )
            : EmptyState(
                icon: Icons.menu_book_outlined,
                title: l10n.libraryEmpty,
              ),
        data: (List<Book> all) => _buildLibrary(all, allCategories, downloaded),
      ),
    );
  }

  Widget _buildLibrary(
    List<Book> all,
    List<BookCategory> allCategories,
    Set<String> downloaded,
  ) {
    final AppLocalizations l10n = context.l10n;
    final List<BookCategory> categories = bookCategoriesInUse(
      allCategories,
      all,
    );
    final LibraryFilter filter = effectiveLibraryFilter(_filter, categories);
    final List<Book> visible = _visible(all, filter, downloaded);
    final bool searching = _query.isNotEmpty;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _SearchField(
            controller: _search,
            onChanged: _onQueryChanged,
            onClear: _clearSearch,
          ),
        ),
        SliverToBoxAdapter(
          child: _FilterChips(
            categories: categories,
            selected: filter,
            onSelected: _selectFilter,
          ),
        ),
        // Hidden while searching or filtering so results come first.
        if (!searching && filter.isAll)
          _ContinueReadingSliver(books: all, onOpen: _continueReading),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _NoBooks(
              searching: searching,
              downloadedFilter: filter.kind == LibraryFilterKind.downloaded,
              onClearSearch: _clearSearch,
              onShowAll: () => _selectFilter(LibraryFilter.all),
              l10n: l10n,
            ),
          )
        else
          SliverBookGrid(
            books: visible,
            downloadedIds: downloaded,
            onOpen: _openBook,
          ),
      ],
    );
  }
}

/// "Continue reading" for the last opened book. Watches the reading progress
/// on its own so saving pages while reading never rebuilds the whole grid.
class _ContinueReadingSliver extends ConsumerWidget {
  const _ContinueReadingSliver({required this.books, required this.onOpen});

  final List<Book> books;
  final ValueChanged<Book> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = ref.watch(
      readingProgressProvider.select((ReadingProgress p) => p.lastBookId),
    );
    final Book? book = id == null ? null : findBook(books, id);
    if (book == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final (int?, int?) position = ref.watch(
      readingProgressProvider.select(
        (ReadingProgress p) => (p.pageFor(book.id), p.pageCountFor(book.id)),
      ),
    );
    return SliverToBoxAdapter(
      child: ContinueReadingCard(
        book: book,
        page: position.$1 ?? 1,
        pageCount: position.$2 ?? book.pageCount,
        onTap: () => onOpen(book),
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
        hintText: l10n.librarySearchHint,
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

/// All · Downloaded · one chip per category in use.
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<BookCategory> categories;
  final LibraryFilter selected;
  final ValueChanged<LibraryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final double height = MediaQuery.textScalerOf(context).scale(15) + 40;
    final List<LibraryFilter> filters = <LibraryFilter>[
      LibraryFilter.all,
      LibraryFilter.downloaded,
      for (final BookCategory c in categories) LibraryFilter.category(c.id),
    ];
    String label(LibraryFilter filter) => switch (filter.kind) {
      LibraryFilterKind.all => l10n.all,
      LibraryFilterKind.downloaded => l10n.downloaded,
      LibraryFilterKind.category =>
        categories
            .firstWhere((BookCategory c) => c.id == filter.categoryId)
            .name
            .of(context),
    };
    return SizedBox(
      height: height.clamp(52.0, 72.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.xs,
        ),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final LibraryFilter filter = filters[i];
          return Center(
            child: ChoiceChip(
              avatar: filter.kind == LibraryFilterKind.downloaded
                  ? const Icon(Icons.download_done_rounded, size: 18)
                  : null,
              label: Text(label(filter)),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
            ),
          );
        },
      ),
    );
  }
}

class _NoBooks extends StatelessWidget {
  const _NoBooks({
    required this.searching,
    required this.downloadedFilter,
    required this.onClearSearch,
    required this.onShowAll,
    required this.l10n,
  });

  final bool searching;
  final bool downloadedFilter;
  final VoidCallback onClearSearch;
  final VoidCallback onShowAll;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: l10n.libraryNoResults,
        action: FilledButton.tonal(
          onPressed: onClearSearch,
          child: Text(l10n.clearSearch),
        ),
      );
    }
    if (downloadedFilter) {
      return EmptyState(
        icon: Icons.download_for_offline_outlined,
        title: l10n.libraryDownloadedEmpty,
        action: FilledButton.tonal(onPressed: onShowAll, child: Text(l10n.all)),
      );
    }
    return EmptyState(
      icon: Icons.menu_book_outlined,
      title: l10n.libraryNoResults,
      action: FilledButton.tonal(onPressed: onShowAll, child: Text(l10n.all)),
    );
  }
}
