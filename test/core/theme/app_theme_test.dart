import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_text_styles.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('labelLarge', () {
    test('keeps its colour in light mode — the same textPrimary as before', () {
      expect(AppTheme.light.textTheme.labelLarge!.color, AppColors.textPrimary);
    });

    test('turns white in dark mode instead of staying dark grey', () {
      expect(
        AppTheme.dark.textTheme.labelLarge!.color,
        isNot(AppColors.textPrimary),
      );
    });

    test('keeps its typography in both modes', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final style = theme.textTheme.labelLarge!;
        expect(style.fontSize, AppTextStyles.labelLarge.fontSize);
        expect(style.fontWeight, AppTextStyles.labelLarge.fontWeight);
        expect(style.letterSpacing, AppTextStyles.labelLarge.letterSpacing);
      }
    });
  });

  // Dark-mode work must never move a light-mode colour. These pin the values
  // light mode had before the dark palette was changed.
  group('light theme is unchanged', () {
    final light = AppTheme.light;

    test('page, surface and bar colours', () {
      expect(light.scaffoldBackgroundColor, AppColors.backgroundLight);
      expect(light.colorScheme.surface, AppColors.surfaceLight);
      expect(light.appBarTheme.backgroundColor, AppColors.primary);
      expect(light.appBarTheme.foregroundColor, AppColors.textOnPrimary);
    });

    test('card, input and navigation colours', () {
      expect(light.cardTheme.color, AppColors.surfaceLight);
      expect(light.inputDecorationTheme.fillColor, AppColors.surfaceLight);
      expect(
        light.bottomNavigationBarTheme.backgroundColor,
        AppColors.surfaceLight,
      );
      expect(
        light.bottomNavigationBarTheme.selectedItemColor,
        AppColors.primary,
      );
    });

    test('text colours', () {
      expect(light.textTheme.bodyLarge!.color, AppColors.textPrimary);
      expect(light.textTheme.bodyMedium!.color, AppColors.textSecondary);
    });
  });

  group('dark theme', () {
    final dark = AppTheme.dark;

    test('page is black and the app bar matches it', () {
      expect(dark.scaffoldBackgroundColor, AppColors.backgroundBlack);
      expect(dark.appBarTheme.backgroundColor, AppColors.backgroundBlack);
    });

    test('surfaces that are white in light mode are light grey', () {
      expect(dark.colorScheme.surface, AppColors.surfaceDark);
    });

    test('plain cards are black, as set in the dark theme', () {
      expect(dark.cardTheme.color, AppColors.backgroundBlack);
    });

    test('text drawn straight on the black page is white', () {
      expect(dark.textTheme.bodyLarge!.color, Colors.white);
      expect(contrast(Colors.white, AppColors.backgroundBlack), greaterThan(7));
    });
  });

  group('darkSurface (content on light-grey surfaces in dark mode)', () {
    final surface = AppTheme.darkSurface;

    test('swaps every white surface for the same light grey', () {
      expect(surface.colorScheme.surface, AppColors.surfaceDark);
      expect(surface.cardTheme.color, AppColors.surfaceDark);
      expect(surface.inputDecorationTheme.fillColor, AppColors.surfaceDark);
    });

    test('keeps the light theme\'s dark text, so it reads on light grey', () {
      expect(surface.textTheme.bodyLarge!.color, AppColors.textPrimary);
      expect(
        contrast(AppColors.textPrimary, AppColors.surfaceDark),
        greaterThan(7),
      );
    });

    test('darkens the grey secondary text enough to stay readable', () {
      expect(surface.textTheme.bodyMedium!.color, AppColors.grey700);
      expect(
        contrast(AppColors.grey700, AppColors.surfaceDark),
        greaterThanOrEqualTo(4.5),
      );
      // The light theme's own grey would not have been.
      expect(
        contrast(AppColors.textSecondary, AppColors.surfaceDark),
        lessThan(4.5),
      );
    });

    test('keeps typography', () {
      expect(
        surface.textTheme.bodyMedium!.fontSize,
        AppTextStyles.bodyMedium.fontSize,
      );
    });
  });

  group('resolveMode', () {
    test('switch off: always light, whatever was chosen or saved', () {
      for (final chosen in ThemeMode.values) {
        expect(AppTheme.resolveMode(chosen, enabled: false), ThemeMode.light);
      }
    });

    test('switch on: passes the member\'s choice through', () {
      for (final chosen in ThemeMode.values) {
        expect(AppTheme.resolveMode(chosen, enabled: true), chosen);
      }
    });
  });

  group('brandBackdrop', () {
    Future<Color> backdropIn(WidgetTester tester, ThemeMode mode) async {
      late Color result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: Builder(
            builder: (context) {
              result = AppTheme.brandBackdrop(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('is the brand orange in light mode, as the pages hard-coded', (
      tester,
    ) async {
      expect(await backdropIn(tester, ThemeMode.light), AppColors.primary);
    });

    testWidgets('is black in dark mode', (tester) async {
      expect(
        await backdropIn(tester, ThemeMode.dark),
        AppColors.backgroundBlack,
      );
    });
  });
}
