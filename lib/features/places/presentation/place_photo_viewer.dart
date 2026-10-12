import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/firebase/media_url.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';

/// Opens the full-screen, zoomable photo viewer above the bottom bar.
Future<void> openPlacePhotoViewer(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: AppDurations.medium,
      reverseTransitionDuration: AppDurations.medium,
      pageBuilder: (_, _, _) => PlacePhotoViewer(
        images: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
      ),
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Swipeable, pinch-to-zoom gallery of a place's photos on black.
class PlacePhotoViewer extends StatefulWidget {
  const PlacePhotoViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<PlacePhotoViewer> createState() => _PlacePhotoViewerState();
}

class _PlacePhotoViewerState extends State<PlacePhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.images.length;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: PhotoViewGallery.builder(
                itemCount: count,
                pageController: _pages,
                onPageChanged: (int i) => setState(() => _index = i),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                builder: (BuildContext context, int i) =>
                    PhotoViewGalleryPageOptions.customChild(
                      child: _ViewerImage(raw: widget.images[i]),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.contained * 4,
                      initialScale: PhotoViewComputedScale.contained,
                    ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: context.l10n.close,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (count > 1)
                      DecoratedBox(
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
                            '${_index + 1} / $count',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One photo, resolved from its media reference and decoded sharp enough
/// for zooming (but bounded so huge uploads never exhaust memory).
class _ViewerImage extends ConsumerWidget {
  const _ViewerImage({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaUrlResolver.isDirect(raw)) return _image(context, raw);
    return ref
        .watch(mediaUrlProvider(raw))
        .when(
          data: (String url) => _image(context, url),
          loading: () => const _Loading(),
          error: (_, _) => const _Broken(),
        );
  }

  Widget _image(BuildContext context, String url) {
    final Size size = MediaQuery.sizeOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    // Bounded on BOTH sides (aspect ratio kept): sharp enough to zoom, while
    // a 24-megapixel portrait upload can never exhaust the phone's memory
    // (bounding only the width would still decode it at ~86 MB).
    final int bound = (size.longestSide * dpr * 1.25).round().clamp(1080, 3072);
    return Image(
      image: ResizeImage(
        CachedNetworkImageProvider(
          url,
          imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
        ),
        width: bound,
        height: bound,
        policy: ResizeImagePolicy.fit,
      ),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder:
          (
            BuildContext context,
            Widget child,
            int? frame,
            bool wasSynchronouslyLoaded,
          ) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedSwitcher(
              duration: AppDurations.medium,
              child: frame == null ? const _Loading() : child,
            );
          },
      errorBuilder: (_, _, _) => const _Broken(),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Colors.white70));
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56),
  );
}
