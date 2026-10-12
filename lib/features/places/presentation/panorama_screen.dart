import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

import '../../../core/firebase/media_url.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../core/widgets/language_button.dart';
import '../../../core/widgets/state_views.dart';
import '../data/places_repository.dart';
import '../domain/place_queries.dart';
import '../domain/prasadi_place.dart';

/// Full-screen, immersive 360° darshan of a prasadi place.
///
/// Drag (or move the phone) to look around, pinch to zoom. When a place has
/// several 360° photos a thumbnail strip switches between them, and Google
/// Street View is always one tap away as a fallback.
class PanoramaScreen extends ConsumerStatefulWidget {
  const PanoramaScreen({
    super.key,
    required this.placeId,
    this.initialIndex = 0,
  });

  final String placeId;
  final int initialIndex;

  @override
  ConsumerState<PanoramaScreen> createState() => _PanoramaScreenState();
}

class _PanoramaScreenState extends ConsumerState<PanoramaScreen> {
  late int _index = widget.initialIndex;
  bool _motion = true;
  bool _hintVisible = false;
  bool _hintShown = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    // Immersive: hide the system bars and allow turning the phone sideways.
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    // Restore the app-wide settings made in bootstrap().
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]),
    );
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.place(widget.placeId));
    }
  }

  /// Shows the "drag or move your phone" hint once, when the first 360°
  /// photo appears, and fades it out after a few seconds.
  void _onLoaded() {
    if (_hintShown || !mounted) return;
    _hintShown = true;
    setState(() => _hintVisible = true);
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  void _hideHint() {
    if (!_hintVisible) return;
    _hintTimer?.cancel();
    setState(() => _hintVisible = false);
  }

  void _toggleMotion() {
    HapticFeedback.selectionClick().ignore();
    setState(() => _motion = !_motion);
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick().ignore();
    setState(() => _index = index);
  }

  Future<void> _openStreetView(StreetViewTarget target) async {
    HapticFeedback.selectionClick().ignore();
    final bool opened = await Launcher.streetView(
      target.coordinate.latitude,
      target.coordinate.longitude,
      heading: target.heading,
      pitch: target.pitch,
    );
    if (!opened && mounted) context.showOpenLinkError();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PrasadiPlace?> value = ref.watch(
      placeProvider(widget.placeId),
    );
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white70)),
      ),
      error: (_, _) => _MessageScaffold(
        onClose: _close,
        child: ErrorState(onRetry: () => ref.invalidate(placesProvider)),
      ),
      data: (PrasadiPlace? place) {
        if (place == null || !place.hasPanorama) {
          return _MessageScaffold(
            onClose: _close,
            child: EmptyState(
              icon: Icons.threesixty_rounded,
              title: context.l10n.placeNotFound,
            ),
          );
        }
        return _viewer(context, place);
      },
    );
  }

  Widget _viewer(BuildContext context, PrasadiPlace place) {
    final AppLocalizations l10n = context.l10n;
    final List<String> panoramas = place.panoramaUrls;
    final int index = clampPanoramaIndex(_index, panoramas.length);
    final String raw = panoramas[index];
    final StreetViewTarget? streetView = place.streetViewTarget;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Listener(
              onPointerDown: (_) => _hideHint(),
              child: _PanoramaView(
                key: ValueKey<String>(raw),
                raw: raw,
                motion: _motion,
                onLoaded: _onLoaded,
              ),
            ),
            IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _hintVisible ? 1 : 0,
                  duration: AppDurations.slow,
                  child: const _Hint(),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                title: place.name.of(context),
                motion: _motion,
                onClose: _close,
                onToggleMotion: _toggleMotion,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (panoramas.length > 1)
                        _PanoramaSelector(
                          count: panoramas.length,
                          index: index,
                          onSelected: _select,
                        ),
                      if (streetView != null) ...<Widget>[
                        if (panoramas.length > 1)
                          const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: Colors.white38),
                          ),
                          onPressed: () => _openStreetView(streetView),
                          icon: const Icon(Icons.streetview_rounded),
                          label: Text(l10n.placeStreetView),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads one 360° photo and shows it on the sphere.
///
/// The photo is resolved and decoded here first (with progress and error
/// handling, which the viewer package does not offer), bounded to 4096 px so
/// huge uploads can never run the phone out of memory, and only then handed
/// to [PanoramaViewer], which picks it up instantly from the image cache.
class _PanoramaView extends ConsumerStatefulWidget {
  const _PanoramaView({
    super.key,
    required this.raw,
    required this.motion,
    required this.onLoaded,
  });

  final String raw;
  final bool motion;
  final VoidCallback onLoaded;

  @override
  ConsumerState<_PanoramaView> createState() => _PanoramaViewState();
}

class _PanoramaViewState extends ConsumerState<_PanoramaView> {
  /// The viewer package adds a listener to its controller and never removes
  /// it, so every new [PanoramaViewer] (after a retry) gets a fresh one.
  PanoramaController _controller = PanoramaController();
  ImageProvider<Object>? _provider;
  Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// Shows the photo even if the viewer never reports that its texture is
  /// ready, so the loading ring can never spin forever.
  Timer? _revealTimer;
  int _attempt = 0;
  bool _decoded = false;
  bool _visible = false;
  bool _failed = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void didUpdateWidget(_PanoramaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.motion && !oldWidget.motion && _decoded) {
      // panorama_viewer keeps its render loop running for the gyroscope only
      // when it starts that way; restart the loop once it has re-subscribed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.setAnimSpeed(0);
      });
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _detach();
    _controller.dispose();
    // A decoded 360° photo is ~30 MB: free it as soon as it leaves the
    // screen (it reloads quickly from the disk cache if opened again).
    final ImageProvider<Object>? provider = _provider;
    if (provider != null) {
      unawaited(provider.evict().catchError((Object _) => false));
    }
    super.dispose();
  }

  Future<void> _start() async {
    final int attempt = ++_attempt;
    final String url;
    try {
      url = await ref.read(mediaUrlResolverProvider).resolve(widget.raw);
    } catch (error, stack) {
      AppLogger.error('Panorama URL failed: ${widget.raw}', error, stack);
      if (mounted && attempt == _attempt) setState(() => _failed = true);
      return;
    }
    if (!mounted || attempt != _attempt) return;
    _attach(url);
  }

  void _attach(String url) {
    _detach();
    final Size physical =
        MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
    final int maxWidth = physical.longestSide >= 2000 ? 4096 : 3072;
    final ImageProvider<Object> provider = ResizeImage(
      CachedNetworkImageProvider(
        url,
        imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
      ),
      width: maxWidth,
      height: maxWidth ~/ 2,
      policy: ResizeImagePolicy.fit,
    );
    final ImageStreamListener listener = ImageStreamListener(
      _onImage,
      onChunk: _onChunk,
      onError: _onError,
    );
    _provider = provider;
    _image = Image(image: provider, gaplessPlayback: true);
    _listener = listener;
    // Keeping this listener attached also keeps the decoded photo alive in
    // the image cache while the viewer uses it.
    _stream = provider.resolve(createLocalImageConfiguration(context))
      ..addListener(listener);
  }

  void _detach() {
    final ImageStreamListener? listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    info.dispose();
    if (!mounted || _decoded) return;
    setState(() {
      _decoded = true;
      _progress = 1;
    });
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 4), _reveal);
  }

  void _onChunk(ImageChunkEvent event) {
    final int? total = event.expectedTotalBytes;
    if (!mounted || total == null || total <= 0) return;
    final double progress = (event.cumulativeBytesLoaded / total).clamp(
      0.0,
      1.0,
    );
    // Rebuild only for visible changes (every 2 %).
    if (_progress == null || (progress - _progress!).abs() >= 0.02) {
      setState(() => _progress = progress);
    }
  }

  void _onError(Object error, StackTrace? stack) {
    AppLogger.error('Panorama image failed: ${widget.raw}', error, stack);
    if (mounted) setState(() => _failed = true);
  }

  /// Called by the viewer when the photo is on the sphere. May arrive during
  /// a frame, so the rebuild is deferred.
  void _onTextureReady() => scheduleMicrotask(_reveal);

  void _reveal() {
    _revealTimer?.cancel();
    if (!mounted || _visible || !_decoded || _failed) return;
    setState(() => _visible = true);
    widget.onLoaded();
  }

  Future<void> _retry() async {
    HapticFeedback.selectionClick().ignore();
    _revealTimer?.cancel();
    _detach();
    final ImageProvider<Object>? provider = _provider;
    _provider = null;
    _image = null;
    final PanoramaController oldController = _controller;
    _controller = PanoramaController();
    oldController.dispose();
    if (provider != null) {
      try {
        await provider.evict();
      } catch (_) {
        // Nothing cached: fine.
      }
    }
    if (!mounted) return;
    setState(() {
      _failed = false;
      _decoded = false;
      _visible = false;
      _progress = null;
    });
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _PanoramaError(onRetry: _retry);
    final Image? image = _image;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_decoded && image != null)
          AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: AppDurations.slow,
            child: PanoramaViewer(
              panoramaController: _controller,
              sensorControl: widget.motion
                  ? SensorControl.orientation
                  : SensorControl.none,
              onImageLoad: _onTextureReady,
              child: image,
            ),
          ),
        if (!_visible) _PanoramaLoading(progress: _progress),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.motion,
    required this.onClose,
    required this.onToggleMotion,
  });

  final String title;
  final bool motion;
  final VoidCallback onClose;
  final VoidCallback onToggleMotion;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
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
            0,
            AppSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: l10n.close,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.placesMotionControl,
                isSelected: motion,
                style: IconButton.styleFrom(
                  backgroundColor: motion ? Colors.white : Colors.black45,
                  foregroundColor: motion ? Colors.black87 : Colors.white,
                ),
                icon: const Icon(Icons.screen_rotation_alt_rounded),
                onPressed: onToggleMotion,
              ),
              const LanguageButton(foregroundColor: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: Color(0xB3000000),
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.threesixty_rounded, color: Colors.white, size: 28),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              context.l10n.place360Hint,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanoramaLoading extends StatelessWidget {
  const _PanoramaLoading({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double? value = progress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: 56,
              child: CircularProgressIndicator(
                value: value == null || value >= 1 ? null : value,
                color: Colors.white,
                backgroundColor: Colors.white24,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.places360Loading,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: Colors.white70),
            ),
            if (value != null && value < 1) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${(value * 100).round()}%',
                style: text.labelLarge?.copyWith(color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PanoramaError extends StatelessWidget {
  const _PanoramaError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Colors.white60,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.errorGeneric,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numbered buttons to switch between several 360° photos.
///
/// Deliberately not thumbnails: a thumbnail of a 360° photo would download
/// and decode every full-size panorama at once, slowing down the one the
/// devotee is waiting for (and a squeezed sphere is hard to recognise).
class _PanoramaSelector extends StatelessWidget {
  const _PanoramaSelector({
    required this.count,
    required this.index,
    required this.onSelected,
  });

  final int count;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _PanoramaPill(
              label: l10n.placesPanoramaNumber(i + 1),
              selected: i == index,
              onTap: () {
                if (i != index) onSelected(i);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PanoramaPill extends StatelessWidget {
  const _PanoramaPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? Colors.black87 : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Colors.white : Colors.black54,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? Colors.white : Colors.white38),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
              minWidth: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.threesixty_rounded, size: 18, color: foreground),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain themed page for "not found" / error states of the 360° screen.
class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.l10n.close,
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
        title: Text(context.l10n.placeView360),
        actions: const <Widget>[LanguageButton()],
      ),
      body: child,
    );
  }
}
