import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jetalpur_dham/core/router/routes.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_player_controller.dart';
import 'package:jetalpur_dham/features/kirtan/application/kirtan_player_state.dart';
import 'package:jetalpur_dham/features/kirtan/domain/kirtan.dart';
import 'package:jetalpur_dham/features/kirtan/presentation/widgets/kirtan_actions.dart';
import 'package:material_ui/material_ui.dart';

/// Row taps: what reaches the player and how often Now Playing opens.

final List<Kirtan> _kirtans = <Kirtan>[
  for (final String id in <String>['a', 'b', 'c'])
    Kirtan.fromMap(id, <String, Object?>{
      'title': 'Kirtan $id',
      'audioUrl': 'https://example.com/$id.mp3',
    }),
];

class _RecordingPlayer extends KirtanPlayerController {
  _RecordingPlayer(this._initial);

  final KirtanQueue _initial;
  final List<String> calls = <String>[];

  @override
  KirtanQueue build() => _initial;

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> togglePlayPause() async => calls.add('toggle');

  @override
  Future<void> playKirtans(List<Kirtan> kirtans, {int startIndex = 0}) async =>
      calls.add('play ${kirtans[startIndex].id}');
}

class _PushCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

class _Rows extends ConsumerWidget {
  const _Rows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ListView(
        children: <Widget>[
          for (int i = 0; i < _kirtans.length; i++)
            ListTile(
              title: Text(_kirtans[i].id),
              onTap: () => playKirtanFromList(context, ref, _kirtans, i),
            ),
        ],
      ),
    );
  }
}

Future<(_RecordingPlayer, _PushCounter, GoRouter)> _pump(
  WidgetTester tester,
  KirtanQueue queue,
) async {
  final _PushCounter counter = _PushCounter();
  final GoRouter router = GoRouter(
    initialLocation: Routes.kirtan,
    observers: <NavigatorObserver>[counter],
    routes: <RouteBase>[
      GoRoute(path: Routes.kirtan, builder: (_, _) => const _Rows()),
      GoRoute(
        path: Routes.player,
        builder: (_, _) => const Scaffold(body: Text('player page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      kirtanPlayerProvider.overrideWith(() => _RecordingPlayer(queue)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  final _RecordingPlayer player =
      container.read(kirtanPlayerProvider.notifier) as _RecordingPlayer;
  return (player, counter, router);
}

void main() {
  testWidgets(
    'double tap on a kirtan that is still loading never cancels it and '
    'opens Now Playing once',
    (WidgetTester tester) async {
      final (
        _RecordingPlayer player,
        _PushCounter counter,
        GoRouter router,
      ) = await _pump(
        tester,
        KirtanQueue(items: _kirtans, index: 0, isPreparing: true),
      );
      final int initialPushes = counter.pushes;

      await tester.tap(find.text('a'));
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      expect(player.calls, <String>['resume', 'resume']);
      expect(find.text('player page'), findsOneWidget);
      expect(counter.pushes - initialPushes, 1);

      // Later taps while Now Playing is already open do nothing either.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 900)),
      );
      openKirtanPlayer(tester.element(find.text('a', skipOffstage: false)));
      await tester.pumpAndSettle();
      expect(counter.pushes - initialPushes, 1);
      expect(router.state.uri.path, Routes.player);
    },
  );

  testWidgets('tapping another kirtan plays the list from that row', (
    WidgetTester tester,
  ) async {
    final (_RecordingPlayer player, _PushCounter counter, GoRouter _) =
        await _pump(tester, KirtanQueue(items: _kirtans, index: 0));
    final int initialPushes = counter.pushes;

    await tester.tap(find.text('c'));
    await tester.pumpAndSettle();

    expect(player.calls, <String>['play c']);
    expect(counter.pushes, initialPushes);
    expect(find.text('player page'), findsNothing);
  });
}
