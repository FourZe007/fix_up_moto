import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/tab_container.dart';
import 'package:fix_up_moto/core/widgets/main_shell.dart';

/// A stand-in tab page that counts how many times it has been built, and
/// remembers a tap count, so tests can tell "kept alive" from "rebuilt".
class CountingPage extends StatefulWidget {
  final String name;
  final Map<String, int> builds;

  const CountingPage({super.key, required this.name, required this.builds});

  @override
  State<CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<CountingPage> {
  int taps = 0;

  @override
  void initState() {
    super.initState();
    widget.builds[widget.name] = (widget.builds[widget.name] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('${widget.name} taps: $taps'),
    ),
  );
}

/// The same shell the app uses: five branches in MainTabs order, with Feeds the
/// one tab that is dropped while hidden.
Future<Map<String, int>> pumpShell(WidgetTester tester) async {
  final builds = <String, int>{};

  StatefulShellBranch branch(String name) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/$name',
        builder: (_, _) => CountingPage(name: name, builds: builds),
      ),
    ],
  );

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute(
        builder: (_, _, shell) => MainShell(navigationShell: shell),
        navigatorContainerBuilder: (context, shell, branches) =>
            buildTabContainer(
              context,
              shell,
              branches,
              disposeWhenHidden: const {MainTabs.feeds},
            ),
        branches: [
          branch('home'),
          branch('feeds'),
          branch('membership'),
          branch('bookings'),
          branch('profile'),
        ],
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return builds;
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only the first tab is built at start (tabs load lazily)', (
    tester,
  ) async {
    final builds = await pumpShell(tester);

    expect(builds, {'home': 1});
  });

  testWidgets('a tab you leave is not rebuilt when you come back', (
    tester,
  ) async {
    final builds = await pumpShell(tester);

    await openTab(tester, 'Member');
    await openTab(tester, 'Booking');
    await openTab(tester, 'Beranda');
    await openTab(tester, 'Member');

    // Home and Member were each built once, even though both were left and
    // returned to — that rebuild is what used to refetch.
    expect(builds['home'], 1);
    expect(builds['membership'], 1);
    expect(builds['bookings'], 1);
  });

  testWidgets('a tab keeps its state while hidden', (tester) async {
    await pumpShell(tester);

    await openTab(tester, 'Member');
    await tester.tap(find.text('membership taps: 0'));
    await tester.pump();
    expect(find.text('membership taps: 1'), findsOneWidget);

    await openTab(tester, 'Booking');
    await openTab(tester, 'Member');

    expect(find.text('membership taps: 1'), findsOneWidget);
  });

  testWidgets('Feeds is the exception: it is dropped while hidden', (
    tester,
  ) async {
    final builds = await pumpShell(tester);

    await openTab(tester, 'Feed');
    expect(builds['feeds'], 1);

    await openTab(tester, 'Beranda');
    // Gone from the tree, so its video would stop with it.
    expect(find.text('feeds taps: 0', skipOffstage: false), findsNothing);

    await openTab(tester, 'Feed');
    expect(builds['feeds'], 2);
  });

  testWidgets('back from another tab returns to Home, then leaves the app', (
    tester,
  ) async {
    await pumpShell(tester);

    await openTab(tester, 'Booking');
    expect(find.text('bookings taps: 0'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('home taps: 0'), findsOneWidget);
    expect(find.text('bookings taps: 0'), findsNothing);
  });
}
