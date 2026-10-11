import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Opens internal locations requested from outside the widget tree (push
/// notification taps). Requests that arrive before the splash screen has
/// finished are held and replayed once the app is ready.
abstract final class DeepLinks {
  static GoRouter? _router;
  static bool _ready = false;
  static String? _pending;

  static void attach(GoRouter router) => _router = router;

  /// Called by the splash screen after it navigates to home.
  static void markReady() {
    _ready = true;
    final String? pending = _pending;
    _pending = null;
    if (pending != null) _router?.go(pending);
  }

  static void open(String? location) {
    if (!Routes.isSafeDeepLink(location)) return;
    final GoRouter? router = _router;
    if (_ready && router != null) {
      router.go(location!);
    } else {
      _pending = location;
    }
  }
}
