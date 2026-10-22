import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/complete_google_profile_page.dart';
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

/// How visible a hint is. Flutter keeps a hint in the tree while hiding it (an
/// opacity of 0), so finding its text does not say whether it can be seen.
double hintOpacity(WidgetTester tester, String hint) => tester
    .widget<AnimatedOpacity>(
      find
          .ancestor(of: find.text(hint), matching: find.byType(AnimatedOpacity))
          .first,
    )
    .opacity;

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

    testWidgets('shows +62 and an example number before the phone field is '
        'tapped, in place of the phone icon', (tester) async {
      await pumpPage(tester, const LoginPage());

      expect(find.text('+62'), findsOneWidget);
      expect(find.text('81234567889'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);
      // The label stays, so the field keeps its name once something is typed.
      expect(find.text('Phone number'), findsOneWidget);
    });

    testWidgets('drops a typed leading 0 and signs in with the bare number', (
      tester,
    ) async {
      final bloc = unauthenticatedBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: bloc,
            child: const LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, '0812-3456-7890');
      await tester.enterText(fields.last, 'Password1');
      // What the field holds is what will be sent, with the +62 in front of it.
      expect(find.text('81234567890'), findsOneWidget);

      await tapText(tester, 'Sign In');

      verify(
        () => bloc.add(
          const AuthLoginRequested(phone: '81234567890', password: 'Password1'),
        ),
      ).called(1);
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

    testWidgets('shows +62 and an example number in place of the phone icon, '
        'like Login', (tester) async {
      await pumpPage(tester, const RegisterPage());

      expect(find.text('+62'), findsOneWidget);
      expect(hintOpacity(tester, '81234567889'), 1);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);
      expect(find.text('Phone number'), findsOneWidget);
    });

    testWidgets('gives every field a hint, visible before it is tapped', (
      tester,
    ) async {
      await pumpPage(tester, const RegisterPage());

      for (final hint in [
        'Budi Santoso',
        '81234567889',
        'you@example.com',
        'Min. 8 karakter',
        'Ulangi password',
      ]) {
        expect(hintOpacity(tester, hint), 1, reason: hint);
      }
    });

    testWidgets('drops a typed leading 0 in the phone field, as Login does', (
      tester,
    ) async {
      await pumpPage(tester, const RegisterPage());

      await tester.enterText(
        find.byType(TextFormField).at(1),
        '0812-3456-7890',
      );

      expect(find.text('81234567890'), findsOneWidget);
    });

    group('the error snackbar', () {
      /// The page, then an [AuthError] arriving from the bloc.
      Future<void> pumpWithError(WidgetTester tester, String message) async {
        final bloc = MockAuthBloc();
        whenListen(
          bloc,
          Stream<AuthState>.fromIterable([AuthError(message)]),
          initialState: const AuthUnauthenticated(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<AuthBloc>.value(
              value: bloc,
              child: const RegisterPage(),
            ),
          ),
        );
        await tester.pump(); // the error arrives
        await tester.pump(const Duration(milliseconds: 300)); // snackbar in
      }

      testWidgets('tidies a reason the backend shouted in capitals', (
        tester,
      ) async {
        await pumpWithError(tester, 'NO HP SUDAH TERDAFTAR');

        expect(find.text('No Hp Sudah Terdaftar'), findsOneWidget);
        expect(find.text('NO HP SUDAH TERDAFTAR'), findsNothing);
      });

      testWidgets('leaves wording that is not shouted exactly as it is', (
        tester,
      ) async {
        await pumpWithError(tester, 'No internet connection');

        expect(find.text('No internet connection'), findsOneWidget);
      });

      testWidgets('has a close button at the centre right', (tester) async {
        await pumpWithError(tester, 'NO HP SUDAH TERDAFTAR');

        final snackBar = find.byType(SnackBar);
        final close = find.descendant(
          of: snackBar,
          matching: find.byIcon(Icons.close),
        );

        expect(close, findsOneWidget);
        // At the right end...
        expect(
          tester.getCenter(close).dx,
          greaterThan(tester.getCenter(snackBar).dx),
        );
        expect(
          tester.getTopRight(snackBar).dx - tester.getCenter(close).dx,
          lessThan(48),
        );
        // ...and halfway down.
        expect(
          (tester.getCenter(close).dy - tester.getCenter(snackBar).dy).abs(),
          lessThan(2),
        );
      });

      testWidgets('the close button dismisses it at once', (tester) async {
        await pumpWithError(tester, 'NO HP SUDAH TERDAFTAR');

        await tester.tap(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('goes by itself after ten seconds, untouched', (
        tester,
      ) async {
        await pumpWithError(tester, 'NO HP SUDAH TERDAFTAR');

        // Set to time out after ten seconds, and not to stay put.
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 10));
        expect(snackBar.persist, isFalse);

        // Still there well into its time...
        await tester.pump(const Duration(seconds: 5));
        expect(find.byType(SnackBar), findsOneWidget);

        // ...and gone once it is up, with nobody having tapped anything.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    group('the confirm password check', () {
      /// The page with its bloc, the keyboard already up (so nothing rebuilds
      /// the page between typing the password and tapping the button), and the
      /// form filled in with [confirmation] as the second password.
      Future<MockAuthBloc> fillWithKeyboardUp(
        WidgetTester tester, {
        required String confirmation,
      }) async {
        final bloc = unauthenticatedBloc();
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<AuthBloc>.value(
              value: bloc,
              child: const RegisterPage(),
            ),
          ),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Budi Santoso');
        await tester.enterText(fields.at(1), '0812-3456-7890');
        await tester.enterText(fields.at(3), 'Password1');
        await tester.enterText(fields.at(4), confirmation);
        await tapText(tester, 'Buat Akun');
        return bloc;
      }

      testWidgets('accepts an identical confirmation even while the keyboard '
          'stays up, and signs up with the bare number', (tester) async {
        final bloc = await fillWithKeyboardUp(
          tester,
          confirmation: 'Password1',
        );

        expect(find.text('Passwords do not match'), findsNothing);
        verify(
          () => bloc.add(
            const AuthRegisterRequested(
              name: 'Budi Santoso',
              phone: '81234567890',
              email: '',
              password: 'Password1',
            ),
          ),
        ).called(1);
      });

      testWidgets('still rejects a confirmation that differs, and does not '
          'sign up', (tester) async {
        final bloc = await fillWithKeyboardUp(
          tester,
          confirmation: 'Password2',
        );

        expect(find.text('Passwords do not match'), findsOneWidget);
        // Same event the passing test expects, so this cannot pass by the
        // event merely differing in some detail.
        verifyNever(
          () => bloc.add(
            const AuthRegisterRequested(
              name: 'Budi Santoso',
              phone: '81234567890',
              email: '',
              password: 'Password1',
            ),
          ),
        );
      });
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

  group('one failure, one snackbar', () {
    /// Opens [pages] in order, each pushed over the last (the way the app
    /// stacks them), makes the bloc emit a single [AuthError], and returns the
    /// text of every snackbar that comes up. Each is dismissed in turn so that
    /// whatever is queued behind it slides in and is counted too.
    Future<List<String>> snackBarsAfterError(
      WidgetTester tester,
      List<String> pages,
    ) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      final bloc = MockAuthBloc();
      whenListen(
        bloc,
        controller.stream,
        initialState: const AuthUnauthenticated(),
      );

      final router = GoRouter(
        initialLocation: pages.first,
        routes: [
          GoRoute(path: RouteNames.login, builder: (_, _) => const LoginPage()),
          GoRoute(
            path: RouteNames.register,
            builder: (_, _) => const RegisterPage(),
          ),
          GoRoute(
            path: RouteNames.completeGoogleProfile,
            builder: (_, state) => CompleteGoogleProfilePage(
              identity: state.extra as GoogleAccountIdentity,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: bloc,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      for (final page in pages.skip(1)) {
        unawaited(
          router.push(
            page,
            extra: GoogleAccountIdentity(
              displayName: 'Budi',
              email: 'budi@example.com',
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      controller.add(const AuthError('NO HP SUDAH TERDAFTAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      );
      final seen = <String>[];
      while (find.byType(SnackBar).evaluate().isNotEmpty && seen.length < 6) {
        seen.add(
          tester
              .widget<Text>(
                find
                    .descendant(
                      of: find.byType(SnackBar),
                      matching: find.byType(Text),
                    )
                    .first,
              )
              .data!,
        );
        messenger.hideCurrentSnackBar();
        await tester.pumpAndSettle();
      }
      return seen;
    }

    testWidgets('Login on its own reports an error once', (tester) async {
      final seen = await snackBarsAfterError(tester, [RouteNames.login]);

      expect(seen, ['NO HP SUDAH TERDAFTAR']);
    });

    testWidgets('Register opened from Login reports it once, not once more '
        'from the Login underneath', (tester) async {
      final seen = await snackBarsAfterError(tester, [
        RouteNames.login,
        RouteNames.register,
      ]);

      // Register's own, tidied — not Login's raw one as well.
      expect(seen, ['No Hp Sudah Terdaftar']);
    });

    testWidgets('the Google profile page opened from Login reports it once '
        'too', (tester) async {
      final seen = await snackBarsAfterError(tester, [
        RouteNames.login,
        RouteNames.completeGoogleProfile,
      ]);

      expect(seen, ['NO HP SUDAH TERDAFTAR']);
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
