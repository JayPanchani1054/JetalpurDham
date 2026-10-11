import 'package:material_ui/material_ui.dart';

/// Brand palette for Shree Jetalpur Dham: kesari (saffron), maroon and gold
/// on a warm ivory canvas.
abstract final class AppColors {
  static const Color saffron = Color(0xFFC2410C);
  static const Color saffronBright = Color(0xFFEA7A1E);
  static const Color maroon = Color(0xFF8C1C13);
  static const Color gold = Color(0xFFA16207);
  static const Color goldLight = Color(0xFFF5C451);
  static const Color ivory = Color(0xFFFFF8F0);
  static const Color nightSurface = Color(0xFF17120E);

  /// Gradient used on hero headers and the splash screen.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFEA7A1E), Color(0xFFC2410C), Color(0xFF8C1C13)],
  );

  /// Scrim placed over photos so white text stays readable.
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x00000000), Color(0x33000000), Color(0xCC000000)],
    stops: <double>[0.35, 0.6, 1],
  );
}
