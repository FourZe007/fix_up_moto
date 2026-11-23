import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/router/tab_container.dart';
import 'package:fix_up_moto/core/tour/app_tour_steps.dart';
import 'package:fix_up_moto/core/widgets/app_tab_bar.dart';

void main() {
  const steps = AppTourSteps.all;

  test('there is one step per tab, left to right', () {
    expect(steps.map((step) => step.tab), [
      MainTabs.home,
      MainTabs.feeds,
      MainTabs.membership,
      MainTabs.bookings,
      MainTabs.profile,
    ]);
  });

  test('every step has a title and a message to read', () {
    for (final step in steps) {
      expect(step.title.trim(), isNotEmpty);
      expect(step.message.trim(), isNotEmpty);
    }
  });

  test('messages stay short enough for someone new to read at a glance', () {
    for (final step in steps) {
      expect(
        step.message.length,
        lessThanOrEqualTo(170),
        reason: '${step.title} is ${step.message.length} characters',
      );
    }
  });

  testWidgets('each title is the label the bar gives that tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppTabBar(selectedIndex: 0, onSelected: (_) {}),
        ),
      ),
    );

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label)
        .toList();

    for (final step in steps) {
      expect(step.title, labels[step.tab], reason: 'tab ${step.tab}');
    }
  });
}
