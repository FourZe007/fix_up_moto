import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/tab_container.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
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
Future<Map<String, int>> pumpShell(
  WidgetTester tester, {
  ThemeData? theme,
}) async {
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

  await tester.pumpWidget(
    MaterialApp.router(theme: theme, routerConfig: router),
  );
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

    await openTab(tester, 'My Point');
    await openTab(tester, 'Booking');
    await openTab(tester, 'Beranda');
    await openTab(tester, 'My Point');

    // Home and Member were each built once, even though both were left and
    // returned to — that rebuild is what used to refetch.
    expect(builds['home'], 1);
    expect(builds['membership'], 1);
    expect(builds['bookings'], 1);
  });

  testWidgets('a tab keeps its state while hidden', (tester) async {
    await pumpShell(tester);

    await openTab(tester, 'My Point');
    await tester.tap(find.text('membership taps: 0'));
    await tester.pump();
    expect(find.text('membership taps: 1'), findsOneWidget);

    await openTab(tester, 'Booking');
    await openTab(tester, 'My Point');

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

  group('the selected tab\'s style', () {
    // The five tabs, in bar order: (outlined icon, filled icon, label).
    const tabs = [
      (Icons.home_outlined, Icons.home, 'Beranda'),
      (Icons.play_circle_outline, Icons.play_circle, 'Feed'),
      (Icons.stars_outlined, Icons.stars, 'My Point'),
      (Icons.calendar_month_outlined, Icons.calendar_month, 'Booking'),
      (Icons.person_outline, Icons.person, 'Saya'),
    ];

    /// The colour and size an [Icon] actually paints with.
    IconThemeData iconStyle(WidgetTester tester, IconData icon) =>
        IconTheme.of(tester.element(find.byIcon(icon)));

    /// The style the bar gives the label [text].
    TextStyle labelStyle(WidgetTester tester, String text) => tester
        .widget<Text>(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(text),
          ),
        )
        .style!;

    /// The same five tabs in a plain [NavigationBar] with nothing restyled —
    /// what the idle tabs must still look like.
    Future<void> pumpUnthemedBar(WidgetTester tester, ThemeData theme) =>
        tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              bottomNavigationBar: NavigationBar(
                selectedIndex: 0,
                destinations: [
                  for (final (outlined, filled, label) in tabs)
                    NavigationDestination(
                      icon: Icon(outlined),
                      selectedIcon: Icon(filled),
                      label: label,
                    ),
                ],
              ),
            ),
          ),
        );

    group('with the app\'s real themes', () {
      for (final (name, theme) in [
        ('light', AppTheme.light),
        ('dark', AppTheme.dark),
      ]) {
        testWidgets('$name: the selected tab shows its filled icon', (
          tester,
        ) async {
          await pumpShell(tester, theme: theme);

          expect(find.byIcon(Icons.home), findsOneWidget);
          expect(find.byIcon(Icons.home_outlined), findsNothing);
          // The other four are still the outlined ones.
          for (final (outlined, filled, _) in tabs.skip(1)) {
            expect(find.byIcon(outlined), findsOneWidget);
            expect(find.byIcon(filled), findsNothing);
          }
        });

        testWidgets('$name: its icon and label are the brand colour', (
          tester,
        ) async {
          await pumpShell(tester, theme: theme);

          expect(iconStyle(tester, Icons.home).color, AppColors.primary);
          expect(labelStyle(tester, 'Beranda').color, AppColors.primary);
        });

        testWidgets('$name: no pill is drawn behind it', (tester) async {
          await pumpShell(tester, theme: theme);

          final indicators = tester.widgetList<NavigationIndicator>(
            find.byType(NavigationIndicator),
          );
          expect(indicators, isNotEmpty);
          for (final indicator in indicators) {
            expect(indicator.color, Colors.transparent);
          }
        });

        testWidgets('$name: the idle tabs look exactly as they did', (
          tester,
        ) async {
          await pumpUnthemedBar(tester, theme);
          final before = {
            for (final (outlined, _, label) in tabs.skip(1))
              label: (iconStyle(tester, outlined), labelStyle(tester, label)),
          };

          await pumpShell(tester, theme: theme);

          for (final (outlined, _, label) in tabs.skip(1)) {
            final (iconBefore, labelBefore) = before[label]!;
            final icon = iconStyle(tester, outlined);
            expect(icon.color, iconBefore.color, reason: '$label icon colour');
            expect(icon.size, iconBefore.size, reason: '$label icon size');
            expect(labelStyle(tester, label), labelBefore, reason: label);
            // ...and that is not the brand colour, so it is a real contrast.
            expect(icon.color, isNot(AppColors.primary));
          }
        });
      }

      testWidgets('without the change the pill would be drawn (sanity check)', (
        tester,
      ) async {
        // Proves the "no pill" test above can fail: a plain bar does draw one.
        await pumpUnthemedBar(tester, AppTheme.light);

        final indicator = tester.widget<NavigationIndicator>(
          find.byType(NavigationIndicator).first,
        );
        expect(indicator.color, isNot(Colors.transparent));
      });
    });

    testWidgets('selecting a tab moves the style to it', (tester) async {
      await pumpShell(tester, theme: AppTheme.light);

      await openTab(tester, 'My Point');

      // My Point is now filled and brand-coloured...
      expect(find.byIcon(Icons.stars), findsOneWidget);
      expect(find.byIcon(Icons.stars_outlined), findsNothing);
      expect(iconStyle(tester, Icons.stars).color, AppColors.primary);
      expect(labelStyle(tester, 'My Point').color, AppColors.primary);
      // ...and Beranda, left behind, is outlined and no longer brand-coloured.
      expect(find.byIcon(Icons.home), findsNothing);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(
        iconStyle(tester, Icons.home_outlined).color,
        isNot(AppColors.primary),
      );
      expect(labelStyle(tester, 'Beranda').color, isNot(AppColors.primary));
    });

    testWidgets('the label keeps its size and spacing when selected', (
      tester,
    ) async {
      await pumpShell(tester, theme: AppTheme.light);

      // Beranda is selected, Feed is idle: only the colour may differ.
      final selected = labelStyle(tester, 'Beranda');
      final idle = labelStyle(tester, 'Feed');
      expect(selected.fontSize, idle.fontSize);
      expect(selected.fontFamily, idle.fontFamily);
      expect(selected.fontWeight, idle.fontWeight);
      expect(selected.letterSpacing, idle.letterSpacing);
      expect(selected.height, idle.height);
    });

    testWidgets('the icon keeps its size when selected', (tester) async {
      await pumpShell(tester, theme: AppTheme.light);

      expect(
        iconStyle(tester, Icons.home).size,
        iconStyle(tester, Icons.play_circle_outline).size,
      );
    });
  });
}
