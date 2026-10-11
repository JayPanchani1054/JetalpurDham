import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` while the device has any network connection.
///
/// Note: a connection does not guarantee internet access; screens should still
/// handle request failures. This is used for the offline banner and to prefer
/// downloaded files.
final StreamProvider<bool> isOnlineProvider = StreamProvider<bool>((
  Ref ref,
) async* {
  final Connectivity connectivity = Connectivity();
  bool online(List<ConnectivityResult> results) =>
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online).distinct();
});
