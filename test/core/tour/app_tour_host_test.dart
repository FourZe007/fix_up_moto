import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/tour/app_tour.dart';
import 'package:fix_up_moto/core/tour/app_tour_handoff.dart';
import 'package:fix_up_moto/core/tour/app_tour_host.dart';
import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/tour/app_tour_steps.dart';
import 'package:fix_up_moto/core/widgets/app_tab_bar.dart';
import 'package:fix_up_moto/core/widgets/ios_floating_tab_bar.dart';

/// What a test needs to look at after [pumpHost].
class Harness {
  /// The tabs the bar reported as tapped: anything in here means the tour let a
  /// tap through to the page behind it.
  final List<int> taps;

  /// The keys the host gave the bar.
  final List<GlobalKey> tabKeys;

  /// The host's own "play the tour" call, as a page below it would reach it.
  final bool Function() start;

  const Harness(this.taps, this.tabKeys, this.start);
}

Future<SharedPreferences> prefsWith(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  return SharedPreferences.getInstance();
}

/// A host over a bare scaffold with the real [AppTabBar], like the shell's. The
/// body has a button that opens a dialog, to stand in for anything that takes
/// the screen (the notification explainer is one).
Future<Harness> pumpHost(
  WidgetTester tester, {
  SharedPreferences? prefs,
  TargetPlatform platform = TargetPlatform.android,
  AppTourHandoff? Function()? handoff,
  int? Function()? bikeCount,
}) async {
  final taps = <int>[];
  late List<GlobalKey> keys;
  late bool Function() start;

  // A real router, because accepting the hand-off pushes a route.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => AppTourHost(
          prefs: prefs,
          handoff: handoff,
          bikeCount: bikeCount,
          builder: (context, tabKeys) {
            keys = tabKeys;
            return Scaffold(
              body: Builder(
                builder: (context) {
                  start = AppTourScope.maybeOf(context)!.start;
                  return Column(
                    children: [
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Dialog lain'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Tutup dialog'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('Buka dialog'),
                      ),
                      TextButton(
                        onPressed: () => start(),
                        child: const Text('Putar ulang'),
                      ),
                    ],
                  );
                },
              ),
              bottomNavigationBar: AppTabBar(
                selectedIndex: 0,
                onSelected: taps.add,
                tabKeys: tabKeys,
              ),
            );
          },
        ),
      ),
      // Stands in for Add Bike, where accepting the hand-off lands.
      GoRoute(
        path: RouteNames.addBike,
        builder: (_, state) {
          addBikeExtra = state.extra;
          return const Scaffold(body: Text('add-bike-page'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      theme: ThemeData(platform: platform),
      routerConfig: router,
    ),
  );
  return Harness(taps, keys, () => start());
}

/// Lets the host's checks run for as long as an automatic start needs, then the
/// tour's own animation finish.
Future<void> waitForAutoStart(WidgetTester tester) async {
  await tester.pump(AppTourHost.checkEvery * AppTourHost.calmChecksNeeded);
  await tester.pumpAndSettle();
}

/// What the stand-in Add Bike route was last opened with as its `extra`.
Object? addBikeExtra;

final card = find.byType(AppTourCard);
final next = find.byKey(const Key('tour-next'));
final back = find.byKey(const Key('tour-back'));
final skip = find.text('Lewati');
final accept = find.byKey(const Key('tour-accept'));
final decline = find.byKey(const Key('tour-decline'));

/// The tab bar's tab for [label], not the tour card's title of the same name.
Finder tabLabelled(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is NavigationBar || w is IosFloatingTabBar,
  ),
  matching: find.text(label),
);

Future<void> pressNext(WidgetTester tester) async {
  await tester.tap(next);
  await tester.pumpAndSettle();
}

void main() {
  group('playing by itself', () {
    testWidgets('a member who has not seen it gets it after a quiet moment', (
      tester,
    ) async {
      await pumpHost(tester, prefs: await prefsWith({}));
      expect(card, findsNothing);

      await waitForAutoStart(tester);

      expect(card, findsOneWidget);
      expect(find.text('1 dari 5'), findsOneWidget);
      expect(find.text(AppTourSteps.all.first.message), findsOneWidget);
    });

    testWidgets('not at once: the first checks find it too soon', (
      tester,
    ) async {
      await pumpHost(tester, prefs: await prefsWith({}));

      await tester.pump(AppTourHost.checkEvery * 2);
      await tester.pumpAndSettle();
      expect(card, findsNothing);

      await tester.pump(AppTourHost.checkEvery);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
    });

    testWidgets('a member who has seen it never gets it again', (tester) async {
      await pumpHost(tester, prefs: await prefsWith({AppTourSeen.key: true}));

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });

    testWidgets('without preferences it does not start on its own', (
      tester,
    ) async {
      await pumpHost(tester);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });

    testWidgets('it plays once, not again at every check', (tester) async {
      await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsOneWidget);
      expect(find.text('1 dari 5'), findsOneWidget);
    });

    testWidgets('it waits while a dialog is on top, then plays', (
      tester,
    ) async {
      await pumpHost(tester, prefs: await prefsWith({}));
      await tester.tap(find.text('Buka dialog'));
      await tester.pumpAndSettle();

      // Plenty of time, but the dialog is the screen on top.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(find.text('Dialog lain'), findsOneWidget);

      await tester.tap(find.text('Tutup dialog'));
      await tester.pumpAndSettle();
      expect(card, findsNothing, reason: 'the count starts over');

      await waitForAutoStart(tester);
      expect(card, findsOneWidget);
    });

    testWidgets('it waits while the app is out of the foreground', (
      tester,
    ) async {
      await pumpHost(tester, prefs: await prefsWith({}));

      // What the phone's own permission prompt does to the app.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(card, findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await waitForAutoStart(tester);
      expect(card, findsOneWidget);
    });

    testWidgets('a busy moment in between restarts the quiet count', (
      tester,
    ) async {
      await pumpHost(tester, prefs: await prefsWith({}));

      // Two quiet checks...
      await tester.pump(AppTourHost.checkEvery * 2);
      // ...then the app is pulled away for one check...
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(AppTourHost.checkEvery);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // ...so two quiet checks are no longer enough.
      await tester.pump(AppTourHost.checkEvery * 2);
      await tester.pumpAndSettle();
      expect(card, findsNothing);

      await tester.pump(AppTourHost.checkEvery);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
    });
  });

  group('walking through it', () {
    testWidgets('each step names its tab and counts up to five', (
      tester,
    ) async {
      await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);

      for (var i = 0; i < AppTourSteps.all.length; i++) {
        final step = AppTourSteps.all[i];
        expect(find.text('${i + 1} dari 5'), findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.text(step.title)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text(step.message)),
          findsOneWidget,
        );
        if (i < AppTourSteps.all.length - 1) await pressNext(tester);
      }
    });

    testWidgets('the last step says Selesai, the others Lanjut', (
      tester,
    ) async {
      await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);

      for (var i = 0; i < 4; i++) {
        expect(
          find.descendant(of: next, matching: find.text('Lanjut')),
          findsOne,
        );
        await pressNext(tester);
      }

      expect(
        find.descendant(of: next, matching: find.text('Selesai')),
        findsOne,
      );
    });

    testWidgets(
      'there is no Kembali on the first step, and it goes back after',
      (tester) async {
        await pumpHost(tester, prefs: await prefsWith({}));
        await waitForAutoStart(tester);
        expect(back, findsNothing);

        await pressNext(tester);
        expect(find.text('2 dari 5'), findsOneWidget);
        expect(back, findsOneWidget);

        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.text('1 dari 5'), findsOneWidget);
      },
    );

    testWidgets('Lewati is on every step but the last', (tester) async {
      await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);

      for (var i = 0; i < 4; i++) {
        expect(skip, findsOneWidget, reason: 'step ${i + 1}');
        await pressNext(tester);
      }

      expect(skip, findsNothing, reason: 'the last step has Selesai instead');
    });

    testWidgets('Selesai ends the tour and marks it seen', (tester) async {
      final prefs = await prefsWith({});
      await pumpHost(tester, prefs: prefs);
      await waitForAutoStart(tester);
      for (var i = 0; i < 4; i++) {
        await pressNext(tester);
      }
      expect(AppTourSeen.read(prefs), isFalse, reason: 'not before the end');

      await pressNext(tester);

      expect(card, findsNothing);
      expect(AppTourSeen.read(prefs), isTrue);
    });

    testWidgets('Lewati ends it at once and marks it seen', (tester) async {
      final prefs = await prefsWith({});
      await pumpHost(tester, prefs: prefs);
      await waitForAutoStart(tester);
      await pressNext(tester);

      await tester.tap(skip);
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(AppTourSeen.read(prefs), isTrue);
    });

    testWidgets('merely opening it does not mark it seen', (tester) async {
      final prefs = await prefsWith({});
      await pumpHost(tester, prefs: prefs);

      await waitForAutoStart(tester);

      expect(card, findsOneWidget);
      // So a member who closes the app halfway gets it again.
      expect(AppTourSeen.read(prefs), isFalse);
    });

    testWidgets('once it has ended it does not come back', (tester) async {
      await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);
      await tester.tap(skip);
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });
  });

  group('the tour does not let a tap through to the page', () {
    testWidgets('tapping the lit tab goes to the next step, not to that tab', (
      tester,
    ) async {
      final harness = await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);

      await tester.tap(tabLabelled('Beranda'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('2 dari 5'), findsOneWidget);
      expect(harness.taps, isEmpty);
    });

    testWidgets('the lit tab is the step\'s own: Feed on the second step', (
      tester,
    ) async {
      final harness = await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);
      await pressNext(tester);

      // Another tab is dark: tapping it does nothing, and never reaches the bar.
      await tester.tap(tabLabelled('Saya'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('2 dari 5'), findsOneWidget);

      await tester.tap(tabLabelled('Feed'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('3 dari 5'), findsOneWidget);
      expect(harness.taps, isEmpty);
    });

    testWidgets('tapping the dark area does nothing', (tester) async {
      final harness = await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);

      await tester.tapAt(const Offset(40, 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka dialog'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('1 dari 5'), findsOneWidget);
      expect(find.text('Dialog lain'), findsNothing);
      expect(harness.taps, isEmpty);
    });

    testWidgets('once it is over the bar takes taps again', (tester) async {
      final harness = await pumpHost(tester, prefs: await prefsWith({}));
      await waitForAutoStart(tester);
      await tester.tap(skip);
      await tester.pumpAndSettle();

      await tester.tap(tabLabelled('MyPoint'));

      expect(harness.taps, [2]);
    });
  });

  group('playing it again', () {
    testWidgets('works for a member who has already seen it', (tester) async {
      await pumpHost(tester, prefs: await prefsWith({AppTourSeen.key: true}));

      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();

      expect(find.text('1 dari 5'), findsOneWidget);
    });

    testWidgets('works with no preferences too', (tester) async {
      await pumpHost(tester);

      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();

      expect(find.text('1 dari 5'), findsOneWidget);
    });

    testWidgets('leaves it marked seen once it ends', (tester) async {
      final prefs = await prefsWith({AppTourSeen.key: true});
      await pumpHost(tester, prefs: prefs);
      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();

      await tester.tap(skip);
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(AppTourSeen.read(prefs), isTrue);
    });

    testWidgets('can be played a second time after it ends', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();
      await tester.tap(skip);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();

      expect(find.text('1 dari 5'), findsOneWidget);
    });

    testWidgets('start says whether it started, and not twice at once', (
      tester,
    ) async {
      final harness = await pumpHost(tester);

      expect(harness.start(), isTrue);
      expect(harness.start(), isFalse);
      // The overlay goes in a moment after the call, and the package starts
      // its focus a moment after that: two short pumps, then it settles.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(card, findsOneWidget, reason: 'one tour, not two on top');
    });

    testWidgets('a replay stops a waiting automatic start from doubling it', (
      tester,
    ) async {
      await pumpHost(tester, prefs: await prefsWith({}));

      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsOneWidget);
      expect(find.text('1 dari 5'), findsOneWidget);
    });
  });

  group('the tabs it lights up', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('${platform.name}: every tab carries its key', (
        tester,
      ) async {
        final harness = await pumpHost(tester, platform: platform);

        expect(harness.tabKeys, hasLength(5));
        for (final (i, key) in harness.tabKeys.indexed) {
          expect(key.currentContext, isNotNull, reason: 'tab $i');
        }
      });

      testWidgets('${platform.name}: each key is on its own tab, in order', (
        tester,
      ) async {
        final harness = await pumpHost(tester, platform: platform);

        final centres = [
          for (final key in harness.tabKeys)
            (key.currentContext!.findRenderObject() as RenderBox)
                .localToGlobal(Offset.zero)
                .dx,
        ];

        // Left to right, none on top of another.
        for (var i = 1; i < centres.length; i++) {
          expect(centres[i], greaterThan(centres[i - 1]));
        }
        // And each one holds the label it is meant for.
        for (final step in AppTourSteps.all) {
          expect(
            find.descendant(
              of: find.byKey(harness.tabKeys[step.tab]),
              matching: find.text(step.title),
            ),
            findsOneWidget,
            reason: step.title,
          );
        }
      });

      testWidgets('${platform.name}: the tour plays over it', (tester) async {
        await pumpHost(tester, prefs: await prefsWith({}), platform: platform);
        await waitForAutoStart(tester);

        expect(card, findsOneWidget);

        // Right through to the end without a tab going missing.
        for (var i = 0; i < 4; i++) {
          await pressNext(tester);
        }
        expect(find.text('5 dari 5'), findsOneWidget);
      });
    }
  });

  group('only for new members', () {
    testWidgets('a member with no bike gets it', (tester) async {
      await pumpHost(tester, prefs: await prefsWith({}), bikeCount: () => 0);

      await waitForAutoStart(tester);

      expect(card, findsOneWidget);
    });

    testWidgets('a member with a bike never gets it unasked', (tester) async {
      await pumpHost(tester, prefs: await prefsWith({}), bikeCount: () => 3);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });

    testWidgets('and is marked as having seen it, so it stays gone', (
      tester,
    ) async {
      final prefs = await prefsWith({});
      await pumpHost(tester, prefs: prefs, bikeCount: () => 1);
      expect(AppTourSeen.read(prefs), isFalse);

      await tester.pump(AppTourHost.checkEvery);

      expect(AppTourSeen.read(prefs), isTrue);
    });

    testWidgets('deleting their last bike later does not bring it back', (
      tester,
    ) async {
      var bikes = 2;
      await pumpHost(
        tester,
        prefs: await prefsWith({}),
        bikeCount: () => bikes,
      );
      await tester.pump(AppTourHost.checkEvery);

      bikes = 0;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });

    testWidgets('while the count is unknown it waits, and does not guess', (
      tester,
    ) async {
      final prefs = await prefsWith({});
      await pumpHost(tester, prefs: prefs, bikeCount: () => null);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      // Not marked either: nothing has been decided about this member yet.
      expect(AppTourSeen.read(prefs), isFalse);
    });

    testWidgets('once the count is known to be none, it plays', (tester) async {
      int? bikes;
      await pumpHost(
        tester,
        prefs: await prefsWith({}),
        bikeCount: () => bikes,
      );
      await tester.pump(const Duration(seconds: 5));

      bikes = 0;
      await waitForAutoStart(tester);

      expect(card, findsOneWidget);
    });

    testWidgets('the quiet it needs starts counting only once it is known', (
      tester,
    ) async {
      int? bikes;
      await pumpHost(
        tester,
        prefs: await prefsWith({}),
        bikeCount: () => bikes,
      );
      await tester.pump(const Duration(seconds: 5));

      bikes = 0;
      // Two quiet checks since it became known are not enough...
      await tester.pump(AppTourHost.checkEvery * 2);
      await tester.pumpAndSettle();
      expect(card, findsNothing);

      // ...the third is.
      await tester.pump(AppTourHost.checkEvery);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
    });

    testWidgets('once the count is known to be some, it never plays', (
      tester,
    ) async {
      final prefs = await prefsWith({});
      int? bikes;
      await pumpHost(tester, prefs: prefs, bikeCount: () => bikes);
      await tester.pump(const Duration(seconds: 5));

      bikes = 2;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(AppTourSeen.read(prefs), isTrue);
    });

    testWidgets('a bike added while it was still waiting cancels it', (
      tester,
    ) async {
      var bikes = 0;
      await pumpHost(
        tester,
        prefs: await prefsWith({}),
        bikeCount: () => bikes,
      );

      // Two quiet checks, then the member saves their first bike.
      await tester.pump(AppTourHost.checkEvery * 2);
      bikes = 1;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });

    testWidgets('a member who has seen it is not even counted', (tester) async {
      var asked = 0;
      await pumpHost(
        tester,
        prefs: await prefsWith({AppTourSeen.key: true}),
        bikeCount: () {
          asked++;
          return 0;
        },
      );

      await tester.pump(const Duration(seconds: 10));

      expect(asked, 0);
      expect(card, findsNothing);
    });

    testWidgets(
      'without a count to go by, anyone who has not seen it gets it',
      (tester) async {
        await pumpHost(tester, prefs: await prefsWith({}));

        await waitForAutoStart(tester);

        expect(card, findsOneWidget);
      },
    );

    testWidgets(
      'with no preferences a member with a bike is simply left alone',
      (tester) async {
        await pumpHost(tester, bikeCount: () => 2);

        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();

        expect(card, findsNothing);
      },
    );

    testWidgets('a member with bikes can still play it from Profile', (
      tester,
    ) async {
      final prefs = await prefsWith({});
      await pumpHost(tester, prefs: prefs, bikeCount: () => 4);
      await tester.pump(AppTourHost.checkEvery);

      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();

      expect(find.text('1 dari 5'), findsOneWidget);
    });

    testWidgets('a replay on screen is left alone by the checks', (
      tester,
    ) async {
      var bikes = 0;
      await pumpHost(
        tester,
        prefs: await prefsWith({}),
        bikeCount: () => bikes,
      );

      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();
      bikes = 3;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Still playing: the member is not cut off because the count changed.
      expect(find.text('1 dari 5'), findsOneWidget);
    });
  });

  group('handing the member on to their first task', () {
    /// A host that offers adding a bike, and the tour walked to its last step.
    Future<SharedPreferences> toLastStep(
      WidgetTester tester, {
      AppTourHandoff? Function()? handoff,
      bool seen = false,
    }) async {
      final prefs = await prefsWith({if (seen) AppTourSeen.key: true});
      await pumpHost(
        tester,
        prefs: prefs,
        handoff: handoff ?? () => AppTourHandoff.addFirstBike,
      );
      if (seen) {
        await tester.tap(find.text('Putar ulang'));
        await tester.pumpAndSettle();
      } else {
        await waitForAutoStart(tester);
      }
      for (var i = 0; i < 4; i++) {
        await pressNext(tester);
      }
      return prefs;
    }

    testWidgets('the last step offers it instead of Selesai', (tester) async {
      await toLastStep(tester);

      expect(find.text('5 dari 5'), findsOneWidget);
      expect(find.text(AppTourHandoff.addFirstBike.message), findsOneWidget);
      expect(
        find.descendant(
          of: accept,
          matching: find.text(AppTourHandoff.addFirstBike.acceptLabel),
        ),
        findsOneWidget,
      );
      expect(decline, findsOneWidget);
      // The plain ending is not there beside it.
      expect(next, findsNothing);
      expect(find.text('Selesai'), findsNothing);
    });

    testWidgets('only the last step: the earlier ones are unchanged', (
      tester,
    ) async {
      final prefs = await prefsWith({});
      await pumpHost(
        tester,
        prefs: prefs,
        handoff: () => AppTourHandoff.addFirstBike,
      );
      await waitForAutoStart(tester);

      for (var i = 0; i < 4; i++) {
        expect(accept, findsNothing, reason: 'step ${i + 1}');
        expect(
          find.descendant(of: next, matching: find.text('Lanjut')),
          findsOneWidget,
          reason: 'step ${i + 1}',
        );
        await pressNext(tester);
      }
    });

    testWidgets('Kembali is still there on the last step, and works', (
      tester,
    ) async {
      await toLastStep(tester);

      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(find.text('4 dari 5'), findsOneWidget);
      expect(accept, findsNothing);
    });

    testWidgets('accepting closes the tour and opens Add Bike', (tester) async {
      await toLastStep(tester);

      await tester.tap(accept);
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(find.text('add-bike-page'), findsOneWidget);
    });

    testWidgets("and opens it as the guidance's bike step", (tester) async {
      addBikeExtra = null;
      await toLastStep(tester);

      await tester.tap(accept);
      await tester.pumpAndSettle();

      // So that once the bike is saved, the member is offered a booking.
      expect(addBikeExtra, FirstTaskStep.addBike);
    });

    testWidgets('accepting also marks the tour seen', (tester) async {
      final prefs = await toLastStep(tester);
      expect(AppTourSeen.read(prefs), isFalse);

      await tester.tap(accept);
      await tester.pumpAndSettle();

      expect(AppTourSeen.read(prefs), isTrue);
    });

    testWidgets('back from Add Bike returns to the page, and no tour again', (
      tester,
    ) async {
      await toLastStep(tester);
      await tester.tap(accept);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('add-bike-page'), findsNothing);
      expect(find.text('Putar ulang'), findsOneWidget);
      expect(card, findsNothing);
    });

    testWidgets('Nanti saja closes it, opens nothing, and marks it seen', (
      tester,
    ) async {
      final prefs = await toLastStep(tester);

      await tester.tap(decline);
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(find.text('add-bike-page'), findsNothing);
      expect(find.text('Putar ulang'), findsOneWidget);
      expect(AppTourSeen.read(prefs), isTrue);
    });

    testWidgets('Lewati before the last step opens nothing either', (
      tester,
    ) async {
      await pumpHost(
        tester,
        prefs: await prefsWith({}),
        handoff: () => AppTourHandoff.addFirstBike,
      );
      await waitForAutoStart(tester);
      await pressNext(tester);

      await tester.tap(skip);
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(find.text('add-bike-page'), findsNothing);
    });

    testWidgets('a replay from a member who has seen the tour offers it too', (
      tester,
    ) async {
      await toLastStep(tester, seen: true);

      expect(accept, findsOneWidget);
    });

    testWidgets('an answer of null means the plain Selesai ending', (
      tester,
    ) async {
      await toLastStep(tester, handoff: () => null);

      expect(accept, findsNothing);
      expect(decline, findsNothing);
      expect(
        find.descendant(of: next, matching: find.text('Selesai')),
        findsOneWidget,
      );
    });

    testWidgets('Selesai without an offer still opens nothing', (tester) async {
      await toLastStep(tester, handoff: () => null);

      await pressNext(tester);

      expect(card, findsNothing);
      expect(find.text('add-bike-page'), findsNothing);
    });

    testWidgets('it is asked again at each start, not once and kept', (
      tester,
    ) async {
      var hasBike = false;
      await pumpHost(
        tester,
        handoff: () => hasBike ? null : AppTourHandoff.addFirstBike,
      );

      // First replay: no bike yet, so it is offered.
      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await pressNext(tester);
      }
      expect(accept, findsOneWidget);
      await tester.tap(decline);
      await tester.pumpAndSettle();

      // The member has a bike by the second: nothing to offer.
      hasBike = true;
      await tester.tap(find.text('Putar ulang'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await pressNext(tester);
      }
      expect(accept, findsNothing);
      expect(find.text('Selesai'), findsOneWidget);
    });

    testWidgets('lays out on a small phone without overflowing', (
      tester,
    ) async {
      // A test that overflows fails on its own: Flutter reports it as an error.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await toLastStep(tester);

      expect(accept, findsOneWidget);
      // The card stays on screen, buttons included.
      final screen = tester.view.physicalSize;
      expect(tester.getBottomLeft(accept).dy, lessThan(screen.height));
      expect(tester.getTopLeft(find.byType(AppTourCard)).dy, greaterThan(0));
    });

    testWidgets('on the iOS bar too', (tester) async {
      final prefs = await prefsWith({});
      await pumpHost(
        tester,
        prefs: prefs,
        platform: TargetPlatform.iOS,
        handoff: () => AppTourHandoff.addFirstBike,
      );
      await waitForAutoStart(tester);
      for (var i = 0; i < 4; i++) {
        await pressNext(tester);
      }

      await tester.tap(accept);
      await tester.pumpAndSettle();

      expect(find.text('add-bike-page'), findsOneWidget);
    });
  });

  testWidgets('leaving the screen takes the tour with it', (tester) async {
    await pumpHost(tester, prefs: await prefsWith({}));
    await waitForAutoStart(tester);
    expect(card, findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();

    expect(card, findsNothing);
  });
}
