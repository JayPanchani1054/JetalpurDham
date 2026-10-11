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
    Widget child;
    if (raw == null || raw.isEmpty) {
      child = _Fallback(icon: placeholderIcon);
    } else if (MediaUrlResolver.isDirect(raw)) {
      child = _image(raw);
    } else {
      child = ref
          .watch(mediaUrlProvider(raw))
          .when(
            data: _image,
            loading: () => const Skeleton(
              child: SkeletonBox(
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),
            error: (_, _) => _Fallback(icon: placeholderIcon),
          );
    }
    child = SizedBox(width: width, height: height, child: child);
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _image(String resolved) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        int? cacheWidth;
        if (!decodeAtFullResolution && constraints.maxWidth.isFinite) {
          final double dpr = MediaQuery.devicePixelRatioOf(context);
          cacheWidth = (constraints.maxWidth * dpr).round().clamp(64, 2048);
        }
        return CachedNetworkImage(
          imageUrl: resolved,
          fit: fit,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: cacheWidth,
          fadeInDuration: AppDurations.medium,
          fadeOutDuration: AppDurations.fast,
          placeholder: (_, _) => const Skeleton(
            child: SkeletonBox(
              height: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
          ),
          errorWidget: (_, _, _) => _Fallback(icon: placeholderIcon),
        );
      },
    );
  }
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
