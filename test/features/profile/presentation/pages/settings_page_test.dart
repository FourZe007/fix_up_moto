import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/theme/theme_cubit.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/settings_page.dart';

/// Mirrors how app.dart wires it: MaterialApp rebuilt from ThemeCubit. With a
/// [platform], both themes report it (what PREVIEW_PLATFORM does).
Widget app(ThemeCubit cubit, {TargetPlatform? platform}) =>
    BlocProvider<ThemeCubit>.value(
      value: cubit,
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) => MaterialApp(
          theme: AppTheme.light.copyWith(platform: platform),
          darkTheme: AppTheme.dark.copyWith(platform: platform),
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

  group('the Dark mode switch', () {
    /// Dark mode, so the switch is on and offered (it is disabled while the
    /// theme follows the device), on a theme that reports [platform].
    Future<void> pumpDark(WidgetTester tester, TargetPlatform platform) async {
      await cubit.setMode(ThemeMode.dark);
      await tester.pumpWidget(app(cubit, platform: platform));
    }

    Switch theSwitch(WidgetTester tester) =>
        tester.widget<Switch>(find.byType(Switch));

    testWidgets('paints the theme colour when on, as before (Android)', (
      tester,
    ) async {
      await pumpDark(tester, TargetPlatform.android);

      expect(find.byType(Switch), findsOneWidget);
      final primary = Theme.of(
        tester.element(find.byType(Switch)),
      ).colorScheme.primary;
      expect(
        tester.renderObject(find.byType(Switch)),
        paints..rrect(color: primary),
      );
    });

    testWidgets('paints the iOS green when on, not the theme colour (iOS)', (
      tester,
    ) async {
      await pumpDark(tester, TargetPlatform.iOS);

      // `Switch.adaptive` is still a Switch widget; on iOS it draws itself the
      // iOS way, which Flutter 3.47 does with its own Cupertino styling rather
      // than a CupertinoSwitch widget.
      expect(find.byType(Switch), findsOneWidget);
      final context = tester.element(find.byType(Switch));
      final green = CupertinoDynamicColor.resolve(
        CupertinoColors.systemGreen,
        context,
      );
      expect(
        tester.renderObject(find.byType(Switch)),
        paints..rrect(color: green),
      );
    });

    testWidgets('still turns dark mode off from iOS', (tester) async {
      await pumpDark(tester, TargetPlatform.iOS);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(cubit.state, ThemeMode.light);
    });

    testWidgets('stays off, on either platform, while following the device', (
      tester,
    ) async {
      // A fresh cubit follows the device (ThemeMode.system).
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        await tester.pumpWidget(app(cubit, platform: platform));
        await tester.pump();

        expect(theSwitch(tester).onChanged, isNull, reason: '$platform');
      }
    });
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
