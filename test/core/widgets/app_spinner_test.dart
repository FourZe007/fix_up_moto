import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/widgets/app_spinner.dart';

/// Pumps [child] under a theme that reports [platform]. The spinner reads the
/// theme's platform, not the device's, so the iOS look can be seen anywhere.
Future<void> pumpOn(
  WidgetTester tester,
  TargetPlatform platform,
  Widget child,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('on Android', () {
    testWidgets('is the ordinary spinner, with nothing added', (tester) async {
      await pumpOn(tester, TargetPlatform.android, const AppSpinner());

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      // Nothing is passed that the old call sites did not pass, so the spinner
      // looks exactly as it did before AppSpinner existed.
      expect(spinner.color, isNull);
      expect(spinner.strokeWidth, isNull);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('passes its colour and stroke width through', (tester) async {
      await pumpOn(
        tester,
        TargetPlatform.android,
        const AppSpinner(color: Colors.white, strokeWidth: 2),
      );

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, Colors.white);
      expect(spinner.strokeWidth, 2);
    });
  });

  group('on iOS', () {
    testWidgets('is the iOS activity indicator', (tester) async {
      await pumpOn(tester, TargetPlatform.iOS, const AppSpinner());

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('keeps its colour, which the adaptive spinner would drop', (
      tester,
    ) async {
      // A white spinner on an orange button must stay white.
      await pumpOn(
        tester,
        TargetPlatform.iOS,
        const AppSpinner(color: Colors.white, strokeWidth: 2),
      );

      final indicator = tester.widget<CupertinoActivityIndicator>(
        find.byType(CupertinoActivityIndicator),
      );
      expect(indicator.color, Colors.white);
    });

    testWidgets('fills the box it is put in, like the Android one', (
      tester,
    ) async {
      await pumpOn(
        tester,
        TargetPlatform.iOS,
        const SizedBox(width: 16, height: 16, child: AppSpinner()),
      );

      expect(tester.getSize(find.byType(AppSpinner)), const Size(16, 16));
    });

    testWidgets('has the indicator\'s own size when nothing boxes it in', (
      tester,
    ) async {
      await pumpOn(tester, TargetPlatform.iOS, const AppSpinner());

      expect(tester.getSize(find.byType(AppSpinner)), const Size(20, 20));
    });

    testWidgets('can sit where the layout asks for intrinsic sizes', (
      tester,
    ) async {
      await pumpOn(
        tester,
        TargetPlatform.iOS,
        const IntrinsicHeight(
          child: IntrinsicWidth(child: Row(children: [AppSpinner()])),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });
  });

  testWidgets('follows the theme, not the phone it runs on', (tester) async {
    // The test host reports Android (defaultTargetPlatform); only the theme
    // says iOS, which is what the PREVIEW_PLATFORM switch changes.
    expect(defaultTargetPlatform, TargetPlatform.android);

    await pumpOn(tester, TargetPlatform.iOS, const AppSpinner());

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });
}
