import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../application/kirtan_player_controller.dart';
import '../../domain/kirtan.dart';

/// Hero tag shared by the mini player and the Now Playing artwork.
const String kKirtanArtworkHeroTag = 'kirtan-now-playing-artwork';

/// Square kirtan artwork: the cover image when set, otherwise a calm saffron
/// tile with a music note (or the murti image for large artwork).
class KirtanArtwork extends StatelessWidget {
  const KirtanArtwork({
    super.key,
    required this.kirtan,
    this.size,
    this.borderRadius = AppRadius.mdAll,
    this.useMurtiFallback = false,
  });

  final Kirtan kirtan;

  /// Fixed edge length; null fills the parent.
  final double? size;
  final BorderRadius borderRadius;

  /// Shows Shree Harikrushna Maharaj's murti instead of the music tile.
  final bool useMurtiFallback;

  @override
  Widget build(BuildContext context) {
    final String? cover = kirtan.coverUrl;
    final Widget fallback = useMurtiFallback
        ? const _MurtiArtwork()
        : _MusicTile(size: size);
    // A cover that cannot be loaded (offline, deleted file) shows the same
    // calm fallback as a kirtan without one.
    final Widget child = cover != null && cover.isNotEmpty
        ? AppNetworkImage(
            url: cover,
            placeholderIcon: Icons.music_note_rounded,
            fallback: fallback,
          )
        : fallback;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _MusicTile extends StatelessWidget {
  const _MusicTile({this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double edge =
              size ??
              (constraints.biggest.shortestSide.isFinite
                  ? constraints.biggest.shortestSide
                  : 56);
          return Center(
            child: Icon(
              Icons.music_note_rounded,
              color: Colors.white.withValues(alpha: 0.92),
              size: (edge * 0.44).clamp(16.0, 120.0),
            ),
          );
        },
      ),
    );
  }
}

class _MurtiArtwork extends StatelessWidget {
  const _MurtiArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          kKirtanFallbackArtAsset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: 900,
          errorBuilder: (_, _, _) => const _MusicTile(),
        ),
        // Warm saffron glow at the bottom, like an aarti lamp.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x00000000), Color(0x66C2410C)],
              stops: <double>[0.55, 1],
            ),
          ),
        ),
      ],
    );
  }
}
