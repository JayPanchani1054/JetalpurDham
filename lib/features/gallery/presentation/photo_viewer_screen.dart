import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/firebase/media_url.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../core/widgets/expandable_text.dart';
import '../application/photo_saver.dart';
import '../data/gallery_repository.dart';
import '../domain/gallery_models.dart';
import '../domain/gallery_queries.dart';
import 'widgets/gallery_hero.dart';

/// Full-screen, immersive photo viewer: swipe between photos, pinch or
/// double-tap to zoom, tap to show/hide the controls, swipe down to close.
/// "Save to Gallery" and "Share" work on the full-resolution photo.
///
/// Reads the album's photos itself, so it also works when opened directly
/// from a link or notification.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.albumId,
    this.initialIndex = 0,
  });

  final String albumId;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  PageController? _pages;
  int _index = 0;
  String? _currentId;
  List<AlbumPhoto> _photos = const <AlbumPhoto>[];
  Map<int, AsyncValue<String>> _urls = const <int, AsyncValue<String>>{};
  final Set<String> _precached = <String>{};

  bool _chromeVisible = true;
  bool _zoomed = false;
  bool _saving = false;
  bool _sharing = false;
  bool _closing = false;

  /// Retry count per photo id; part of the page key so "Retry" reloads it.
  final Map<String, int> _attempts = <String, int>{};

  late ThemeData _theme;
  AppLanguage? _themeLanguage;
  int _decodeSize = 2048;

  /// One provider per photo URL, so rebuilds never re-resolve an image.
  final Map<String, ImageProvider> _providers = <String, ImageProvider>{};

  /// Vertical offset while swiping the photo away.
  final ValueNotifier<double> _drag = ValueNotifier<double>(0);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: AppDurations.medium,
  )..addListener(_onSettleTick);
  double _settleFrom = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Size size = MediaQuery.sizeOf(context);
    final int decodeSize = viewerDecodeSize(
      size.longestSide,
      MediaQuery.devicePixelRatioOf(context),
    );
    if (decodeSize != _decodeSize) {
      _decodeSize = decodeSize;
      _providers.clear();
      _precached.clear();
    }
    final AppLanguage language = context.appLanguage;
    if (_themeLanguage != language) {
      _themeLanguage = language;
      _theme = AppTheme.dark(language);
    }
  }

  @override
  void didUpdateWidget(covariant PhotoViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A link to another photo of the same album can reuse this screen
    // (only `?i=` changed): move to the requested photo.
    if (oldWidget.initialIndex == widget.initialIndex || _photos.isEmpty) {
      return;
    }
    final int target = clampIndex(widget.initialIndex, _photos.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final PageController? pages = _pages;
      if (mounted && pages != null && pages.hasClients) {
        pages.jumpToPage(target);
      }
    });
  }

  @override
  void dispose() {
    if (!_chromeVisible) _setSystemUi(SystemUiMode.edgeToEdge);
    _pages?.dispose();
    _settle.dispose();
    _drag.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Images

  /// Full-resolution image, decoded no larger than needed for sharp zooming.
  ImageProvider _fullImage(String url) => _providers[url] ??= ResizeImage(
    CachedNetworkImageProvider(
      url,
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
    ),
    width: _decodeSize,
    height: _decodeSize,
    policy: ResizeImagePolicy.fit,
  );

  AsyncValue<String> _watchUrl(AlbumPhoto photo) =>
      MediaUrlResolver.isDirect(photo.url)
      ? AsyncData<String>(photo.url)
      : ref.watch(mediaUrlProvider(photo.url));

  /// Loads a photo again after it failed (no internet, expired link…).
  /// [resolved] is null when the Storage link itself could not be resolved.
  void _retryPhoto(AlbumPhoto photo, String? resolved) {
    HapticFeedback.selectionClick().ignore();
    if (resolved == null) {
      ref.invalidate(mediaUrlProvider(photo.url));
    } else {
      // Drop the failed image so a fresh download starts.
      final ImageProvider? failed = _providers.remove(resolved);
      _precached.remove(resolved);
      if (failed != null) unawaited(failed.evict());
    }
    setState(() => _attempts[photo.id] = (_attempts[photo.id] ?? 0) + 1);
  }

  /// Warms the neighbouring photos so swiping shows them instantly.
  void _precacheNeighbours() {
    if (!mounted) return;
    for (final int i in <int>[_index + 1, _index - 1]) {
      final String? url = _urls[i]?.value;
      if (url == null || !_precached.add(url)) continue;
      unawaited(
        precacheImage(
          _fullImage(url),
          context,
          onError: (Object error, StackTrace? stack) {
            _precached.remove(url);
          },
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Chrome, paging and closing

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    _setSystemUi(
      _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  static void _setSystemUi(SystemUiMode mode) {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(mode).catchError((Object error) {
        AppLogger.info('System UI mode change failed: $error');
      }),
    );
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _photos.length) return;
    setState(() {
      _index = index;
      _currentId = _photos[index].id;
      _zoomed = false;
    });
  }

  void _onScaleStateChanged(PhotoViewScaleState state) {
    // photo_view reports this through a stream, so it can arrive after the
    // viewer has closed.
    if (!mounted) return;
    final bool zoomed =
        state == PhotoViewScaleState.zoomedIn ||
        state == PhotoViewScaleState.covering ||
        state == PhotoViewScaleState.originalSize;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _close() {
    // A second close (double tap, or a swipe ending as the button is
    // pressed) must not pop the screen underneath or re-route the app.
    if (_closing || !mounted) return;
    _closing = true;
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(Routes.album(widget.albumId));
    }
  }

  void _onSettleTick() {
    _drag.value =
        _settleFrom * (1 - Curves.easeOutCubic.transform(_settle.value));
  }

  void _onDragStart(DragStartDetails details) => _settle.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    _drag.value += details.delta.dy;
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.velocity.pixelsPerSecond.dy;
    if (_drag.value.abs() > 110 || velocity.abs() > 900) {
      HapticFeedback.selectionClick().ignore();
      _close();
      return;
    }
    _settleFrom = _drag.value;
    unawaited(_settle.forward(from: 0));
  }

  /// Keeps showing the same photo when the album changes while it is open
  /// (photos added, reordered or removed in the console).
  void _onPhotosChanged(
    AsyncValue<LiveList<AlbumPhoto>>? previous,
    AsyncValue<LiveList<AlbumPhoto>> next,
  ) {
    final List<AlbumPhoto>? photos = next.value?.items;
    final PageController? pages = _pages;
    if (photos == null || photos.isEmpty || pages == null) return;
    final int found = indexOfPhoto(photos, _currentId);
    final int target = found >= 0 ? found : clampIndex(_index, photos.length);
    _currentId = photos[target].id;
    if (target == _index) return;
    setState(() => _index = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && pages.hasClients) pages.jumpToPage(target);
    });
  }

  // ---------------------------------------------------------------------------
  // Save & share

  Future<void> _save(AlbumPhoto photo) async {
    if (_saving) return;
    final AppLocalizations l10n = context.l10n;
    HapticFeedback.selectionClick().ignore();
    setState(() => _saving = true);
    final PhotoSaveOutcome outcome = await ref
        .read(photoSaverProvider)
        .save(photo, albumId: widget.albumId);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (outcome) {
      case PhotoSaveOutcome.saved:
        HapticFeedback.mediumImpact().ignore();
        context.showSnack(l10n.gallerySaved);
      case PhotoSaveOutcome.denied:
        context.showSnack(l10n.galleryPermissionDenied);
      case PhotoSaveOutcome.failed:
        context.showSnack(
          _isOffline ? l10n.errorNetwork : l10n.gallerySaveFailed,
        );
    }
  }

  /// True when the device has no connection (a likely reason a photo that
  /// was not on screen yet could not be saved or shared).
  bool get _isOffline => !(ref.read(isOnlineProvider).value ?? true);

  Future<void> _share(AlbumPhoto photo, String albumTitle, Rect? origin) async {
    if (_sharing) return;
    final AppLocalizations l10n = context.l10n;
    HapticFeedback.selectionClick().ignore();
    setState(() => _sharing = true);
    final bool shared = await ref
        .read(photoSaverProvider)
        .share(
          photo,
          albumId: widget.albumId,
          text: l10n.galleryShareText(albumTitle),
          origin: origin,
        );
    if (!mounted) return;
    setState(() => _sharing = false);
    if (!shared) {
      context.showSnack(_isOffline ? l10n.errorNetwork : l10n.errorGeneric);
    }
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LiveList<AlbumPhoto>> photosAsync = ref.watch(
      albumPhotosProvider(widget.albumId),
    );
    final Album? album = ref.watch(
      albumLookupProvider(widget.albumId)
          .select((AsyncValue<AlbumLookup> value) => value.value?.album),
    );
    ref
      ..listen<AsyncValue<LiveList<AlbumPhoto>>>(
        albumPhotosProvider(widget.albumId),
        _onPhotosChanged,
      )
      // Keeps the connection state current for the save/share messages.
      ..listen<AsyncValue<bool>>(isOnlineProvider, (_, _) {});

    final LiveList<AlbumPhoto>? list = photosAsync.value;
    final Widget content;
    if (album != null && !album.isActive) {
      // Hidden by the temple (also when opened from an old link).
      content = _statusPage(
        _StatusMessage(
          icon: Icons.photo_library_outlined,
          message: context.l10n.galleryAlbumNotFound,
        ),
      );
    } else if (list == null) {
      content = photosAsync.hasError
          ? _statusPage(
              _StatusMessage(
                icon: Icons.cloud_off_rounded,
                message: context.l10n.errorGeneric,
                actionLabel: context.l10n.retry,
                onAction: () =>
                    ref.invalidate(albumPhotosProvider(widget.albumId)),
              ),
            )
          : _statusPage(const CircularProgressIndicator(color: Colors.white70));
    } else if (list.isEmpty) {
      content = _statusPage(
        _StatusMessage(
          icon: list.isUnavailableOffline
              ? Icons.wifi_off_rounded
              : Icons.photo_camera_back_outlined,
          message: list.isUnavailableOffline
              ? context.l10n.errorNetwork
              : context.l10n.galleryEmpty,
        ),
      );
    } else {
      content = _viewer(list.items, album);
    }

    return Theme(
      data: _theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.black,
        ),
        child: content,
      ),
    );
  }

  Widget _statusPage(Widget child) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Center(child: child),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(onClose: _close),
          ),
        ],
      ),
    );
  }

  Widget _viewer(List<AlbumPhoto> photos, Album? album) {
    _photos = photos;
    final PageController? previous = _pages;
    if (previous == null || !previous.hasClients) {
      // First build, or the pager was removed while the album was briefly
      // empty: start at the requested photo (or the one last shown).
      final int found = indexOfPhoto(photos, _currentId);
      _index = previous == null
          ? clampIndex(widget.initialIndex, photos.length)
          : (found >= 0 ? found : clampIndex(_index, photos.length));
      _currentId = photos[_index].id;
      previous?.dispose();
      _pages = PageController(initialPage: _index);
    } else if (_index >= photos.length) {
      _index = photos.length - 1;
    }
    // Resolve storage links for the visible photo and its neighbours only.
    _urls = <int, AsyncValue<String>>{
      for (
        int i = math.max(0, _index - 2);
        i <= math.min(photos.length - 1, _index + 2);
        i++
      )
        i: _watchUrl(photos[i]),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNeighbours());

    final AlbumPhoto current = photos[_index];
    final String locale = Localizations.localeOf(context).languageCode;
    final String albumTitle =
        album?.titleFor(locale) ?? humanizeAlbumId(widget.albumId);

    Widget chrome(Widget child) => ValueListenableBuilder<double>(
      valueListenable: _drag,
      builder: (BuildContext context, double dy, Widget? child) {
        final double fade = 1 - (dy.abs() / 160).clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: !_chromeVisible || dy != 0,
          child: Opacity(opacity: fade, child: child),
        );
      },
      child: AnimatedOpacity(
        opacity: _chromeVisible ? 1 : 0,
        duration: AppDurations.fast,
        child: child,
      ),
    );

    final Widget gallery = PhotoViewGestureDetectorScope(
      axis: Axis.horizontal,
      child: PageView.builder(
        controller: _pages,
        itemCount: photos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: _buildPage,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragStart: _zoomed ? null : _onDragStart,
              onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
              onVerticalDragEnd: _zoomed ? null : _onDragEnd,
              child: ValueListenableBuilder<double>(
                valueListenable: _drag,
                builder: (BuildContext context, double dy, Widget? child) {
                  final double scale = 1 - (dy.abs() / 2400).clamp(0.0, 0.15);
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: gallery,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: chrome(
              _TopBar(
                onClose: _close,
                position: '${_index + 1} / ${photos.length}',
                positionLabel: context.l10n.galleryPhotoLabel(
                  _index + 1,
                  photos.length,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: chrome(
        _BottomBar(
          // A fresh caption (collapsed again) for every photo.
          key: ValueKey<String>(current.id),
          caption: current.caption.of(context),
          saving: _saving,
          sharing: _sharing,
          onSave: () => _save(current),
          onShare: (Rect? origin) => _share(current, albumTitle, origin),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    if (index < 0 || index >= _photos.length) return const SizedBox.shrink();
    final AlbumPhoto photo = _photos[index];
    final AsyncValue<String> url =
        _urls[index] ??
        (MediaUrlResolver.isDirect(photo.url)
            ? AsyncData<String>(photo.url)
            : const AsyncLoading<String>());
    final String? resolved = url.value;
    // Taps toggle the controls on every page state, not only once the photo
    // is zoomable.
    Widget tappable(Widget child) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleChrome,
      child: child,
    );
    if (resolved == null) {
      return tappable(
        // Settled failures only: while Riverpod retries on its own (or after
        // "Retry") the loading placeholder is shown instead.
        url.hasError && !url.isLoading
            ? _PhotoError(onRetry: () => _retryPhoto(photo, null))
            : _PhotoPlaceholder(raw: photo.previewUrl),
      );
    }
    final String caption = photo.caption.of(context);
    final String label = context.l10n.galleryPhotoLabel(
      index + 1,
      _photos.length,
    );
    final int attempt = _attempts[photo.id] ?? 0;
    return ClipRect(
      child: PhotoView(
        key: ValueKey<String>('${photo.id}|$resolved|$attempt'),
        imageProvider: _fullImage(resolved),
        semanticLabel: caption.isEmpty ? label : '$label. $caption',
        heroAttributes: PhotoViewHeroAttributes(
          tag: photoHeroTag(widget.albumId, photo.id),
          flightShuttleBuilder: galleryHeroShuttle,
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        filterQuality: FilterQuality.medium,
        minScale: PhotoViewComputedScale.contained,
        initialScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.contained * 5,
        scaleStateChangedCallback: _onScaleStateChanged,
        onTapUp: (
          BuildContext context,
          TapUpDetails details,
          PhotoViewControllerValue value,
        ) => _toggleChrome(),
        loadingBuilder: (BuildContext context, ImageChunkEvent? event) =>
            tappable(
              _PhotoPlaceholder(
                raw: photo.previewUrl,
                progress: _fraction(event),
              ),
            ),
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            tappable(_PhotoError(onRetry: () => _retryPhoto(photo, resolved))),
      ),
    );
  }

  static double? _fraction(ImageChunkEvent? event) {
    final int? total = event?.expectedTotalBytes;
    if (event == null || total == null || total <= 0) return null;
    return (event.cumulativeBytesLoaded / total).clamp(0.0, 1.0);
  }
}

/// Shown while the full photo downloads: the (already cached) thumbnail,
/// scaled up, with a progress ring — never an empty black screen.
class _PhotoPlaceholder extends ConsumerWidget {
  const _PhotoPlaceholder({required this.raw, this.progress});

  final String raw;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? url = MediaUrlResolver.isDirect(raw)
        ? raw
        : ref.watch(mediaUrlProvider(raw)).value;
    final double width =
        MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (url != null)
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            memCacheWidth: width.round().clamp(320, 2048),
            fadeInDuration: Duration.zero,
            imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        Center(
          child: SizedBox.square(
            dimension: 44,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoError extends StatelessWidget {
  const _PhotoError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _StatusMessage(
    icon: Icons.broken_image_outlined,
    message: context.l10n.galleryPhotoLoadFailed,
    actionLabel: context.l10n.retry,
    onAction: onRetry,
  );
}

/// White icon + message (+ optional action) for the black viewer.
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white54, size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Colors.white70),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Close button and "3 / 120" position over a soft top gradient.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, this.position, this.positionLabel});

  final VoidCallback onClose;
  final String? position;
  final String? positionLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x99000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: context.l10n.close,
                iconSize: 28,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.square(AppSpacing.minTouchTarget),
                ),
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
              ),
              const Spacer(),
              if (position != null)
                Semantics(
                  label: positionLabel,
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs + 2,
                      ),
                      child: Text(
                        position!,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(color: Colors.white),
                      ),
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

/// Caption plus large, labelled "Save to Gallery" and "Share" buttons.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    super.key,
    required this.caption,
    required this.saving,
    required this.sharing,
    required this.onSave,
    required this.onShare,
  });

  final String caption;
  final bool saving;
  final bool sharing;
  final VoidCallback onSave;
  final void Function(Rect? origin) onShare;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x00000000), Color(0xCC000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xl,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (caption.isNotEmpty) ...<Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                  ),
                  child: SingleChildScrollView(
                    child: ExpandableText(
                      caption,
                      collapsedLines: 3,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ViewerButton(
                      icon: Icons.download_rounded,
                      label: l10n.gallerySave,
                      busy: saving,
                      onPressed: onSave,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Builder(
                      builder: (BuildContext buttonContext) => _ViewerButton(
                        icon: Icons.share_rounded,
                        label: l10n.share,
                        busy: sharing,
                        onPressed: () => onShare(_rectOf(buttonContext)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where the share sheet should point on iPad.
  static Rect? _rectOf(BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

class _ViewerButton extends StatelessWidget {
  const _ViewerButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        textStyle: Theme.of(context).textTheme.titleSmall,
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      // Shrinks slightly instead of cutting off long labels
      // ("Save to Gallery", "ગેલેરીમાં સાચવો") on narrow phones.
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
  }
}
