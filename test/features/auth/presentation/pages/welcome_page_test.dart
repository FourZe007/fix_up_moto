import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/welcome_page.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_logo.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/welcome_feature_carousel.dart';

/// A phone-sized screen, [width] x [height] logical pixels at a pixel ratio of 3.
void usePhone(WidgetTester tester, {double width = 360, double height = 800}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Larger system text, as a member can set in their phone's settings.
void useTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// The welcome page with stand-ins for the two places it leads to.
Future<void> pumpWelcome(
  WidgetTester tester, {
  ThemeData? theme,
  bool disableAnimations = false,
  bool settle = true,
}) async {
  final router = GoRouter(
    initialLocation: RouteNames.welcome,
    routes: [
      GoRoute(path: RouteNames.welcome, builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: RouteNames.register,
        builder: (_, _) => const Scaffold(body: Text('register-page')),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, _) => const Scaffold(body: Text('login-page')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: theme,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  final logoBox = find.byKey(const Key('auth-logo-box'));
  final getStarted = find.byKey(const Key('welcome-get-started'));
  final masuk = find.byKey(const Key('welcome-login'));
  final headline = find.text('Servis motor jadi lebih mudah & terpercaya');

  final carousel = find.byKey(const Key('welcome-carousel'));
  // The first card of the carousel, which is the one showing on arrival.
  const firstFeature = 'Booking servis';

  group('the logo', () {
    testWidgets('is the large one, centred at the top', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester);

      expect(find.byType(AuthLogo), findsOneWidget);
      // Larger than the 144 it was first shown at, and in the middle.
      expect(tester.getSize(logoBox), const Size(220, 110));
      expect(tester.getCenter(logoBox).dx, 180);
    });

    testWidgets('is above the headline, which is above the carousel, which is '
        'above the button', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester);

      final tops = [
        tester.getTopLeft(logoBox).dy,
        tester.getTopLeft(headline).dy,
        tester.getTopLeft(carousel).dy,
        tester.getTopLeft(getStarted).dy,
      ];

      expect(tops, orderedEquals([...tops]..sort()));
      expect(tops.toSet().length, tops.length);
    });
  });

  group('the content', () {
    testWidgets('says what the app is, with a line under it', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester);

      expect(headline, findsOneWidget);
      expect(
        find.textContaining('dalam satu aplikasi'),
        findsOneWidget,
        reason: 'supporting line',
      );
    });

    testWidgets('names the chat assistant Fima, as the rest of the app does', (
      tester,
    ) async {
      usePhone(tester);
      await pumpWelcome(tester);

      expect(find.textContaining('dengan Fima dalam satu aplikasi'), findsOne);
      expect(find.textContaining('Mika'), findsNothing);
    });

    testWidgets('shows the feature carousel, full width, on its first card', (
      tester,
    ) async {
      usePhone(tester);
      await pumpWelcome(tester);

      expect(find.byType(WelcomeFeatureCarousel), findsOneWidget);
      expect(find.text(firstFeature), findsOneWidget);
      // As wide as the page's content, not a third of it.
      expect(tester.getSize(carousel).width, 360 - 48);
    });
  });

  group('the colour', () {
    final wash = find.byKey(const Key('welcome-wash'));

    testWidgets('a warm orange wash fades in from the top edge', (
      tester,
    ) async {
      usePhone(tester);
      await pumpWelcome(tester);

      final gradient =
          (tester.widget<DecoratedBox>(wash).decoration as BoxDecoration)
                  .gradient
              as LinearGradient;

      // Brand orange at both ends, strong at the top and gone at the bottom —
      // not transparent black, which would grey the fade.
      expect(gradient.begin, Alignment.topCenter);
      expect(
        gradient.colors.first.withValues(alpha: 1),
        AppColors.primaryLight,
      );
      expect(gradient.colors.last.withValues(alpha: 1), AppColors.primaryLight);
      expect(gradient.colors.first.a, greaterThan(0.2));
      expect(gradient.colors.last.a, 0);
      // It reaches the very top of the screen, under the status bar.
      expect(tester.getTopLeft(wash).dy, 0);
    });

    testWidgets('leaves the page background to the theme', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester, theme: AppTheme.light);

      final scaffold = find.byType(Scaffold);
      expect(tester.widget<Scaffold>(scaffold).backgroundColor, isNull);
      expect(
        Theme.of(tester.element(scaffold)).scaffoldBackgroundColor,
        AppColors.backgroundLight,
      );
    });
  });

  group('the social footer', () {
    final instagram = find.byKey(const Key('welcome-social-instagram'));
    final tiktok = find.byKey(const Key('welcome-social-tiktok'));

    testWidgets('is the last thing on the page, under "Masuk"', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester);

      expect(find.text('Ikuti kami'), findsOneWidget);
      expect(instagram, findsOneWidget);
      expect(tiktok, findsOneWidget);

      // "Get started", then "Masuk", then the footer: quiet, so it never
      // competes with the button the page exists for.
      expect(
        tester.getTopLeft(instagram).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(masuk).dy),
      );
      expect(
        tester.getTopLeft(masuk).dy,
        greaterThan(tester.getBottomLeft(getStarted).dy),
      );
    });

    testWidgets('is centred, as a group, on the same line as "Get started"', (
      tester,
    ) async {
      usePhone(tester);
      await pumpWelcome(tester);

      final axis = tester.getCenter(getStarted).dx;
      // From the label's left edge to the last icon's right edge.
      final group = tester
          .getRect(find.text('Ikuti kami'))
          .expandToInclude(tester.getRect(tiktok));

      expect(group.center.dx, closeTo(axis, 0.5));
    });
  });

  group('the buttons', () {
    testWidgets('"Get started" is as wide as the screen, less the page '
        'margins', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester);

      final rect = tester.getRect(getStarted);
      expect(rect.left, 24);
      expect(rect.width, 360 - 48);
    });

    testWidgets('"Get started" opens Register', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester);

      await tester.tap(getStarted);
      await tester.pumpAndSettle();

      expect(find.text('register-page'), findsOneWidget);
    });

    testWidgets('"Masuk" opens Login', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester);

      expect(find.text('Sudah punya akun?'), findsOneWidget);
      await tester.tap(masuk);
      await tester.pumpAndSettle();

      expect(find.text('login-page'), findsOneWidget);
    });

    testWidgets('keep the welcome screen underneath, so back returns to it', (
      tester,
    ) async {
      usePhone(tester);
      await pumpWelcome(tester);

      for (final (button, page) in [
        (getStarted, 'register-page'),
        (masuk, 'login-page'),
      ]) {
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text(page), findsOneWidget);

        // What the back arrow and Android's back button both do.
        GoRouter.of(tester.element(find.text(page))).pop();
        await tester.pumpAndSettle();
        expect(
          getStarted,
          findsOneWidget,
          reason: 'back on the welcome screen',
        );
      }
    });

    testWidgets('"Get started" is the orange brand button', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester, theme: AppTheme.light);

      final material = tester.widget<Material>(
        find.descendant(of: getStarted, matching: find.byType(Material)).first,
      );
      expect(material.color, AppColors.primary);
    });
  });

  group('on a small screen or with large text', () {
    testWidgets('does not overflow, and the buttons stay on screen', (
      tester,
    ) async {
      usePhone(tester, width: 320, height: 480);
      useTextScale(tester, 1.5);
      await pumpWelcome(tester);

      expect(tester.takeException(), isNull);
      // Pinned: below the content, not scrolled away with it.
      expect(tester.getRect(getStarted).bottom, lessThanOrEqualTo(480));
      expect(tester.getRect(masuk).bottom, lessThanOrEqualTo(480));
      expect(
        tester
            .getRect(find.byKey(const Key('welcome-social-instagram')))
            .bottom,
        lessThanOrEqualTo(480),
      );
    });

    testWidgets('scrolls to reach the carousel', (tester) async {
      usePhone(tester, width: 320, height: 480);
      useTextScale(tester, 1.5);
      await pumpWelcome(tester);

      await tester.ensureVisible(carousel);
      await tester.pumpAndSettle();

      expect(tester.getRect(carousel).bottom, lessThanOrEqualTo(480));
      expect(tester.takeException(), isNull);
    });

    testWidgets('spreads out to fill a tall screen instead of bunching at the '
        'top', (tester) async {
      // Tall enough that there is room to spare even with the test font, which
      // is far wider than Poppins and so makes the headline wrap onto more
      // lines than it will on a phone.
      usePhone(tester, height: 1200);
      await pumpWelcome(tester);

      // The logo is not jammed against the top, and the content does not touch
      // the buttons.
      expect(tester.getTopLeft(logoBox).dy, greaterThan(60));
      expect(
        tester.getTopLeft(getStarted).dy - tester.getBottomLeft(carousel).dy,
        greaterThan(24),
      );
    });
  });

  group('the entrance', () {
    testWidgets('starts hidden and fades in', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester, settle: false);

      double opacityAround(Finder finder) => tester
          .widget<Opacity>(
            find.ancestor(of: finder, matching: find.byType(Opacity)).first,
          )
          .opacity;

      expect(opacityAround(getStarted), 0);

      await tester.pumpAndSettle();
      expect(opacityAround(getStarted), 1);
      expect(opacityAround(headline), 1);
    });

    testWidgets('is skipped when the OS asks for no animations', (
      tester,
    ) async {
      usePhone(tester);
      await pumpWelcome(tester, disableAnimations: true, settle: false);
      await tester.pump();

      final opacity = tester
          .widget<Opacity>(
            find.ancestor(of: getStarted, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(opacity, 1);
    });
  });

  group('in dark app mode', () {
    testWidgets('shows the carousel without trouble', (tester) async {
      usePhone(tester);
      await pumpWelcome(tester, theme: AppTheme.dark);

      expect(find.text(firstFeature), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
