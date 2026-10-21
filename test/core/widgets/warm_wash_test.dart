import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';

Future<void> pumpWash(WidgetTester tester, {ThemeData? theme}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const WarmWash(child: Center(child: Text('on the wash'))),
    ),
  );
}

void main() {
  final base = find.descendant(
    of: find.byType(WarmWash),
    matching: find.byType(ColoredBox),
  );
  final washBox = find.descendant(
    of: find.byType(WarmWash),
    matching: find.byType(DecoratedBox),
  );

  LinearGradient gradientOf(WidgetTester tester) =>
      (tester.widget<DecoratedBox>(washBox.first).decoration as BoxDecoration)
              .gradient
          as LinearGradient;

  testWidgets('shows what is put on it', (tester) async {
    await pumpWash(tester);

    expect(find.text('on the wash'), findsOneWidget);
  });

  testWidgets('keeps the theme\'s page colour underneath: white-grey in light '
      'mode, black in dark mode', (tester) async {
    await pumpWash(tester, theme: AppTheme.light);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ColoredBox>(base.first).color,
      AppColors.backgroundLight,
    );

    // A theme change animates, so let it finish before reading the colour.
    await pumpWash(tester, theme: AppTheme.dark);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ColoredBox>(base.first).color,
      AppColors.backgroundBlack,
    );
  });

  testWidgets('fades the brand\'s light orange from 30% at the top to nothing '
      'by halfway down', (tester) async {
    await pumpWash(tester);

    final gradient = gradientOf(tester);
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.stops, [0, 0.5]);
    expect(gradient.colors.first.a, closeTo(0.30, 0.005));
    expect(gradient.colors.last.a, 0);
  });

  testWidgets('fades through the same orange, not transparent black, so the '
      'fade never greys', (tester) async {
    await pumpWash(tester);

    final gradient = gradientOf(tester);
    for (final color in gradient.colors) {
      expect(color.withValues(alpha: 1), AppColors.primaryLight);
    }
  });

  testWidgets('fills whatever space it is given, so it reaches the top of the '
      'screen', (tester) async {
    await pumpWash(tester);

    expect(tester.getTopLeft(washBox.first), Offset.zero);
    expect(
      tester.getSize(washBox.first),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
  });
}
