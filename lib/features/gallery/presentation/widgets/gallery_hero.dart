import 'package:material_ui/material_ui.dart';

/// Flight shuttle for gallery heroes (thumbnail ↔ full photo, album card ↔
/// album header).
///
/// The default shuttle lays the image out at a new size on every animation
/// frame, which makes size-aware images decode again and again. Instead we
/// render the larger hero's image once at its own size and scale it to cover
/// the flight rectangle — smooth, and the crop morphs naturally from the
/// square thumbnail to the full photo.
Widget galleryHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final Size? fromSize = _sizeOf(fromHeroContext);
  final Size? toSize = _sizeOf(toHeroContext);
  final bool useFrom = _area(fromSize) >= _area(toSize);
  final Hero hero = (useFrom ? fromHeroContext : toHeroContext).widget as Hero;
  final Size? size = useFrom ? fromSize : toSize;
  if (size == null || size.isEmpty) return hero.child;
  return ClipRect(
    child: FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox.fromSize(size: size, child: hero.child),
    ),
  );
}

Size? _sizeOf(BuildContext context) {
  final RenderObject? box = context.findRenderObject();
  return box is RenderBox && box.hasSize ? box.size : null;
}

double _area(Size? size) => size == null ? 0 : size.width * size.height;
