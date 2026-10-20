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
      expect(tester.getSize(logoBox), const Size(200, 100));
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
