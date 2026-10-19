import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/privacy_policy_page.dart';

/// A real router with a page underneath, so the back arrow can be checked by
/// where it lands.
Future<void> pumpPolicy(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('profile-page')),
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        builder: (_, _) => const PrivacyPolicyPage(),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  unawaited(router.push(RouteNames.privacyPolicy));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the app bar title, the heading and the effective date', (
    tester,
  ) async {
    await pumpPolicy(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Kebijakan Privasi'),
      ),
      findsOneWidget,
    );
    expect(find.text('KEBIJAKAN PRIVASI FIXUP MOTO'), findsOneWidget);
    expect(find.textContaining('Berlaku sejak'), findsOneWidget);
  });

  testWidgets('names FixUp Moto and its company, not the policy it was '
      'adapted from', (tester) async {
    await pumpPolicy(tester);

    expect(find.textContaining('PT Sapta Aji Manungga Prima'), findsOneWidget);
    expect(find.textContaining('Kopi Kenangan'), findsNothing);
    // One spelling of the brand throughout.
    expect(find.textContaining('FixUP'), findsNothing);
  });

  testWidgets('shows the Syarat dan Ketentuan as a numbered list of four', (
    tester,
  ) async {
    await pumpPolicy(tester);

    expect(find.text('Syarat dan Ketentuan'), findsOneWidget);
    for (final number in ['1.', '2.', '3.', '4.']) {
      expect(find.text(number), findsOneWidget);
    }
    expect(find.text('5.'), findsNothing);
    expect(find.textContaining('pihak ke-3 (tiga)'), findsOneWidget);
  });

  testWidgets('scrolls down to the last term', (tester) async {
    await pumpPolicy(tester);

    final lastTerm = find.textContaining('pihak ke-3 (tiga)');
    await tester.scrollUntilVisible(lastTerm, 200);

    expect(tester.getBottomLeft(lastTerm).dy, lessThan(600));
  });

  testWidgets('does not overflow at a large font size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPolicy(tester);

    // A RenderFlex overflow would be reported as a test exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the back arrow returns to the previous page', (tester) async {
    await pumpPolicy(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('profile-page'), findsOneWidget);
    expect(find.byType(PrivacyPolicyPage), findsNothing);
  });
}
