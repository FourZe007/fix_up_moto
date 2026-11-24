import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/tour/field_guide.dart';

FieldGuideStep stepOf({
  String title = 'Plat Nomor',
  String message = 'Ketik plat nomor seperti di motor.',
  bool? required = true,
  String? warning,
}) => FieldGuideStep(
  key: GlobalKey(),
  title: title,
  message: message,
  required: required,
  warning: warning,
);

Future<void> pumpCard(
  WidgetTester tester, {
  FieldGuideStep? step,
  int number = 2,
  int total = 6,
  VoidCallback? onNext,
  VoidCallback? onBack,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: FieldGuideCard(
        step: step ?? stepOf(),
        number: number,
        total: total,
        onNext: onNext ?? () {},
        onBack: onBack,
      ),
    ),
  ),
);

final next = find.byKey(const Key('field-guide-next'));
final back = find.byKey(const Key('field-guide-back'));
final tag = find.byKey(const Key('field-guide-tag'));

void main() {
  testWidgets('shows the field, how to fill it in, and where we are', (
    tester,
  ) async {
    await pumpCard(
      tester,
      step: stepOf(title: 'Warna', message: 'Tulis warna motor Anda.'),
      number: 2,
      total: 6,
    );

    expect(find.text('Warna'), findsOneWidget);
    expect(find.text('Tulis warna motor Anda.'), findsOneWidget);
    expect(find.text('2 dari 6'), findsOneWidget);
  });

  group('the tag', () {
    testWidgets('says Wajib diisi for a field the form insists on', (
      tester,
    ) async {
      await pumpCard(tester, step: stepOf(required: true));

      expect(
        find.descendant(of: tag, matching: find.text('Wajib diisi')),
        findsOneWidget,
      );
      expect(find.text('Opsional'), findsNothing);
    });

    testWidgets('says Opsional for one that can be left empty', (tester) async {
      await pumpCard(tester, step: stepOf(required: false));

      expect(
        find.descendant(of: tag, matching: find.text('Opsional')),
        findsOneWidget,
      );
      expect(find.text('Wajib diisi'), findsNothing);
    });
  });

  testWidgets('a step with no answer to give has no tag at all', (
    tester,
  ) async {
    await pumpCard(tester, step: stepOf(required: null));

    expect(tag, findsNothing);
    expect(find.text('Wajib diisi'), findsNothing);
    expect(find.text('Opsional'), findsNothing);
  });

  group('the warning', () {
    final warning = find.byKey(const Key('field-guide-warning'));

    testWidgets('is not there unless the step has one', (tester) async {
      await pumpCard(tester);

      expect(warning, findsNothing);
    });

    testWidgets('shows its text in a box with a warning sign', (tester) async {
      await pumpCard(
        tester,
        step: stepOf(warning: 'Jangan lupa, isi data motor dulu.'),
      );

      expect(
        find.descendant(
          of: warning,
          matching: find.text('Jangan lupa, isi data motor dulu.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: warning,
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('comes after the explanation and before the buttons', (
      tester,
    ) async {
      await pumpCard(
        tester,
        step: stepOf(
          message: 'Penjelasan langkah ini.',
          warning: 'Peringatan penting.',
        ),
      );

      final explanation = tester.getRect(find.text('Penjelasan langkah ini.'));
      final caution = tester.getRect(warning);
      final buttons = tester.getRect(next);

      expect(caution.top, greaterThanOrEqualTo(explanation.bottom));
      expect(buttons.top, greaterThanOrEqualTo(caution.bottom));
    });

    testWidgets('does not change the buttons', (tester) async {
      var wentOn = 0;
      await pumpCard(
        tester,
        step: stepOf(warning: 'Peringatan.'),
        onNext: () => wentOn++,
      );

      await tester.tap(next);

      expect(wentOn, 1);
    });
  });

  group('the buttons', () {
    testWidgets('the first step has Lanjut and no Kembali', (tester) async {
      await pumpCard(tester, number: 1);

      expect(back, findsNothing);
      expect(
        find.descendant(of: next, matching: find.text('Lanjut')),
        findsOneWidget,
      );
    });

    testWidgets('a later step has Kembali, which goes back', (tester) async {
      var wentBack = 0;
      await pumpCard(tester, number: 3, onBack: () => wentBack++);

      await tester.tap(back);

      expect(wentBack, 1);
    });

    testWidgets('Lanjut goes on', (tester) async {
      var wentOn = 0;
      await pumpCard(tester, number: 2, onNext: () => wentOn++);

      await tester.tap(next);

      expect(wentOn, 1);
    });

    testWidgets('the last step says Selesai instead of Lanjut', (tester) async {
      await pumpCard(tester, number: 6, total: 6);

      expect(
        find.descendant(of: next, matching: find.text('Selesai')),
        findsOneWidget,
      );
      expect(find.text('Lanjut'), findsNothing);
    });
  });

  testWidgets('is a white card, so it reads on the dark overlay', (
    tester,
  ) async {
    await pumpCard(tester);

    // The card's own Material comes first; the button's come after it.
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(FieldGuideCard),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(material.color, Colors.white);
  });
}
