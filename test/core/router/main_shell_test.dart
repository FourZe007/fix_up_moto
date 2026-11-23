import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/router/tab_container.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/tour/app_tour.dart';
import 'package:fix_up_moto/core/tour/app_tour_handoff.dart';
import 'package:fix_up_moto/core/tour/app_tour_host.dart';
import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/widgets/ios_floating_tab_bar.dart';
import 'package:fix_up_moto/core/widgets/main_shell.dart';
import '../../support/haptic_recorder.dart';

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
  Widget build(BuildContext context) {
    bottomPadding[widget.name] = MediaQuery.paddingOf(context).bottom;
    return Center(
      child: TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('${widget.name} taps: $taps'),
      ),
    );
  }
}

/// The bottom padding each stand-in page was last built with: what the shell
/// tells a page about the bar below it.
final Map<String, double> bottomPadding = {};

/// The same shell the app uses: five branches in MainTabs order, with Feeds the
/// one tab that is dropped while hidden.
Future<Map<String, int>> pumpShell(
  WidgetTester tester, {
  ThemeData? theme,
  SharedPreferences? prefs,
  AppTourHandoff? Function()? tourHandoff,
  int? Function()? tourBikeCount,
}) async {
  final builds = <String, int>{};
  bottomPadding.clear();

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
        builder: (_, _, shell) => MainShell(
          navigationShell: shell,
          prefs: prefs,
          tourHandoff: tourHandoff,
          tourBikeCount: tourBikeCount,
        ),
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
      // Where the app tour's hand-off lands.
      GoRoute(
        path: RouteNames.addBike,
        builder: (_, _) => const Scaffold(body: Text('add-bike-page')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(theme: theme, routerConfig: router),
  );
  await tester.pumpAndSettle();
  return builds;
}

/// The bar, whichever style the platform gives it: Material's on Android,
/// the floating pill on iOS (see AppTabBar).
final Finder tabBar = find.byWidgetPredicate(
  (widget) => widget is NavigationBar || widget is IosFloatingTabBar,
);

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: tabBar, matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only the first tab is built at start (tabs load lazily)', (
    tester,
  ) async {
    final builds = await pumpShell(tester);

    expect(builds, {'home': 1});
  });

  group('the app tour', () {
    Future<SharedPreferences> prefsWith(Map<String, Object> saved) async {
      SharedPreferences.setMockInitialValues(saved);
      return SharedPreferences.getInstance();
    }

    Future<void> waitForTour(WidgetTester tester) async {
      await tester.pump(AppTourHost.checkEvery * AppTourHost.calmChecksNeeded);
      await tester.pumpAndSettle();
    }

    final card = find.byType(AppTourCard);

    testWidgets('plays once over the real shell for a new member', (
      tester,
    ) async {
      final prefs = await prefsWith({});
      await pumpShell(tester, prefs: prefs);
      expect(card, findsNothing);

      await waitForTour(tester);

      expect(card, findsOneWidget);
      expect(find.text('1 dari 5'), findsOneWidget);
    });

    testWidgets('does not play for a member who has seen it', (tester) async {
      await pumpShell(tester, prefs: await prefsWith({AppTourSeen.key: true}));

      await waitForTour(tester);

      expect(card, findsNothing);
    });

    testWidgets('does not play when the shell is given no preferences', (
      tester,
    ) async {
      await pumpShell(tester);

      await waitForTour(tester);

      expect(card, findsNothing);
    });

    testWidgets('does not play on top of a page that has been opened', (
      tester,
    ) async {
      await pumpShell(tester, prefs: await prefsWith({}));
      // Something takes the screen before the quiet moment is up.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('a pushed page')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('a pushed page'), findsOneWidget);
      expect(card, findsNothing);
    });

    testWidgets('the bar still switches tabs after the tour', (tester) async {
      await pumpShell(tester, prefs: await prefsWith({}));
      await waitForTour(tester);
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      await openTab(tester, 'MyPoint');

      expect(find.text('membership taps: 0'), findsOneWidget);
    });

    testWidgets('plays by itself for a member with no bike', (tester) async {
      await pumpShell(
        tester,
        prefs: await prefsWith({}),
        tourBikeCount: () => 0,
      );

      await waitForTour(tester);

      expect(card, findsOneWidget);
    });

    testWidgets('does not play by itself for a member who has a bike', (
      tester,
    ) async {
      final prefs = await prefsWith({});
      await pumpShell(tester, prefs: prefs, tourBikeCount: () => 2);

      await waitForTour(tester);

      expect(card, findsNothing);
      expect(AppTourSeen.read(prefs), isTrue);
    });

    testWidgets('waits while the shell does not know the count yet', (
      tester,
    ) async {
      await pumpShell(
        tester,
        prefs: await prefsWith({}),
        tourBikeCount: () => null,
      );

      await waitForTour(tester);
      await tester.pump(const Duration(seconds: 10));

      expect(card, findsNothing);
    });

    testWidgets('its last step offers the hand-off the shell was given', (
      tester,
    ) async {
      await pumpShell(
        tester,
        prefs: await prefsWith({}),
        tourHandoff: () => AppTourHandoff.addFirstBike,
      );
      await waitForTour(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('tour-next')));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const Key('tour-accept')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tour-accept')));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(find.text('add-bike-page'), findsOneWidget);
    });

    testWidgets('without a hand-off the last step ends the plain way', (
      tester,
    ) async {
      await pumpShell(tester, prefs: await prefsWith({}));
      await waitForTour(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('tour-next')));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const Key('tour-accept')), findsNothing);
      expect(find.text('Selesai'), findsOneWidget);
    });

    testWidgets('a page in a tab can play it again', (tester) async {
      final prefs = await prefsWith({AppTourSeen.key: true});
      await pumpShell(tester, prefs: prefs);
      expect(card, findsNothing);

      // What Profile's row does: ask the host above the page.
      final scope = AppTourScope.maybeOf(
        tester.element(find.text('home taps: 0')),
      );
      expect(scope, isNotNull);
      expect(scope!.start(), isTrue);
      // The overlay goes in a moment after the call, and the package starts
      // its focus a moment after that: two short pumps, then it settles.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(card, findsOneWidget);
    });

    testWidgets('the bar is drawn the same with the tour wired in', (
      tester,
    ) async {
      await pumpShell(tester, prefs: await prefsWith({AppTourSeen.key: true}));
      final withTour = tester.getRect(find.byType(NavigationBar));

      await pumpShell(tester);
      final without = tester.getRect(find.byType(NavigationBar));

      expect(withTour, without);
    });
  });

  group('haptics', () {
    testWidgets('switching tabs gives a light click on iOS', (tester) async {
      final haptics = HapticRecorder.start();

      await onDevice(TargetPlatform.iOS, () async {
        await pumpShell(tester);
        await openTab(tester, 'MyPoint');

        expect(haptics.taps, [selectionTap]);
      });
    });

    testWidgets('switching tabs gives none on Android', (tester) async {
      final haptics = HapticRecorder.start();

      await pumpShell(tester);
      await openTab(tester, 'MyPoint');

      expect(haptics.taps, isEmpty);
    });
  });

  group('the iOS bar (PREVIEW_PLATFORM=ios on an Android phone)', () {
    final iosTheme = ThemeData(platform: TargetPlatform.iOS);

    testWidgets('switches tabs and keeps them alive, like the Android bar', (
      tester,
    ) async {
      final haptics = HapticRecorder.start();
      final builds = await pumpShell(tester, theme: iosTheme);
      expect(find.byType(IosFloatingTabBar), findsOneWidget);

      await openTab(tester, 'MyPoint');
      expect(find.text('membership taps: 0'), findsOneWidget);
      await openTab(tester, 'Booking');
      await openTab(tester, 'MyPoint');

      expect(builds['membership'], 1);
      // The phone itself is Android, so there is no click.
      expect(haptics.taps, isEmpty);
    });

    testWidgets('back from another tab returns to Home', (tester) async {
      await pumpShell(tester, theme: iosTheme);

      await openTab(tester, 'Booking');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('home taps: 0'), findsOneWidget);
    });
  });

  group('the strip behind the iOS pill matches the showing page', () {
    final strip = find.descendant(
      of: find.byType(IosFloatingTabBar),
      matching: find.byType(ColoredBox),
    );

    // Booking's strip is white in both modes (the colour its list sits on at
    // the bottom of the page), whatever the Scaffold behind it is painted.
    for (final (name, theme, bookingsColor) in [
      (
        'light',
        AppTheme.light.copyWith(platform: TargetPlatform.iOS),
        Colors.white,
      ),
      (
        'dark',
        AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
        Colors.white,
      ),
    ]) {
      testWidgets('$name: every tab gets the colour its page paints', (
        tester,
      ) async {
        await pumpShell(tester, theme: theme);

        // Home and Profile are on the plain theme background, so the strip is
        // left to show it.
        expect(strip, findsNothing);

        // Feed's video runs under the pill, so no strip may cover it.
        await openTab(tester, 'Feed');
        expect(strip, findsNothing);

        await openTab(tester, 'MyPoint');
        expect(tester.widget<ColoredBox>(strip).color, AppColors.primary);

        await openTab(tester, 'Booking');
        expect(tester.widget<ColoredBox>(strip).color, bookingsColor);

        await openTab(tester, 'Saya');
        expect(strip, findsNothing);

        await openTab(tester, 'Beranda');
        expect(strip, findsNothing);
      });
    }
  });

  group('the Feed tab and the bottom bar', () {
    final screenHeight = 600.0; // flutter_test's default 800 x 600 surface

    Rect page(WidgetTester tester, String name) => tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CountingPage && w.name == name,
        skipOffstage: false,
      ),
    );

    group('on the iOS pill', () {
      final iosTheme = ThemeData(platform: TargetPlatform.iOS);

      testWidgets('the Feed runs to the bottom edge, behind the pill', (
        tester,
      ) async {
        await pumpShell(tester, theme: iosTheme);
        await openTab(tester, 'Feed');

        expect(page(tester, 'feeds').bottom, screenHeight);
        // ...and the pill is on top of it, not pushed out.
        expect(
          tester.getRect(find.byType(IosFloatingTabBar)).bottom,
          screenHeight,
        );
      });

      testWidgets('the Feed is told the bar\'s height as bottom padding', (
        tester,
      ) async {
        await pumpShell(tester, theme: iosTheme);
        await openTab(tester, 'Feed');

        // That padding is what keeps its caption and buttons above the pill.
        expect(
          bottomPadding['feeds'],
          tester.getRect(find.byType(IosFloatingTabBar)).height,
        );
        expect(bottomPadding['feeds'], greaterThan(0));
      });

      for (final (label, name) in [
        ('Beranda', 'home'),
        ('MyPoint', 'membership'),
        ('Booking', 'bookings'),
        ('Saya', 'profile'),
      ]) {
        testWidgets('$label still ends where the pill begins', (tester) async {
          await pumpShell(tester, theme: iosTheme);
          await openTab(tester, label);

          expect(
            page(tester, name).bottom,
            tester.getRect(find.byType(IosFloatingTabBar)).top,
          );
          expect(bottomPadding[name], 0);
        });
      }

      testWidgets('leaving the Feed gives the page room back', (tester) async {
        await pumpShell(tester, theme: iosTheme);
        await openTab(tester, 'Feed');
        await openTab(tester, 'Beranda');

        expect(
          page(tester, 'home').bottom,
          tester.getRect(find.byType(IosFloatingTabBar)).top,
        );
      });
    });

    group('on Android', () {
      testWidgets('the Feed still ends where the bar begins', (tester) async {
        await pumpShell(tester);
        await openTab(tester, 'Feed');

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(
          page(tester, 'feeds').bottom,
          tester.getRect(find.byType(NavigationBar)).top,
        );
        expect(bottomPadding['feeds'], 0);
      });
    });
  });

  testWidgets('a tab you leave is not rebuilt when you come back', (
    tester,
  ) async {
    final builds = await pumpShell(tester);

    await openTab(tester, 'MyPoint');
    await openTab(tester, 'Booking');
    await openTab(tester, 'Beranda');
    await openTab(tester, 'MyPoint');

    // Home and Member were each built once, even though both were left and
    // returned to — that rebuild is what used to refetch.
    expect(builds['home'], 1);
    expect(builds['membership'], 1);
    expect(builds['bookings'], 1);
  });

  testWidgets('a tab keeps its state while hidden', (tester) async {
    await pumpShell(tester);

    await openTab(tester, 'MyPoint');
    await tester.tap(find.text('membership taps: 0'));
    await tester.pump();
    expect(find.text('membership taps: 1'), findsOneWidget);

    await openTab(tester, 'Booking');
    await openTab(tester, 'MyPoint');

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
      (Icons.stars_outlined, Icons.stars, 'MyPoint'),
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

      await openTab(tester, 'MyPoint');

      // MyPoint is now filled and brand-coloured...
      expect(find.byIcon(Icons.stars), findsOneWidget);
      expect(find.byIcon(Icons.stars_outlined), findsNothing);
      expect(iconStyle(tester, Icons.stars).color, AppColors.primary);
      expect(labelStyle(tester, 'MyPoint').color, AppColors.primary);
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
