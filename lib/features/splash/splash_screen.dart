import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/deep_links.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Opening darshan of Shree Revati Baldevji Harikrushna Maharaj.
///
/// The native splash (same ivory colour + logo) covers engine start-up; this
/// screen then fades the murti in for a calm, devotional first impression and
/// hands over to Home. Pending notification deep links open right after.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String murtiAsset = 'assets/images/murti.jpg';
  static const Duration minimumDisplay = Duration(milliseconds: 2200);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _imageFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<double> _imageScale = Tween<double>(
    begin: 1.08,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 1, curve: Curves.easeOut),
  );
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _controller.forward();
    _timer = Timer(SplashScreen.minimumDisplay, _continue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(SplashScreen.murtiAsset), context);
  }

  void _continue() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(Routes.home);
    DeepLinks.markReady();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.nightSurface,
      body: GestureDetector(
        // A tap skips the remaining wait for returning devotees.
        onTap: () {
          if (_controller.isCompleted) _continue();
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FadeTransition(
              opacity: _imageFade,
              child: ScaleTransition(
                scale: _imageScale,
                child: Semantics(
                  image: true,
                  label: l10n.deityName,
                  child: Image.asset(
                    SplashScreen.murtiAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.imageScrim),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                child: FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        l10n.jaySwaminarayan,
                        textAlign: TextAlign.center,
                        style: text.headlineMedium?.copyWith(
                          color: AppColors.goldLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.deityName,
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.templeName,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(2),
                          ),
                          color: AppColors.goldLight,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
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
