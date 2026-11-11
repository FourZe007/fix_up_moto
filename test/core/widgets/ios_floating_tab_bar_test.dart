import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/ios_floating_tab_bar.dart';

const items = [
  IosFloatingTabItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'A',
  ),
  IosFloatingTabItem(icon: Icons.search, activeIcon: Icons.search, label: 'B'),
  IosFloatingTabItem(
    icon: Icons.favorite_border,
    activeIcon: Icons.favorite,
    label: 'C',
  ),
];

/// The pill in a bare scaffold on a 400 x 800 screen; returns the taps.
Future<List<int>> pumpPill(
  WidgetTester tester, {
  int selected = 0,
  ThemeData? theme,
  double textScale = 1,
  EdgeInsets viewPadding = EdgeInsets.zero,
  Color? backdropColor,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final taps = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: viewPadding,
          viewPadding: viewPadding,
        ),
        child: child!,
      ),
      home: Scaffold(
        bottomNavigationBar: IosFloatingTabBar(
          selectedIndex: selected,
          onSelected: taps.add,
          items: items,
          backdropColor: backdropColor,
        ),
      ),
    ),
  );
  return taps;
}

/// The strip behind the pill, if one was painted.
Finder get strip => find.descendant(
  of: find.byType(IosFloatingTabBar),
  matching: find.byType(ColoredBox),
);

/// The pill itself: the decorated box that carries the colour and the shadow.
Finder get pill => find.descendant(
  of: find.byType(IosFloatingTabBar),
  matching: find.byType(DecoratedBox),
);

ShapeDecoration pillDecoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(pill.first).decoration as ShapeDecoration;

/// What each tab's highlight is painted with, in order (transparent when idle).
List<Color> highlights(WidgetTester tester) => [
  for (final box in tester.widgetList<AnimatedContainer>(
    find.byType(AnimatedContainer),
  ))
    (box.decoration as ShapeDecoration).color!,
];

void main() {
  testWidgets('the pill is fully rounded, with a shadow', (tester) async {
    await pumpPill(tester);

    final decoration = pillDecoration(tester);
    expect(decoration.shape, isA<StadiumBorder>());
    expect(decoration.shadows, isNotEmpty);
  });

  testWidgets('it floats: a margin on both sides and below it', (tester) async {
    await pumpPill(tester);

    final rect = tester.getRect(pill.first);
    expect(rect.left, 16);
    expect(rect.right, 400 - 16);
    // 8 below it on a phone with no bottom inset, so it never touches the edge.
    expect(rect.bottom, 800 - 8);
  });

  testWidgets('on a phone with a home indicator it clears the inset', (
    tester,
  ) async {
    await pumpPill(tester, viewPadding: const EdgeInsets.only(bottom: 34));

    expect(tester.getRect(pill.first).bottom, 800 - 34);
  });

  group('the strip behind the pill', () {
    const orange = Color(0xFFE65100);

    testWidgets('is left unpainted when no colour is given', (tester) async {
      await pumpPill(tester);

      expect(strip, findsNothing);
    });

    testWidgets('is painted the colour it is given', (tester) async {
      await pumpPill(tester, backdropColor: orange);

      expect(tester.widget<ColoredBox>(strip).color, orange);
    });

    testWidgets('spans the whole width and reaches the bottom edge', (
      tester,
    ) async {
      await pumpPill(tester, backdropColor: orange);

      final rect = tester.getRect(strip);
      expect(rect.left, 0);
      expect(rect.right, 400);
      expect(rect.bottom, 800);
    });

    testWidgets('is painted under the home-indicator inset too', (
      tester,
    ) async {
      await pumpPill(
        tester,
        backdropColor: orange,
        viewPadding: const EdgeInsets.only(bottom: 34),
      );

      // The pill clears the inset, and the colour still runs to the very edge.
      expect(tester.getRect(pill.first).bottom, 800 - 34);
      expect(tester.getRect(strip).bottom, 800);
    });

    testWidgets('does not move the pill', (tester) async {
      await pumpPill(tester);
      final without = tester.getRect(pill.first);

      await pumpPill(tester, backdropColor: orange);

      expect(tester.getRect(pill.first), without);
    });
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets(
      '$name: the pill and the idle tabs use the theme\'s bar colours',
      (tester) async {
        await pumpPill(tester, theme: theme);

        expect(
          pillDecoration(tester).color,
          theme.bottomNavigationBarTheme.backgroundColor,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.search)).color,
          theme.bottomNavigationBarTheme.unselectedItemColor,
        );
      },
    );
  }

  group('the selected tab', () {
    testWidgets('has a brand-tinted highlight; the others have none', (
      tester,
    ) async {
      await pumpPill(tester, selected: 1);

      final colours = highlights(tester);
      expect(colours[1], isNot(Colors.transparent));
      expect(
        colours[1].toARGB32() & 0x00FFFFFF,
        AppColors.primary.toARGB32() & 0x00FFFFFF,
      );
      expect(colours[0], Colors.transparent);
      expect(colours[2], Colors.transparent);
    });

    testWidgets('is the brand colour in its icon and label, filled', (
      tester,
    ) async {
      await pumpPill(tester, selected: 2);

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
        AppColors.primary,
      );
      expect(
        tester.widget<Text>(find.text('C')).style!.color,
        AppColors.primary,
      );
      expect(
        tester.widget<Text>(find.text('A')).style!.color,
        isNot(AppColors.primary),
      );
    });

    testWidgets('the highlight moves when the selection does', (tester) async {
      await pumpPill(tester, selected: 0);
      expect(highlights(tester)[0], isNot(Colors.transparent));

      await pumpPill(tester, selected: 2);
      await tester.pumpAndSettle();

      expect(highlights(tester)[0], Colors.transparent);
      expect(highlights(tester)[2], isNot(Colors.transparent));
    });
  });

  group('tapping', () {
    testWidgets('anywhere in a tab counts, not just the icon and label', (
      tester,
    ) async {
      final taps = await pumpPill(tester);

      // The very corners of the middle tab: nowhere near its icon or text.
      final tab = tester.getRect(find.byType(GestureDetector).at(1));
      await tester.tapAt(tab.topLeft + const Offset(1, 1));
      await tester.tapAt(tab.bottomRight - const Offset(1, 1));

      expect(taps, [1, 1]);
    });

    testWidgets('has no ripple, as on iOS', (tester) async {
      await pumpPill(tester);

      expect(
        find.descendant(
          of: find.byType(IosFloatingTabBar),
          matching: find.byType(InkResponse),
        ),
        findsNothing,
      );
    });

    testWidgets('each tab is at least 44 points tall', (tester) async {
      await pumpPill(tester);

      for (var i = 0; i < items.length; i++) {
        final size = tester.getSize(find.byType(GestureDetector).at(i));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });
  });

  testWidgets('a huge system font cannot grow the labels past 1.15x', (
    tester,
  ) async {
    await pumpPill(tester, textScale: 3);

    final scaler = MediaQuery.of(tester.element(find.text('A'))).textScaler;
    expect(scaler.scale(10), closeTo(11.5, 0.001));
    // Nothing overflowed.
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers hear each tab as a button, one selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpPill(tester, selected: 1);

    final b = tester.getSemantics(find.bySemanticsLabel('B'));
    final a = tester.getSemantics(find.bySemanticsLabel('A'));
    expect(
      b,
      matchesSemantics(
        label: 'B',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      a,
      matchesSemantics(
        label: 'A',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
