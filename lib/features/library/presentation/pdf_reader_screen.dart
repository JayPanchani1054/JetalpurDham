import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/firebase/media_url.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/models/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/reading_progress_controller.dart';
import '../data/library_repository.dart';
import '../domain/book.dart';
import '../domain/library_queries.dart';
import 'widgets/book_download_controls.dart';
import 'widgets/go_to_page_dialog.dart';
import 'widgets/reader_states.dart';

/// Full-screen PDF reader (root navigator, covers the bottom bar).
///
/// Opens the downloaded file when the book is saved on the device, otherwise
/// streams it from the network (range requests, cached on disk by pdfrx).
/// Restores the last page read and remembers the current one, offers a large
/// "Page X of Y" control that jumps to any page, double-tap zoom, a fast
/// scroll thumb and "download for offline".
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

/// Where the PDF is read from.
class _ReaderSource {
  const _ReaderSource.file(String this.path) : uri = null;
  const _ReaderSource.network(Uri this.uri) : path = null;

  final String? path;
  final Uri? uri;

  bool get isLocal => path != null;
}

/// Current page and total pages (null until the document is ready).
@immutable
class _PagePosition {
  const _PagePosition(this.page, this.pageCount);

  final int page;
  final int? pageCount;

  @override
  bool operator ==(Object other) =>
      other is _PagePosition &&
      other.page == page &&
      other.pageCount == pageCount;

  @override
  int get hashCode => Object.hash(page, pageCount);
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  static const Duration _saveDelay = Duration(milliseconds: 600);

  late final ReadingProgressController _progress;
  late final AppLifecycleListener _lifecycle;
  final ValueNotifier<_PagePosition?> _position = ValueNotifier<_PagePosition?>(
    null,
  );

  PdfViewerController _controller = PdfViewerController();
  _ReaderSource? _source;
  bool _notFound = false;
  bool _failed = false;
  int _attempt = 0;
  int? _loggedErrorAttempt;
  bool _closing = false;

  /// The page to open at (restored, then kept up to date while reading).
  late int _lastPage;
  int? _unsavedPage;
  Timer? _saveTimer;

  PdfViewerParams? _params;
  Object? _paramsKey;

  @override
  void initState() {
    super.initState();
    _progress = ref.read(readingProgressProvider.notifier);
    _lastPage = math.max(
      1,
      ref.read(readingProgressProvider).pageFor(widget.bookId) ?? 1,
    );
    // Keep the providers that _open() awaits actively listened, so their
    // first value arrives even on a cold start (e.g. from a notification).
    ref
      ..listenManual<AsyncValue<bool>>(isOnlineProvider, (_, _) {})
      ..listenManual<AsyncValue<List<Book>>>(booksProvider, (_, _) {});
    // Persist the page if the app goes to the background mid-chapter.
    _lifecycle = AppLifecycleListener(onHide: _flushSave, onPause: _flushSave);
    // Keep the screen on during long reading sessions (best-effort).
    WakelockPlus.enable().ignore();
    unawaited(_open());
  }

  @override
  void dispose() {
    WakelockPlus.disable().ignore();
    _saveTimer?.cancel();
    _lifecycle.dispose();
    final int? page = _unsavedPage;
    if (page != null) {
      // Deferred: provider state must not change while the tree is locked.
      final ReadingProgressController progress = _progress;
      final String bookId = widget.bookId;
      final int? pageCount = _position.value?.pageCount;
      scheduleMicrotask(
        () => unawaited(progress.savePage(bookId, page, pageCount: pageCount)),
      );
    }
    _position.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Opening

  Future<void> _open({bool skipLocalFile = false}) async {
    final int attempt = _attempt;
    bool isCurrent() => mounted && attempt == _attempt;
    try {
      // Idempotent; bootstrap normally did this already.
      await pdfrxFlutterInitialize();
    } catch (error, stack) {
      AppLogger.error('PDF engine initialisation failed', error, stack);
    }
    try {
      if (!isCurrent()) return;
      if (!skipLocalFile) {
        final File? local = await ref
            .read(downloadManagerProvider.notifier)
            .localFile(bookDownloadKey(widget.bookId));
        if (!isCurrent()) return;
        if (local != null) {
          setState(() => _source = _ReaderSource.file(local.path));
          return;
        }
      }
      final List<Book> books = await ref
          .read(booksProvider.future)
          .timeout(const Duration(seconds: 20));
      if (!isCurrent()) return;
      final Book? book = findBook(books, widget.bookId);
      if (book == null) {
        // Offline before the library was ever cached: it may well exist.
        final bool offline = await _isOffline();
        if (!isCurrent()) return;
        setState(() {
          if (offline) {
            _failed = true;
          } else {
            _notFound = true;
          }
        });
        return;
      }
      final String url = await ref
          .read(mediaUrlResolverProvider)
          .resolve(book.pdfUrl);
      final Uri uri = Uri.parse(url);
      if (!isCurrent()) return;
      setState(() => _source = _ReaderSource.network(uri));
    } catch (error, stack) {
      AppLogger.error('Could not open book ${widget.bookId}', error, stack);
      if (isCurrent()) setState(() => _failed = true);
    }
  }

  /// Connectivity, waiting briefly for the first value on a cold start (for
  /// example when the reader is opened straight from a notification).
  Future<bool> _isOffline() async {
    try {
      final bool online = await ref
          .read(isOnlineProvider.future)
          .timeout(const Duration(seconds: 2));
      return !online;
    } catch (_) {
      return false;
    }
  }

  void _retry({bool skipLocalFile = false}) {
    HapticFeedback.selectionClick().ignore();
    _flushSave();
    setState(() {
      _attempt++;
      _source = null;
      _failed = false;
      _notFound = false;
      _controller = PdfViewerController();
    });
    _position.value = null;
    unawaited(_open(skipLocalFile: skipLocalFile));
  }

  PdfDocumentRef _documentRef(_ReaderSource source) {
    // The attempt is part of the key so "Retry" really reloads.
    final List<Object?> parts = <Object?>[_attempt];
    final String? path = source.path;
    if (path != null) {
      return PdfDocumentRefFile(path, key: PdfDocumentRefKey(path, parts));
    }
    final Uri uri = source.uri!;
    return PdfDocumentRefUri(
      uri,
      key: PdfDocumentRefKey(uri.toString(), parts),
      // Opens large scriptures quickly: only the pages being read are
      // fetched (falls back to a full download if the server can't do it).
      preferRangeAccess: true,
      timeout: const Duration(seconds: 30),
    );
  }

  // ---------------------------------------------------------------------------
  // Viewer callbacks

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    if (!mounted) return;
    final int count = document.pages.length;
    final int page = (controller.pageNumber ?? _lastPage).clamp(
      1,
      math.max(1, count),
    );
    _lastPage = page;
    _position.value = _PagePosition(page, count);
    // Only a book that really opened becomes "Continue reading": a link to
    // a removed or unreachable book must not replace the devotee's place.
    // (Runs in a microtask after layout, so changing providers is safe.)
    unawaited(_progress.markOpened(widget.bookId));
    unawaited(_progress.savePage(widget.bookId, page, pageCount: count));
  }

  void _onPageChanged(int? page) {
    if (page == null || !mounted) return;
    _lastPage = page;
    _position.value = _PagePosition(page, _position.value?.pageCount);
    _unsavedPage = page;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _flushSave);
  }

  void _flushSave() {
    _saveTimer?.cancel();
    final int? page = _unsavedPage;
    if (page == null) return;
    _unsavedPage = null;
    unawaited(
      _progress.savePage(
        widget.bookId,
        page,
        pageCount: _position.value?.pageCount,
      ),
    );
  }

  /// Double tap: zoom in on that spot, or back to fit-width when zoomed.
  bool _onGeneralTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (details.type != PdfViewerGeneralTapType.doubleTap ||
        !controller.isReady) {
      return false;
    }
    final double target = doubleTapZoomTarget(
      currentZoom: controller.currentZoom,
      fitZoom: controller.coverScale,
      maxZoom: controller.maxScale,
    );
    unawaited(
      controller
          .zoomOnLocalPosition(
            localPosition: details.localPosition,
            newZoom: target,
            duration: AppDurations.medium,
          )
          .catchError(
            (Object error, StackTrace stack) =>
                AppLogger.error('Reader zoom failed', error, stack),
          ),
    );
    return true;
  }

  /// Table-of-contents links jump inside the book; web links open outside.
  void _onLinkTap(PdfLink link) {
    final PdfDest? dest = link.dest;
    if (dest != null) {
      unawaited(
        _controller.goToDest(dest).catchError((Object error, StackTrace stack) {
          AppLogger.error('Reader link failed', error, stack);
          return false;
        }),
      );
      return;
    }
    final Uri? url = link.url;
    if (url != null) unawaited(_openUrl(url));
  }

  Future<void> _openUrl(Uri url) async {
    final bool opened = await Launcher.url(url.toString());
    if (!opened && mounted) context.showOpenLinkError();
  }

  Future<void> _goToPage() async {
    final _PagePosition? position = _position.value;
    final int? pageCount = position?.pageCount;
    if (position == null || pageCount == null || !_controller.isReady) return;
    HapticFeedback.selectionClick().ignore();
    final int? page = await showGoToPageDialog(
      context,
      currentPage: position.page,
      pageCount: pageCount,
    );
    if (page == null || !mounted || !_controller.isReady) return;
    try {
      await _controller.goToPage(
        pageNumber: page,
        anchor: PdfPageAnchor.top,
        duration: AppDurations.slow,
      );
    } catch (error, stack) {
      AppLogger.error('Reader go-to-page failed', error, stack);
    }
  }

  // ---------------------------------------------------------------------------
  // UI

  PdfViewerParams _viewerParams(BuildContext context, bool isLocal) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Object key = (scheme.surfaceContainerHigh, isLocal);
    final PdfViewerParams? cached = _params;
    if (cached != null && _paramsKey == key) return cached;
    _paramsKey = key;
    return _params = PdfViewerParams(
      backgroundColor: scheme.surfaceContainerHigh,
      margin: 10,
      pageDropShadow: const BoxShadow(
        color: Color(0x33000000),
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
      // Native-feeling fling and overscroll for smooth reading.
      scrollPhysics: PdfViewerParams.getScrollPhysics(context),
      // Long-press menus and text selection confuse more than they help on
      // scanned Gujarati/Sanskrit scriptures.
      textSelectionParams: const PdfTextSelectionParams(enabled: false),
      buildContextMenu: (_, _) => null,
      linkHandlerParams: PdfLinkHandlerParams(
        onLinkTap: _onLinkTap,
        linkColor: scheme.primary.withValues(alpha: 0.12),
        enableAutoLinkDetection: false,
      ),
      onViewerReady: _onViewerReady,
      onPageChanged: _onPageChanged,
      onGeneralTap: _onGeneralTap,
      loadingBannerBuilder: (
        BuildContext context,
        int downloaded,
        int? total,
      ) => ReaderPreparing(bytesDownloaded: downloaded, totalBytes: total),
      errorBannerBuilder:
          (
            BuildContext context,
            Object error,
            StackTrace? stack,
            PdfDocumentRef documentRef,
          ) {
            if (_loggedErrorAttempt != _attempt) {
              _loggedErrorAttempt = _attempt;
              AppLogger.error(
                'PDF failed to load: ${widget.bookId}',
                error,
                stack,
              );
            }
            // A damaged offline copy: try the online copy on retry.
            return ReaderError(
              isDownloaded: isLocal,
              onRetry: () => _retry(skipLocalFile: isLocal),
            );
          },
      viewerOverlayBuilder:
          (BuildContext context, Size size, PdfViewerHandleLinkTap _) =>
              <Widget>[
                PdfViewerScrollThumb(
                  controller: _controller,
                  thumbSize: const Size(52, 48),
                  margin: 0,
                  thumbBuilder: (
                    BuildContext context,
                    Size thumbSize,
                    int? pageNumber,
                    PdfViewerController controller,
                  ) => _ScrollThumb(page: pageNumber),
                ),
              ],
    );
  }

  /// Leaves the reader. Opened straight from a notification or link there is
  /// nothing underneath on the root navigator, so go to the book's page
  /// instead of closing the app.
  void _close() {
    if (_closing || !mounted) return;
    final NavigatorState? navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      _closing = true;
      navigator.pop();
      return;
    }
    _closing = true;
    _flushSave();
    context.go(Routes.book(widget.bookId));
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: canPop ? null : BackButton(onPressed: _close),
          title: _ReaderTitle(bookId: widget.bookId),
          actions: <Widget>[
            ReaderDownloadAction(bookId: widget.bookId),
            const LanguageButton(),
          ],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (_notFound) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: l10n.libraryBookNotFound,
        action: FilledButton.tonalIcon(
          onPressed: () => context.go(Routes.library),
          icon: const Icon(Icons.auto_stories_rounded),
          label: Text(l10n.libraryTitle),
        ),
      );
    }
    if (_failed) {
      return ReaderError(isDownloaded: false, onRetry: _retry);
    }
    final _ReaderSource? source = _source;
    if (source == null) return const ReaderPreparing();
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: PdfViewer(
            _documentRef(source),
            key: ValueKey<int>(_attempt),
            controller: _controller,
            initialPageNumber: _lastPage,
            params: _viewerParams(context, source.isLocal),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
          child: Center(
            child: ValueListenableBuilder<_PagePosition?>(
              valueListenable: _position,
              builder:
                  (BuildContext context, _PagePosition? position, Widget? _) =>
                      AnimatedSwitcher(
                        duration: AppDurations.medium,
                        child: position == null
                            ? const SizedBox.shrink()
                            : _PagePill(position: position, onTap: _goToPage),
                      ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderTitle extends ConsumerWidget {
  const _ReaderTitle({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocalizedText? title = ref.watch(
      bookProvider(bookId)
          .select((AsyncValue<Book?> value) => value.value?.title),
    );
    return Text(
      title?.of(context) ?? context.l10n.libraryTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Large "Page X of Y" control at the bottom; tap to jump to a page.
class _PagePill extends StatelessWidget {
  const _PagePill({required this.position, required this.onTap});

  final _PagePosition position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final int? total = position.pageCount;
    final String label = total == null
        ? l10n.libraryPageNumber(position.page)
        : l10n.readerPageOf(position.page, total);
    return Tooltip(
      message: l10n.readerGoToPage,
      // excludeSemantics drops the InkWell's own tap action, so it is
      // provided here for screen readers.
      child: Semantics(
        button: true,
        enabled: total != null,
        label: '$label. ${l10n.readerGoToPage}',
        onTap: total == null ? null : onTap,
        excludeSemantics: true,
        child: Material(
          color: scheme.inverseSurface.withValues(alpha: 0.9),
          elevation: 3,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: total == null ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg + 2,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.find_in_page_outlined,
                      size: 20,
                      color: scheme.onInverseSurface,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fast-scroll handle on the right edge showing the current page number.
class _ScrollThumb extends StatelessWidget {
  const _ScrollThumb({required this.page});

  final int? page;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(24),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: FittedBox(
              child: Text(
                page?.toString() ?? '',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
