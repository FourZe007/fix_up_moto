import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/tour/field_guide.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';
import 'package:fix_up_moto/features/profile/presentation/widgets/bike_form.dart';

/// The form on its own, as Edit Bike uses it: the field guide belongs to Add
/// Bike, so a form given no guide settings must stay exactly as it was.
void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    SharedPreferences? guidePrefs,
    bool autoGuide = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BikeForm(
          submitLabel: 'Simpan',
          onSubmit: (_) {},
          guidePrefs: guidePrefs,
          autoGuide: autoGuide,
        ),
      ),
    ),
  );

  final card = find.byType(FieldGuideCard);

  testWidgets('without guide settings it never plays by itself', (
    tester,
  ) async {
    // autoGuide alone is not enough: there is nowhere to remember it was seen.
    await pumpForm(tester, autoGuide: true);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(card, findsNothing);
  });

  testWidgets('plays by itself once guide settings are given', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await pumpForm(tester, guidePrefs: prefs, autoGuide: true);

    await tester.pump(BikeForm.guideDelay);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(card, findsOneWidget);
  });

  testWidgets('a guide asked for by hand needs no settings', (tester) async {
    await pumpForm(tester);
    final form = tester.state<BikeFormState>(find.byType(BikeForm));

    expect(form.playGuide(), isTrue);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(card, findsOneWidget);
    // Ending it, with nowhere to remember that, does not throw.
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
  });

  testWidgets('once the page is gone the guide goes with it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await pumpForm(tester, guidePrefs: prefs, autoGuide: true);
    await tester.pump(BikeForm.guideDelay);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(card, findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();

    expect(card, findsNothing);
    expect(find.text('Lewati'), findsNothing);
    // Not finished, so not seen: it comes back next time.
    expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isFalse);
  });
}
