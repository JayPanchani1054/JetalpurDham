import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Three bouncing bars marking the kirtan that is playing. Bars rest when
/// paused (or when the system asks to reduce motion). Only repaints; never
/// rebuilds its parent.
class EqualizerIndicator extends StatefulWidget {
  const EqualizerIndicator({
    super.key,
    required this.playing,
    required this.color,
    this.size = 20,
  });

  final bool playing;
  final Color color;
  final double size;

  @override
  State<EqualizerIndicator> createState() => _EqualizerIndicatorState();
}

class _EqualizerIndicatorState extends State<EqualizerIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EqualizerIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _sync();
  }

  void _sync() {
    final bool animate =
        widget.playing && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _BarsPainter(
          animation: _controller,
          color: widget.color,
          playing: widget.playing,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.animation,
    required this.color,
    required this.playing,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool playing;

  static const List<double> _phases = <double>[0, 0.35, 0.7];
  static const List<double> _rest = <double>[0.45, 0.8, 0.6];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double gap = size.width * 0.14;
    final double barWidth = (size.width - gap * 2) / 3;
    for (int i = 0; i < 3; i++) {
      final double level = playing
          ? 0.3 +
                0.7 *
                    (0.5 +
                        0.5 *
                            math.sin(
                              (animation.value + _phases[i]) * 2 * math.pi,
                            ))
          : _rest[i];
      final double height = size.height * level;
      final double left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.playing != playing;
}
