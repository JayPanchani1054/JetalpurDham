import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/about/about_screen.dart';
import '../../features/donation/presentation/donation_screen.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../features/events/presentation/events_screen.dart';
import '../../features/gallery/presentation/album_screen.dart';
import '../../features/gallery/presentation/gallery_screen.dart';
import '../../features/gallery/presentation/photo_viewer_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/kirtan/presentation/kirtan_downloads_screen.dart';
import '../../features/kirtan/presentation/kirtan_screen.dart';
import '../../features/kirtan/presentation/now_playing_screen.dart';
import '../../features/library/presentation/book_detail_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/library/presentation/pdf_reader_screen.dart';
import '../../features/places/presentation/panorama_screen.dart';
import '../../features/places/presentation/place_detail_screen.dart';
import '../../features/places/presentation/places_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/state_views.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Builds the app router.
///
/// Layout: a [StatefulShellRoute] with five tabs (Home, Kirtan, Prasadi,
/// Shastra, Utsav) that each keep their own navigation stack. Immersive
/// screens (player, PDF reader, photo viewer, 360° view) are pushed on the
/// root navigator so they cover the bottom bar.
GoRouter createRouter({
  String initialLocation = Routes.splash,
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    observers: observers,
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const _NotFoundScreen(),
    routes: <RouteBase>[
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.player,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _slideUpPage(state, const NowPlayingScreen()),
      ),
      GoRoute(
        path: '/reader/:bookId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, GoRouterState state) =>
            PdfReaderScreen(bookId: state.pathParameters['bookId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, StatefulNavigationShell shell) =>
            MainShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const HomeScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'gallery',
                    builder: (_, _) => const GalleryScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: ':albumId',
                        builder: (_, GoRouterState state) => AlbumScreen(
                          albumId: state.pathParameters['albumId']!,
                        ),
                        routes: <RouteBase>[
                          GoRoute(
                            path: 'photo',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (_, GoRouterState state) =>
                                PhotoViewerScreen(
                                  albumId: state.pathParameters['albumId']!,
                                  initialIndex: _intParam(state, 'i'),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'donate',
                    builder: (_, _) => const DonationScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (_, _) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.kirtan,
                builder: (_, _) => const KirtanScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'downloads',
                    builder: (_, _) => const KirtanDownloadsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.places,
                builder: (_, _) => const PlacesScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':placeId',
                    builder: (_, GoRouterState state) => PlaceDetailScreen(
                      placeId: state.pathParameters['placeId']!,
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'panorama',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, GoRouterState state) => PanoramaScreen(
                          placeId: state.pathParameters['placeId']!,
                          initialIndex: _intParam(state, 'i'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.library,
                builder: (_, _) => const LibraryScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':bookId',
                    builder: (_, GoRouterState state) => BookDetailScreen(
                      bookId: state.pathParameters['bookId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.events,
                builder: (_, _) => const EventsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':eventId',
                    builder: (_, GoRouterState state) => EventDetailScreen(
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

int _intParam(GoRouterState state, String name) =>
    int.tryParse(state.uri.queryParameters[name] ?? '') ?? 0;

CustomTransitionPage<void> _slideUpPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<Offset> offset =
              Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ),
              );
          return SlideTransition(position: offset, child: child);
        },
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.explore_off_rounded,
        title: context.l10n.emptyGeneric,
        action: FilledButton(
          onPressed: () => context.go(Routes.home),
          child: Text(context.l10n.navHome),
        ),
      ),
    );
  }
}
