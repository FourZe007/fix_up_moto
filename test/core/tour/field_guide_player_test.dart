import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/tour/field_guide.dart';
import 'package:fix_up_moto/core/tour/field_guide_player.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';

/// A one-step page that starts its guide by itself, the way a real page does.
class Host extends StatefulWidget {
  final SharedPreferences prefs;
  final bool Function()? ready;

  const Host({super.key, required this.prefs, this.ready});

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  final target = GlobalKey();
  double room = 0;
  late final FieldGuidePlayer player;

  @override
  void initState() {
    super.initState();
    player = FieldGuidePlayer(
      guideId: 'test_page',
      steps: [
        FieldGuideStep(
          key: target,
          title: 'Langkah satu',
          message: 'Isi bagian ini.',
          required: true,
        ),
      ],
      state: this,
      prefs: widget.prefs,
      onRoomChanged: (value) => setState(() => room = value),
    );
    player.autoPlayOnce(ready: widget.ready);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          SizedBox(key: target, height: 60, child: const Text('sasaran')),
          SizedBox(height: room),
        ],
      ),
    );
  }
}

void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  final card = find.byType(FieldGuideCard);

  /// Lets a started guide come up. Fixed steps: the overlay's chain has gaps where
  /// `pumpAndSettle` would stop (see the Add Bike tests).
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> pumpHost(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
    bool Function()? ready,
  }) async {
    final prefs = await prefsWith(saved);
    await tester.pumpWidget(
      MaterialApp(
        home: Host(prefs: prefs, ready: ready),
      ),
    );
  }

  testWidgets('starts after the page has settled in, when nothing holds it', (
    tester,
  ) async {
    await pumpHost(tester);

    await tester.pump(FieldGuidePlayer.autoDelay);
    await settle(tester);

    expect(card, findsOneWidget);
  });

  testWidgets('not before that', (tester) async {
    await pumpHost(tester);

    await tester.pump(
      FieldGuidePlayer.autoDelay - const Duration(milliseconds: 200),
    );

    expect(card, findsNothing);
  });

  testWidgets('does not start while it is not ready', (tester) async {
    var ready = false;
    await pumpHost(tester, ready: () => ready);

    await tester.pump(FieldGuidePlayer.autoDelay);
    await tester.pump(const Duration(seconds: 3));

    expect(card, findsNothing);
  });

  testWidgets('starts soon after it becomes ready', (tester) async {
    var ready = false;
    await pumpHost(tester, ready: () => ready);
    await tester.pump(FieldGuidePlayer.autoDelay);
    await tester.pump(const Duration(seconds: 3));
    expect(card, findsNothing);

    ready = true;
    await tester.pump(FieldGuidePlayer.retryEvery);
    await settle(tester);

    expect(card, findsOneWidget);
  });

  testWidgets('starts anyway when it never becomes ready', (tester) async {
    await pumpHost(tester, ready: () => false);

    await tester.pump(FieldGuidePlayer.autoDelay);
    await tester.pump(FieldGuidePlayer.waitAtMost);
    await settle(tester);

    expect(card, findsOneWidget);
  });

  testWidgets('asks again every so often, not once', (tester) async {
    var asked = 0;
    await pumpHost(
      tester,
      ready: () {
        asked++;
        return false;
      },
    );

    await tester.pump(FieldGuidePlayer.autoDelay);
    await tester.pump(FieldGuidePlayer.retryEvery * 5);

    expect(asked, greaterThanOrEqualTo(5));
  });

  testWidgets('waits while the app is not in the foreground', (tester) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await pumpHost(tester);
    // What a system permission prompt does to the app.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

    await tester.pump(FieldGuidePlayer.autoDelay);
    await tester.pump(const Duration(seconds: 3));
    expect(card, findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(FieldGuidePlayer.retryEvery);
    await settle(tester);

    expect(card, findsOneWidget);
  });

  testWidgets('time behind a system prompt does not use up the cap', (
    tester,
  ) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await pumpHost(tester, ready: () => false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

    // A minute with the prompt up: far past the cap, and still nothing.
    await tester.pump(FieldGuidePlayer.autoDelay);
    await tester.pump(const Duration(minutes: 1));
    expect(card, findsNothing);

    // Back in the foreground and still not ready: the cap starts counting now,
    // so a little under it is still waiting...
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(FieldGuidePlayer.waitAtMost - const Duration(seconds: 2));
    expect(card, findsNothing);

    // ...and it starts anyway once the cap of foreground time is spent.
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(card, findsOneWidget);
  });

  testWidgets('the cap is longer than the page limit it stands behind', (
    tester,
  ) async {
    // Create Booking's workshop lookup may take up to 30 s: the guide must be
    // willing to wait through all of it.
    expect(
      FieldGuidePlayer.waitAtMost,
      greaterThan(const Duration(seconds: 30)),
    );
  });

  testWidgets('never starts for a phone that has been through it', (
    tester,
  ) async {
    var asked = 0;
    await pumpHost(
      tester,
      saved: {FieldGuideSeen.keyFor('test_page'): true},
      ready: () {
        asked++;
        return true;
      },
    );

    await tester.pump(FieldGuidePlayer.autoDelay);
    await tester.pump(const Duration(seconds: 10));

    expect(card, findsNothing);
    expect(asked, 0);
  });

  testWidgets('stops asking once the page is gone', (tester) async {
    var asked = 0;
    await pumpHost(
      tester,
      ready: () {
        asked++;
        return false;
      },
    );
    await tester.pump(FieldGuidePlayer.autoDelay);
    final before = asked;

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump(const Duration(seconds: 10));

    expect(asked, before);
    expect(card, findsNothing);
  });

  testWidgets('play() still works by hand, ready or not', (tester) async {
    await pumpHost(tester, ready: () => false);

    final started = tester.state<HostState>(find.byType(Host)).player.play();
    await settle(tester);

    expect(started, isTrue);
    expect(card, findsOneWidget);
  });
}
