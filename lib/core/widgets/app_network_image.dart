import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../firebase/media_url.dart';
import '../theme/app_spacing.dart';
import 'skeleton.dart';

/// Network image with disk caching, a shimmer placeholder, a graceful error
/// state, and decoding at display size (keeps scrolling smooth and memory low).
///
/// [url] may be an https URL, a `gs://` URL or a Firebase Storage path.
class AppNetworkImage extends ConsumerWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.placeholderIcon = Icons.temple_hindu_outlined,
    this.decodeAtFullResolution = false,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final Alignment alignment;
  final IconData placeholderIcon;

  /// Set for zoomable/full-screen images that must stay sharp.
  final bool decodeAtFullResolution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? raw = url?.trim();
    Widget child = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Works in any layout: fills bounded parents, and falls back to a
        // small fixed box when a parent gives unbounded constraints.
        final bool bounded =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight;
        Widget fill(Widget w) => bounded
            ? SizedBox.expand(child: w)
            : SizedBox(width: width ?? 64, height: height ?? 64, child: w);

        if (raw == null || raw.isEmpty) {
          return fill(_Fallback(icon: placeholderIcon));
        }
        if (MediaUrlResolver.isDirect(raw)) {
          return fill(_image(context, raw, constraints));
        }
        return fill(
          ref
              .watch(mediaUrlProvider(raw))
              .when(
                data: (String resolved) =>
                    _image(context, resolved, constraints),
                loading: () => const _Loading(),
                error: (_, _) => _Fallback(icon: placeholderIcon),
              ),
        );
      },
    );
    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _image(
    BuildContext context,
    String resolved,
    BoxConstraints constraints,
  ) {
    int? cacheWidth;
    if (!decodeAtFullResolution && constraints.hasBoundedWidth) {
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      cacheWidth = (constraints.maxWidth * dpr).round().clamp(64, 2048);
    }
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      alignment: alignment,
      memCacheWidth: cacheWidth,
      fadeInDuration: AppDurations.medium,
      fadeOutDuration: AppDurations.fast,
      placeholder: (_, _) => const _Loading(),
      errorWidget: (_, _, _) => _Fallback(icon: placeholderIcon),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Skeleton(
    child: SkeletonBox(
      height: double.infinity,
      borderRadius: BorderRadius.zero,
    ),
  );
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primaryContainer.withValues(alpha: 0.6),
      child: Center(
        child: Icon(
          icon,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }
}
