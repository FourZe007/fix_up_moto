import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/app_tab_bar.dart';
import 'package:fix_up_moto/core/widgets/ios_floating_tab_bar.dart';

/// The five tabs, in bar order. Both bars must show exactly these.
const labels = ['Beranda', 'Feed', 'MyPoint', 'Booking', 'Saya'];

/// Puts an [AppTabBar] in a bare scaffold on a [platform] theme and returns the
/// indexes that get tapped.
Future<List<int>> pumpBar(
  WidgetTester tester,
  TargetPlatform platform, {
  int selected = 0,
  ThemeData? theme,
}) async {
  final taps = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: (theme ?? ThemeData()).copyWith(platform: platform),
      home: Scaffold(
        bottomNavigationBar: AppTabBar(
          selectedIndex: selected,
          onSelected: taps.add,
        ),
      ),
    ),
  );
  return taps;
}

/// The colour an [Icon] was given.
Color? iconColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;

void main() {
  group('Android', () {
    testWidgets('shows the Material bar and not the iOS one', (tester) async {
      await pumpBar(tester, TargetPlatform.android);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(IosFloatingTabBar), findsNothing);
    });

    testWidgets('has the five tabs in order', (tester) async {
      await pumpBar(tester, TargetPlatform.android);

      final destinations = tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      );
      expect(destinations.map((d) => d.label), labels);
    });

    testWidgets('tapping a tab reports its index', (tester) async {
      final taps = await pumpBar(tester, TargetPlatform.android);

      await tester.tap(find.text('MyPoint'));
      await tester.tap(find.text('Saya'));

      expect(taps, [2, 4]);
    });

    testWidgets('tapping the tab already showing is still reported', (
      tester,
    ) async {
      final taps = await pumpBar(tester, TargetPlatform.android, selected: 3);

      await tester.tap(find.text('Booking'));

      expect(taps, [3]);
    });
  });

  group('iOS', () {
    testWidgets('shows the floating pill and not the Material bar', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.iOS);

      expect(find.byType(IosFloatingTabBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('has the same five tabs, in the same order, as Android', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.iOS);

      final bar = tester.widget<IosFloatingTabBar>(
        find.byType(IosFloatingTabBar),
      );
      expect(bar.items.map((item) => item.label), labels);
    });

    testWidgets('tapping a tab reports its index', (tester) async {
      final taps = await pumpBar(tester, TargetPlatform.iOS);

      await tester.tap(find.text('MyPoint'));
      await tester.tap(find.text('Saya'));

      expect(taps, [2, 4]);
    });

    testWidgets('tapping the tab already showing is still reported', (
      tester,
    ) async {
      final taps = await pumpBar(tester, TargetPlatform.iOS, selected: 3);

      await tester.tap(find.text('Booking'));

      expect(taps, [3]);
    });

    testWidgets('the selected tab shows its filled icon, the rest outlined', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.iOS, selected: 0);

      expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.house), findsNothing);
      for (final outlined in [
        CupertinoIcons.play_circle,
        CupertinoIcons.creditcard,
        CupertinoIcons.calendar,
        CupertinoIcons.person,
      ]) {
        expect(find.byIcon(outlined), findsOneWidget);
      }
    });

    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      testWidgets('$name: only the selected tab is the brand colour', (
        tester,
      ) async {
        await pumpBar(tester, TargetPlatform.iOS, theme: theme);

        expect(iconColor(tester, CupertinoIcons.house_fill), AppColors.primary);
        expect(
          iconColor(tester, CupertinoIcons.person),
          isNot(AppColors.primary),
        );
      });
    }

    testWidgets('selecting another tab moves the filled icon to it', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.iOS, selected: 2);

      expect(find.byIcon(CupertinoIcons.creditcard_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.creditcard), findsNothing);
      expect(find.byIcon(CupertinoIcons.house), findsOneWidget);
    });
  });
}
