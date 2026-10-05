import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/theme/theme_cubit.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/settings_page.dart';

/// Mirrors how app.dart wires it: MaterialApp rebuilt from ThemeCubit.
Widget app(ThemeCubit cubit) => BlocProvider<ThemeCubit>.value(
  value: cubit,
  child: BlocBuilder<ThemeCubit, ThemeMode>(
    builder: (context, mode) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: const SettingsPage(),
    ),
  ),
);

Color titleColor(WidgetTester tester) =>
    tester.widget<Text>(find.text('Pengaturan')).style!.color!;

Color barColor(WidgetTester tester) =>
    tester.widget<AppBar>(find.byType(AppBar)).backgroundColor!;

Color arrowColor(WidgetTester tester) {
  final button = tester.widget<IconButton>(
    find.widgetWithIcon(IconButton, Icons.arrow_back),
  );
  return button.style!.foregroundColor!.resolve({})!;
}

void main() {
  late ThemeCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cubit = ThemeCubit(await SharedPreferences.getInstance());
  });

  testWidgets('app bar uses the light theme colours in light mode', (
    tester,
  ) async {
    await cubit.setMode(ThemeMode.light);
    await tester.pumpWidget(app(cubit));

    expect(barColor(tester), AppTheme.light.scaffoldBackgroundColor);
    expect(titleColor(tester), AppTheme.light.colorScheme.onSurface);
    expect(arrowColor(tester), AppTheme.light.colorScheme.onSurface);
  });

  testWidgets('app bar follows the cubit to dark colours when it switches', (
    tester,
  ) async {
    await cubit.setMode(ThemeMode.light);
    await tester.pumpWidget(app(cubit));
    final lightBar = barColor(tester);
    final lightTitle = titleColor(tester);

    await cubit.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(barColor(tester), AppTheme.dark.scaffoldBackgroundColor);
    expect(titleColor(tester), AppTheme.dark.colorScheme.onSurface);
    expect(arrowColor(tester), AppTheme.dark.colorScheme.onSurface);
    // Guards against passing by accident if both themes ever shared a colour.
    expect(barColor(tester), isNot(lightBar));
    expect(titleColor(tester), isNot(lightTitle));
  });
}
