/// Every navigable location in the app. Use these helpers instead of string
/// literals so links stay valid when routes change.
abstract final class Routes {
  static const String splash = '/splash';

  // Home tab and the screens opened from it (bottom bar stays visible).
  static const String home = '/home';
  static const String gallery = '/home/gallery';
  static String album(String albumId) =>
      '/home/gallery/${Uri.encodeComponent(albumId)}';
  static String photo(String albumId, int index) =>
      '/home/gallery/${Uri.encodeComponent(albumId)}/photo?i=$index';
  static const String donate = '/home/donate';
  static const String about = '/home/about';
  static const String settings = '/home/settings';

  // Kirtan tab.
  static const String kirtan = '/kirtan';
  static const String kirtanDownloads = '/kirtan/downloads';
  static const String player = '/player';

  // Prasadi places tab.
  static const String places = '/places';
  static String place(String placeId) =>
      '/places/${Uri.encodeComponent(placeId)}';
  static String panorama(String placeId, [int index = 0]) =>
      '/places/${Uri.encodeComponent(placeId)}/panorama?i=$index';

  // Shastra library tab.
  static const String library = '/library';
  static String book(String bookId) =>
      '/library/${Uri.encodeComponent(bookId)}';
  static String reader(String bookId) =>
      '/reader/${Uri.encodeComponent(bookId)}';

  // Utsav / events tab.
  static const String events = '/events';
  static String event(String eventId) =>
      '/events/${Uri.encodeComponent(eventId)}';

  /// Locations a push notification may open, with everything below them. A
  /// root ending in '/' only allows what is below it.
  static const List<String> _deepLinkRoots = <String>[
    home,
    kirtan,
    places,
    library,
    '/reader/',
    events,
  ];

  /// Screens that make no sense when a notification opens the app from cold:
  /// the player needs a queue that only the app can build, so its tab opens
  /// instead.
  static const Map<String, String> _deepLinkRedirects = <String, String>{
    player: kirtan,
  };

  /// The internal location a push notification for [location] should open,
  /// or null when [location] must not be opened from outside the app.
  static String? deepLinkTarget(String? location) {
    if (location == null || !location.startsWith('/')) return null;
    if (location.startsWith('//')) return null;
    // go_router opens the parsed location, in which '.' and '..' segments are
    // already resolved ('/home/../player' is '/player'), so the parsed path
    // is what gets checked.
    final String? path = Uri.tryParse(location)?.path;
    if (path == null) return null;
    bool isUnder(String root) => root.endsWith('/')
        ? path.length > root.length && path.startsWith(root)
        : path == root || path.startsWith('$root/');
    for (final MapEntry<String, String> redirect
        in _deepLinkRedirects.entries) {
      if (isUnder(redirect.key)) return redirect.value;
    }
    return _deepLinkRoots.any(isUnder) ? location : null;
  }

  /// True for internal locations that a push notification may open as they
  /// are (see [deepLinkTarget]).
  static bool isSafeDeepLink(String? location) =>
      location != null && deepLinkTarget(location) == location;
}
