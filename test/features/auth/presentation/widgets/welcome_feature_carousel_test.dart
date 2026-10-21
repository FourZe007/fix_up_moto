import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/welcome_feature_carousel.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A phone-sized screen, [width] x [height] logical pixels at a pixel ratio of 3.
void usePhone(WidgetTester tester, {double width = 360, double height = 800}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void useTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Where the pager starts. It begins thousands of pages in (so there is a lot
/// to swipe back through), and the tests count pages from there.
late double origin;

/// The carousel in a page with 24 px of padding, as on the welcome screen.
Future<void> pumpCarousel(
  WidgetTester tester, {
  ThemeData? theme,
  bool disableAnimations = false,
}) async {
  usePhone(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topCenter,
            child: WelcomeFeatureCarousel(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  origin = tester
      .widget<PageView>(find.byKey(const Key('welcome-carousel')))
      .controller!
      .page!;
}

void main() {
  const features = WelcomeFeatureCarousel.features;
  final carousel = find.byKey(const Key('welcome-carousel'));
  Finder title(int i) => find.text(features[i].title);

  /// The pager's position: 0.0 on the first card, 1.0 on the next, and so on,
  /// counting on past the last card (the carousel is endless) and below 0 for
  /// back before the first.
  double page(WidgetTester tester) =>
      tester.widget<PageView>(carousel).controller!.page! - origin;

  /// A swipe from right to left (to the next card) or left to right.
  Future<void> swipe(WidgetTester tester, {bool forward = true}) async {
    await tester.drag(carousel, Offset(forward ? -300 : 300, 0));
    await tester.pumpAndSettle();
  }

  /// The width of the dot for card [i]: wide when it is the current one. Read
  /// from the dot itself, because its rendered size includes its margins.
  double dotWidth(WidgetTester tester, int i) => tester
      .widget<AnimatedContainer>(find.byKey(Key('welcome-dot-$i')))
      .constraints!
      .maxWidth;

  /// Waits one autoplay interval and lets the slide it starts finish.
  Future<void> autoAdvance(WidgetTester tester) async {
    await tester.pump(WelcomeFeatureCarousel.autoPlayInterval);
    await tester.pumpAndSettle();
  }

  test('the features are the three the app is known for, each with a line', () {
    expect(features.map((f) => f.title), [
      'Booking servis',
      'Poin & voucher',
      'Chat dengan Fima',
    ]);
    for (final feature in features) {
      expect(feature.description, isNotEmpty);
    }
  });

  test('autoplay keeps the pace of the promo carousel on Home', () {
    expect(WelcomeFeatureCarousel.autoPlayInterval, const Duration(seconds: 4));
    expect(
      WelcomeFeatureCarousel.slideDuration,
      const Duration(milliseconds: 400),
    );
  });

  group('a card', () {
    testWidgets('takes the whole width, one at a time', (tester) async {
      await pumpCarousel(tester);

      // The carousel is the page's content width...
      expect(tester.getSize(carousel).width, 360 - 48);
      // ...and the card fills it, less a 4 px margin each side, with the next
      // card not squeezed in beside it.
      final card = tester.getRect(
        find.ancestor(of: title(0), matching: find.byType(DecoratedBox)).first,
      );
      expect(card.width, 360 - 48 - 8);
      expect(title(0), findsOneWidget);
      expect(title(1), findsNothing);
    });

    testWidgets('has its icon, title and description', (tester) async {
      await pumpCarousel(tester);

      expect(find.byIcon(features[0].icon), findsOneWidget);
      expect(title(0), findsOneWidget);
      expect(find.text(features[0].description), findsOneWidget);
    });

    testWidgets('puts a white icon on a solid brand-orange tile', (
      tester,
    ) async {
      await pumpCarousel(tester);

      final icon = find.byIcon(features[0].icon);
      final tile =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(of: icon, matching: find.byType(DecoratedBox))
                        .first,
                  )
                  .decoration
              as BoxDecoration;

      expect(tile.color, AppColors.primary);
      expect(tester.widget<Icon>(icon).color, AppColors.textOnPrimary);
    });

    testWidgets('sets its description at 14 px', (tester) async {
      await pumpCarousel(tester);

      final description = tester.widget<Text>(
        find.text(features[0].description),
      );
      expect(description.style!.fontSize, 14);
    });
  });

  group('the dots', () {
    testWidgets('are one per card, the first one wide', (tester) async {
      await pumpCarousel(tester);

      expect([for (var i = 0; i < 3; i++) dotWidth(tester, i)], [24, 8, 8]);
    });

    testWidgets('follow the card in view, in the brand colour', (tester) async {
      await pumpCarousel(tester);
      await swipe(tester);

      expect([for (var i = 0; i < 3; i++) dotWidth(tester, i)], [8, 24, 8]);

      Color dotColor(int i) =>
          (tester
                      .widget<AnimatedContainer>(
                        find.byKey(Key('welcome-dot-$i')),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(dotColor(1), AppColors.primary);
      expect(dotColor(0), AppColors.grey400);
    });
  });

  group('swiping by hand', () {
    testWidgets('moves to the next card and back', (tester) async {
      await pumpCarousel(tester);

      await swipe(tester);
      expect(title(1), findsOneWidget);
      expect(title(0), findsNothing);

      await swipe(tester, forward: false);
      expect(title(0), findsOneWidget);
      expect(title(1), findsNothing);
    });

    testWidgets('goes round: past the last card is the first', (tester) async {
      await pumpCarousel(tester);

      await swipe(tester);
      await swipe(tester);
      expect(title(2), findsOneWidget);

      await swipe(tester);
      expect(title(0), findsOneWidget);
      expect(dotWidth(tester, 0), 24);
    });

    testWidgets('goes round the other way too: before the first is the last', (
      tester,
    ) async {
      await pumpCarousel(tester);

      await swipe(tester, forward: false);

      expect(title(2), findsOneWidget);
      expect(dotWidth(tester, 2), 24);
    });
  });

  group('autoplay', () {
    testWidgets('waits the full interval before the first move', (
      tester,
    ) async {
      await pumpCarousel(tester);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(page(tester), 0);
      expect(title(0), findsOneWidget);
    });

    testWidgets('moves on to the next card by itself', (tester) async {
      await pumpCarousel(tester);

      await autoAdvance(tester);

      expect(page(tester), 1);
      expect(title(1), findsOneWidget);
      expect(dotWidth(tester, 1), 24);
    });

    testWidgets('keeps going forward past the last card instead of rewinding '
        'to the first', (tester) async {
      await pumpCarousel(tester);

      for (var i = 0; i < 3; i++) {
        await autoAdvance(tester);
      }

      // Three moves forward: back on the first card, having gone round — not
      // having travelled back across the other two.
      expect(page(tester), 3);
      expect(title(0), findsOneWidget);
      expect(dotWidth(tester, 0), 24);

      // And it carries on.
      await autoAdvance(tester);
      expect(page(tester), 4);
      expect(title(1), findsOneWidget);
    });

    testWidgets('slides over 400 ms rather than jumping', (tester) async {
      await pumpCarousel(tester);

      await tester.pump(WelcomeFeatureCarousel.autoPlayInterval);
      await tester.pump(const Duration(milliseconds: 200));

      // Part of the way there: neither card is fully in view.
      expect(page(tester), allOf(greaterThan(0), lessThan(1)));
      await tester.pumpAndSettle();
      expect(page(tester), 1);
    });

    testWidgets('does not move while a finger is on the carousel', (
      tester,
    ) async {
      await pumpCarousel(tester);

      final finger = await tester.startGesture(tester.getCenter(carousel));
      await finger.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(seconds: 10));

      // Still where the finger left it: a few pixels in, nowhere near the next
      // card, though two intervals have passed.
      expect(page(tester), lessThan(0.2));

      await finger.up();
      await tester.pumpAndSettle();
      expect(page(tester), 0);
    });

    testWidgets('starts counting again once the swipe has settled', (
      tester,
    ) async {
      await pumpCarousel(tester);

      final finger = await tester.startGesture(tester.getCenter(carousel));
      await finger.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(seconds: 10));
      await finger.up();
      await tester.pumpAndSettle();
      expect(page(tester), 0);

      await tester.pump(const Duration(seconds: 3));
      expect(page(tester), 0, reason: 'a full interval has not passed yet');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(page(tester), 1);
    });

    testWidgets('a swipe gives the card a full interval, not what was left '
        'on the clock', (tester) async {
      await pumpCarousel(tester);

      // 3 s in, one second before autoplay would have moved on, swipe.
      await tester.pump(const Duration(seconds: 3));
      await swipe(tester);
      expect(page(tester), 1);

      // The old clock would have fired by now; the restarted one has not.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(page(tester), 1);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(page(tester), 2);
    });

    testWidgets('is off when the OS asks for no animations', (tester) async {
      await pumpCarousel(tester, disableAnimations: true);

      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(page(tester), 0);
      // Swiping by hand still works.
      await swipe(tester);
      expect(title(1), findsOneWidget);
    });

    testWidgets('stops when the carousel is removed', (tester) async {
      await pumpCarousel(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));

      // A timer left running would be reported as pending when the test ends,
      // and would have called into the disposed controller by now.
      expect(tester.takeException(), isNull);
    });
  });

  group('large text and small screens', () {
    testWidgets('grow the carousel instead of overflowing', (tester) async {
      await pumpCarousel(tester);
      final normal = tester.getSize(carousel).height;

      useTextScale(tester, 2.0);
      await pumpCarousel(tester);

      expect(tester.getSize(carousel).height, greaterThan(normal));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keep every card inside the carousel at 1.5x text', (
      tester,
    ) async {
      useTextScale(tester, 1.5);
      await pumpCarousel(tester);

      for (var i = 0; i < features.length; i++) {
        final cardBottom = tester
            .getRect(
              find
                  .ancestor(of: title(i), matching: find.byType(DecoratedBox))
                  .first,
            )
            .bottom;
        expect(cardBottom, lessThanOrEqualTo(tester.getRect(carousel).bottom));
        await swipe(tester);
      }
      expect(tester.takeException(), isNull);
    });
  });

  for (final MapEntry(key: mode, value: theme) in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    group('in $mode app mode', () {
      testWidgets('every card is readable', (tester) async {
        await pumpCarousel(tester, theme: theme);

        for (var i = 0; i < features.length; i++) {
          final card =
              tester
                      .widget<DecoratedBox>(
                        find
                            .ancestor(
                              of: title(i),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          // Peach in both modes, like the Membership tab's point card.
          expect(card.color, AppColors.peachLight);

          for (final text in [features[i].title, features[i].description]) {
            final color = tester.widget<Text>(find.text(text)).style!.color!;
            expect(
              contrast(color, card.color!),
              greaterThanOrEqualTo(4.5),
              reason: '"$text" on the $mode card',
            );
          }
          await swipe(tester);
        }
      });
    });
  }
}
