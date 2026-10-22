import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/phone_input_formatter.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';

const _prefix = '+62';
const _hint = '81234567889';
const _label = 'Phone number';

Future<TextEditingController> pumpField(
  WidgetTester tester, {
  ThemeData? theme,
  String? prefixText,
  IconData? prefixIcon,
  bool formatter = false,
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: AuthTextField(
          controller: controller,
          label: _label,
          hint: _hint,
          prefixText: prefixText,
          prefixIcon: prefixIcon,
          keyboardType: TextInputType.phone,
          inputFormatters: formatter
              ? const [PhoneNumberInputFormatter()]
              : null,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// How visible a decoration piece is. Flutter keeps the hint and the prefix in
/// the tree even while it hides them (an opacity of 0), so "is it there" does
/// not say whether the member can see it.
double opacityOf(WidgetTester tester, Finder piece) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: piece, matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity;

void main() {
  final field = find.byType(TextFormField);

  group('with a prefix', () {
    testWidgets('shows the label, the +62 and the hint before it is tapped', (
      tester,
    ) async {
      await pumpField(tester, prefixText: _prefix);

      expect(find.text(_label), findsOneWidget);
      expect(find.text(_prefix), findsOneWidget);
      expect(opacityOf(tester, find.text(_prefix)), 1);
      expect(find.text(_hint), findsOneWidget);
      expect(opacityOf(tester, find.text(_hint)), 1);
    });

    testWidgets('keeps the +62 while typing, and the hint gives way', (
      tester,
    ) async {
      await pumpField(tester, prefixText: _prefix);

      await tester.enterText(field, '812');
      await tester.pumpAndSettle();

      expect(find.text(_label), findsOneWidget);
      expect(opacityOf(tester, find.text(_prefix)), 1);
      expect(opacityOf(tester, find.text(_hint)), 0);
    });

    testWidgets('keeps the +62 in the field, but not in what is typed', (
      tester,
    ) async {
      final controller = await pumpField(tester, prefixText: _prefix);

      await tester.enterText(field, '81234567890');

      // The prefix is decoration: the value to validate and send is the number.
      expect(controller.text, '81234567890');
    });

    testWidgets('is set in the input\'s own style, but bolder, not in the '
        'hint\'s grey', (tester) async {
      await pumpField(tester, prefixText: _prefix);

      final prefix = tester.widget<Text>(find.text(_prefix));
      final bodyLarge = Theme.of(
        tester.element(find.text(_prefix)),
      ).textTheme.bodyLarge!;

      expect(prefix.style?.fontWeight, FontWeight.w600);
      expect(prefix.style?.fontSize, bodyLarge.fontSize);
      expect(prefix.style?.color, bodyLarge.color);
      expect(prefix.style?.color, isNot(AppTheme.light.hintColor));
    });

    testWidgets('is dark on the light-grey box in dark mode too', (
      tester,
    ) async {
      await pumpField(tester, theme: ThemeData.dark(), prefixText: _prefix);

      final color = tester.widget<Text>(find.text(_prefix)).style?.color;

      // The scope's light-surface theme, not the dark theme's white text.
      expect(color, AppTheme.darkSurface.textTheme.bodyLarge?.color);
      expect(color, isNot(ThemeData.dark().textTheme.bodyLarge?.color));
    });

    testWidgets('applies the input formatter as the member types', (
      tester,
    ) async {
      final controller = await pumpField(
        tester,
        prefixText: _prefix,
        formatter: true,
      );

      await tester.enterText(field, '0812-3456-7890');
      expect(controller.text, '81234567890');

      await tester.enterText(field, '+62 812 3456 7890');
      expect(controller.text, '81234567890');
    });
  });

  group('without a prefix', () {
    testWidgets('shows the label and the hint before it is tapped too', (
      tester,
    ) async {
      await pumpField(tester);

      // Every field keeps its label up, so the hint is not hidden until focus
      // the way Flutter does by default for a field with an inline label.
      expect(find.text(_label), findsOneWidget);
      expect(opacityOf(tester, find.text(_hint)), 1);
      expect(find.text(_prefix), findsNothing);
    });

    testWidgets('lets the hint give way once something is typed', (
      tester,
    ) async {
      await pumpField(tester);

      await tester.enterText(field, '8');
      await tester.pumpAndSettle();

      expect(find.text(_label), findsOneWidget);
      expect(opacityOf(tester, find.text(_hint)), 0);
    });

    testWidgets('still shows its leading icon', (tester) async {
      await pumpField(tester, prefixIcon: Icons.phone_outlined);

      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    });

    testWidgets('leaves what is typed alone', (tester) async {
      final controller = await pumpField(tester);

      await tester.enterText(field, '0812-3456');

      expect(controller.text, '0812-3456');
    });
  });
}
