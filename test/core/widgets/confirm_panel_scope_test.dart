import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/confirm_panel_scope.dart';

/// What a test needs to drive and watch the page: what each confirmation
/// resolved to, and a switch that removes the scope while a panel is open.
class Harness {
  final results = <bool>[];
  final showScope = ValueNotifier<bool>(true);
  bool destructive = false;
}

final ask = find.byKey(const Key('ask'));
final bottomBar = find.byKey(const Key('bottom-bar'));
final panel = find.byKey(const Key('confirm-panel'));
final confirmButton = find.byKey(const Key('confirm-panel-confirm'));
final cancelButton = find.byKey(const Key('confirm-panel-cancel'));
final pageBarrier = find.byKey(const Key('confirm-panel-page-barrier'));

/// A page with a bottom bar (standing in for MainShell's) inside a
/// [ConfirmPanelScope], in a real `MaterialApp.router`: the panel claims the
/// system back button through the Router.
Future<void> pumpScope(
  WidgetTester tester,
  Harness harness, {
  double textScale = 1,
}) async {
  addTearDown(harness.showScope.dispose);

  Widget page() => Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('ask'),
          onPressed: () async {
            final ok = await ConfirmPanelScope.of(context).confirm(
              icon: Icons.logout,
              title: 'Judul',
              message: 'Pesan konfirmasi',
              confirmLabel: 'Ya',
              destructive: harness.destructive,
            );
            harness.results.add(ok);
          },
          child: const Text('ask'),
        ),
      ),
      bottomNavigationBar: const SizedBox(key: Key('bottom-bar'), height: 56),
    ),
  );

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => ValueListenableBuilder<bool>(
          valueListenable: harness.showScope,
          builder: (_, show, _) =>
              show ? ConfirmPanelScope(child: page()) : page(),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  // The panel is mounted into the root Overlay after the first frame, and
  // built on the next.
  await tester.pumpAndSettle();
}

double screenHeight(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

void main() {
  late Harness harness;

  setUp(() => harness = Harness());

  group('at rest', () {
    testWidgets('builds no panel and no blur, and lets taps through', (
      tester,
    ) async {
      await pumpScope(tester, harness);

      expect(panel, findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      // The page behind is still tappable, so the closed panel blocks nothing.
      await tester.tap(ask);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
    });
  });

  group('when open', () {
    testWidgets('slides up in the root overlay, above the Scaffold and the '
        'bottom bar, with the page blurred behind it', (tester) async {
      await pumpScope(tester, harness);

      await tester.tap(ask);
      await tester.pumpAndSettle();

      expect(panel, findsOneWidget);
      expect(find.text('Judul'), findsOneWidget);
      expect(find.text('Pesan konfirmasi'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      // Not part of the page's own Scaffold: it sits in the Overlay above it.
      expect(
        find.ancestor(of: panel, matching: find.byType(Scaffold)),
        findsNothing,
      );
      // Flush with the bottom of the screen, and tall enough to cover the bar.
      expect(tester.getBottomLeft(panel).dy, screenHeight(tester));
      expect(
        tester.getTopLeft(panel).dy,
        lessThan(tester.getTopLeft(bottomBar).dy),
      );
    });

    testWidgets('the blur follows the panel: none once it has closed again', (
      tester,
    ) async {
      await pumpScope(tester, harness);

      await tester.tap(ask);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('hides the page behind from screen readers until it closes', (
      tester,
    ) async {
      await pumpScope(tester, harness);
      bool excluding() =>
          tester.widget<ExcludeSemantics>(pageBarrier).excluding;

      expect(excluding(), isFalse);

      await tester.tap(ask);
      await tester.pumpAndSettle();
      expect(excluding(), isTrue);

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      expect(excluding(), isFalse);
    });

    testWidgets('asking again while one is open answers false at once', (
      tester,
    ) async {
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      final second = await ConfirmPanelScope.of(tester.element(ask)).confirm(
        icon: Icons.delete,
        title: 'Lain',
        message: 'Lain',
        confirmLabel: 'Hapus',
      );

      expect(second, isFalse);
      expect(find.text('Lain'), findsNothing);
      expect(find.text('Judul'), findsOneWidget);
    });
  });

  group('how it ends', () {
    testWidgets('the confirm button answers true, once the panel has closed', (
      tester,
    ) async {
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      await tester.tap(confirmButton);
      // The slide away has only just begun: still no answer.
      await tester.pump();
      expect(harness.results, isEmpty);

      await tester.pumpAndSettle();
      expect(harness.results, [true]);
      expect(panel, findsNothing);
    });

    testWidgets('the cancel button answers false', (tester) async {
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(harness.results, [false]);
      expect(panel, findsNothing);
    });

    testWidgets('a tap on the dimmed page answers false', (tester) async {
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(harness.results, [false]);
      expect(panel, findsNothing);
    });

    testWidgets('dragging the panel down answers false', (tester) async {
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      await tester.fling(panel, const Offset(0, 400), 1500);
      await tester.pumpAndSettle();

      expect(harness.results, [false]);
      expect(panel, findsNothing);
    });

    testWidgets('system back closes it, and is used up doing so', (
      tester,
    ) async {
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(harness.results, [false]);
      expect(panel, findsNothing);
      // Still on the page, not left through the router.
      expect(ask, findsOneWidget);
    });

    testWidgets('removing the scope while it is open closes it, answering '
        'false', (tester) async {
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);

      harness.showScope.value = false;
      await tester.pump();
      await tester.pump();

      expect(panel, findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(harness.results, [false]);
      expect(tester.takeException(), isNull);
    });
  });

  group('how it looks', () {
    testWidgets(
      'the confirm button is the dark red, on an orange-tinted tile',
      (tester) async {
        await pumpScope(tester, harness);
        await tester.tap(ask);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<FilledButton>(confirmButton)
              .style
              ?.backgroundColor
              ?.resolve({}),
          AppColors.primaryDark,
        );
        final tile = tester.widget<Container>(
          find.byKey(const Key('confirm-panel-icon')),
        );
        expect((tile.decoration as BoxDecoration).color, AppColors.peachMist);
      },
    );

    testWidgets('a destructive one is red all through', (tester) async {
      harness.destructive = true;
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(confirmButton)
            .style
            ?.backgroundColor
            ?.resolve({}),
        AppColors.error,
      );
      final tile = tester.widget<Container>(
        find.byKey(const Key('confirm-panel-icon')),
      );
      expect(
        (tile.decoration as BoxDecoration).color,
        AppColors.errorBackground,
      );
    });

    testWidgets('both buttons are 48 px tall and share the width', (
      tester,
    ) async {
      await pumpScope(tester, harness);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      expect(tester.getSize(confirmButton).height, 48);
      expect(tester.getSize(cancelButton).height, 48);
      expect(
        tester.getSize(confirmButton).width,
        tester.getSize(cancelButton).width,
      );
    });

    testWidgets('keeps its buttons on screen, without overflowing, at a large '
        'font size', (tester) async {
      await pumpScope(tester, harness, textScale: 2);
      await tester.tap(ask);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(confirmButton).dy,
        lessThanOrEqualTo(screenHeight(tester)),
      );
      expect(tester.getTopLeft(panel).dy, greaterThanOrEqualTo(0));
    });
  });
}
