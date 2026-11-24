import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/tour/field_guide_help_button.dart';

void main() {
  late ValueNotifier<bool> active;
  var pressed = 0;

  setUp(() {
    active = ValueNotifier<bool>(false);
    pressed = 0;
  });

  tearDown(() => active.dispose());

  final button = find.byKey(const Key('help'));

  Future<void> pumpButton(WidgetTester tester, {Color? color}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Judul'),
              actions: [
                FieldGuideHelpButton(
                  buttonKey: const Key('help'),
                  active: active,
                  color: color,
                  onPressed: () => pressed++,
                ),
              ],
            ),
          ),
        ),
      );

  bool shown(WidgetTester tester) => tester
      .widget<Visibility>(
        find.ancestor(of: button, matching: find.byType(Visibility)).first,
      )
      .visible;

  testWidgets('is a "?" that presses through', (tester) async {
    await pumpButton(tester);

    await tester.tap(button);

    expect(pressed, 1);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byTooltip('Panduan pengisian'), findsOneWidget);
  });

  testWidgets('steps aside while the guide plays, and comes back', (
    tester,
  ) async {
    await pumpButton(tester);
    expect(shown(tester), isTrue);

    active.value = true;
    await tester.pump();
    expect(shown(tester), isFalse);

    active.value = false;
    await tester.pump();
    expect(shown(tester), isTrue);
  });

  testWidgets('cannot be pressed while it is out of the way', (tester) async {
    await pumpButton(tester);
    active.value = true;
    await tester.pump();

    await tester.tap(button, warnIfMissed: false);

    expect(pressed, 0);
  });

  testWidgets('keeps its place, so the title does not move', (tester) async {
    await pumpButton(tester);
    final before = tester.getTopLeft(find.text('Judul'));
    final size = tester.getSize(button);

    active.value = true;
    await tester.pump();

    expect(tester.getTopLeft(find.text('Judul')), before);
    expect(tester.getSize(button), size);
  });
}
