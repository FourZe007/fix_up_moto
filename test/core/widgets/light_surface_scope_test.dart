import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';

/// Reads the theme from just outside and just inside a [LightSurfaceScope].
class Probe {
  late ThemeData outside;
  late ThemeData inside;
}

Widget app(ThemeMode mode, Probe probe) => MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: mode,
  home: Builder(
    builder: (outer) {
      probe.outside = Theme.of(outer);
      return LightSurfaceScope(
        child: Builder(
          builder: (inner) {
            probe.inside = Theme.of(inner);
            return const SizedBox();
          },
        ),
      );
    },
  ),
);

void main() {
  testWidgets('light mode: the scope changes nothing', (tester) async {
    final probe = Probe();
    await tester.pumpWidget(app(ThemeMode.light, probe));

    expect(probe.inside.colorScheme.surface, AppColors.surfaceLight);
    expect(probe.inside.textTheme.bodyLarge!.color, AppColors.textPrimary);
    expect(
      probe.inside.scaffoldBackgroundColor,
      probe.outside.scaffoldBackgroundColor,
    );
    expect(probe.inside.brightness, Brightness.light);
  });

  testWidgets('dark mode: the page stays black with white text', (
    tester,
  ) async {
    final probe = Probe();
    await tester.pumpWidget(app(ThemeMode.dark, probe));

    expect(probe.outside.scaffoldBackgroundColor, AppColors.backgroundBlack);
    expect(probe.outside.textTheme.bodyLarge!.color, Colors.white);
  });

  testWidgets('dark mode: inside the scope is dark text on light grey', (
    tester,
  ) async {
    final probe = Probe();
    await tester.pumpWidget(app(ThemeMode.dark, probe));

    expect(probe.inside.colorScheme.surface, AppColors.surfaceDark);
    expect(probe.inside.cardTheme.color, AppColors.surfaceDark);
    expect(probe.inside.textTheme.bodyLarge!.color, AppColors.textPrimary);
    expect(probe.inside.brightness, Brightness.light);
  });
}
