import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/login_page.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/register_page.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_logo.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

MockAuthBloc unauthenticatedBloc([
  AuthState state = const AuthUnauthenticated(),
]) {
  final authBloc = MockAuthBloc();
  whenListen(authBloc, const Stream<AuthState>.empty(), initialState: state);
  return authBloc;
}

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  AuthState state = const AuthUnauthenticated(),
  ThemeData? theme,

  /// False for a state that shows the sign-in spinner, which animates forever
  /// and would keep pumpAndSettle from ever returning.
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: BlocProvider<AuthBloc>.value(
        value: unauthenticatedBloc(state),
        child: page,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Login and Register under a real router, to test where their links go,
/// opened at [at] with each of [then] pushed on top. `welcome-page` stands in
/// for the welcome screen.
Future<GoRouter> pumpRouter(
  WidgetTester tester, {
  required String at,
  List<String> then = const [],
}) async {
  final router = GoRouter(
    initialLocation: at,
    routes: [
      GoRoute(
        path: RouteNames.welcome,
        builder: (_, _) => const Scaffold(body: Text('welcome-page')),
      ),
      GoRoute(path: RouteNames.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: RouteNames.register,
        builder: (_, _) => const RegisterPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: unauthenticatedBloc(),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  for (final location in then) {
    unawaited(router.push(location));
    await tester.pumpAndSettle();
  }
  return router;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  /// The logo now lives on the welcome screen only.
  final logo = find.byType(AuthLogo);

  /// The page is the app's normal light grey, not a colour of its own: the
  /// Scaffold sets none, so it takes the theme's.
  void expectThemeBackground(WidgetTester tester) {
    final scaffold = find.byType(Scaffold);

    expect(tester.widget<Scaffold>(scaffold).backgroundColor, isNull);
    expect(
      Theme.of(tester.element(scaffold)).scaffoldBackgroundColor,
      AppColors.backgroundLight,
    );
  }

  group('page background', () {
    testWidgets('LoginPage is the app light grey', (tester) async {
      await pumpPage(tester, const LoginPage(), theme: AppTheme.light);

      expectThemeBackground(tester);
    });

    testWidgets('RegisterPage is the app light grey', (tester) async {
      await pumpPage(tester, const RegisterPage(), theme: AppTheme.light);

      expectThemeBackground(tester);
    });
  });

  group('LoginPage', () {
    testWidgets('has no logo, so the headline leads', (tester) async {
      await pumpPage(tester, const LoginPage());

      expect(logo, findsNothing);
      expect(find.byKey(const Key('auth-logo-image')), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('keeps the form on screen', (tester) async {
      await pumpPage(tester, const LoginPage());

      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('still has no logo while a login is in flight', (tester) async {
      await pumpPage(
        tester,
        const LoginPage(),
        state: const AuthLoading(),
        settle: false,
      );

      expect(logo, findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('does not overflow in dark mode on a short screen', (
      tester,
    ) async {
      // Short, not narrow: the test font is wide enough that the existing
      // "Tidak punya akun?" row overflows at phone width. What this checks is
      // the vertical fit.
      tester.view.physicalSize = const Size(700, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpPage(tester, const LoginPage(), theme: ThemeData.dark());

      expect(tester.takeException(), isNull);
    });
  });

  group('RegisterPage', () {
    testWidgets('has no logo, so the headline leads', (tester) async {
      await pumpPage(tester, const RegisterPage());

      expect(logo, findsNothing);
      expect(find.byKey(const Key('auth-logo-image')), findsNothing);
      expect(find.text('Join FixUp Moto'), findsOneWidget);
    });

    testWidgets('keeps the form on screen', (tester) async {
      await pumpPage(tester, const RegisterPage());

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow in dark mode on a short screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpPage(tester, const RegisterPage(), theme: ThemeData.dark());

      expect(tester.takeException(), isNull);
    });
  });

  group("Register's 'Masuk disini' link", () {
    testWidgets('goes back to the Login underneath when it was opened from '
        'Login', (tester) async {
      await pumpRouter(tester, at: RouteNames.login);
      await tapText(tester, 'Daftar disini');
      expect(find.byType(RegisterPage), findsOneWidget);

      await tapText(tester, 'Masuk disini');

      expect(find.byType(RegisterPage), findsNothing);
      // The Login that was already there, not a second one on top of it.
      expect(find.byType(LoginPage, skipOffstage: false), findsOneWidget);
    });

    testWidgets('swaps Register for Login when it was opened from the welcome '
        'screen, which stays underneath', (tester) async {
      final router = await pumpRouter(
        tester,
        at: RouteNames.welcome,
        then: [RouteNames.register],
      );

      await tapText(tester, 'Masuk disini');

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(RegisterPage, skipOffstage: false), findsNothing);

      // Back from that Login is the welcome screen, with no Register left
      // behind on the stack to come back to.
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('welcome-page'), findsOneWidget);
      expect(router.canPop(), isFalse);
    });

    testWidgets('goes to Login when Register was opened with nothing under '
        'it', (tester) async {
      await pumpRouter(tester, at: RouteNames.register);
      expect(find.byType(LoginPage), findsNothing);

      await tapText(tester, 'Masuk disini');

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);
    });
  });

  group("Login's 'Daftar disini' link", () {
    testWidgets('opens Register on top of Login, so back returns to Login', (
      tester,
    ) async {
      final router = await pumpRouter(
        tester,
        at: RouteNames.welcome,
        then: [RouteNames.login],
      );

      await tapText(tester, 'Daftar disini');
      expect(find.byType(RegisterPage), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
