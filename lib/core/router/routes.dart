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

  static const List<String> _allowedPrefixes = <String>[
    home,
    kirtan,
    player,
    places,
    library,
    '/reader/',
    events,
  ];

  /// True for internal locations that may be opened from a push notification.
  static bool isSafeDeepLink(String? location) {
    if (location == null || !location.startsWith('/')) return false;
    if (location.startsWith('//')) return false;
    return _allowedPrefixes.any(location.startsWith);
  }
}
