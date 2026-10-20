import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/login_page.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/register_page.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_app_bar.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Login and Register under a real router with a stand-in welcome screen at
/// the root, opened at [at] and then with each of [then] pushed on top.
Future<GoRouter> pumpAt(
  WidgetTester tester, {
  required String at,
  List<String> then = const [],
  AuthState state = const AuthUnauthenticated(),
  Stream<AuthState> states = const Stream<AuthState>.empty(),
  ThemeData? theme,
  bool settle = true,
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

  final bloc = MockAuthBloc();
  whenListen(bloc, states, initialState: state);

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(theme: theme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  for (final location in then) {
    unawaited(router.push(location));
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(seconds: 1));
  }
  return router;
}

void main() {
  final appBar = find.byType(AppBar);
  final backArrow = find.descendant(
    of: appBar,
    matching: find.widgetWithIcon(IconButton, Icons.arrow_back),
  );
  final welcome = find.text('welcome-page');

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(backArrow);
    await tester.pumpAndSettle();
  }

  // Both screens get the same bar.
  final pages = {
    'LoginPage': (location: RouteNames.login, page: find.byType(LoginPage)),
    'RegisterPage': (
      location: RouteNames.register,
      page: find.byType(RegisterPage),
    ),
  };

  for (final MapEntry(key: name, value: p) in pages.entries) {
    group(name, () {
      testWidgets('has a bar with only a back arrow, no title', (tester) async {
        await pumpAt(tester, at: RouteNames.welcome, then: [p.location]);

        expect(appBar, findsOneWidget);
        expect(backArrow, findsOneWidget);
        expect(tester.widget<AppBar>(appBar).title, isNull);
      });

      testWidgets('has that bar set up like the app\'s other pages: flat, in '
          'the page\'s own colour, with the arrow in the theme\'s text '
          'colour', (tester) async {
        await pumpAt(
          tester,
          at: RouteNames.welcome,
          then: [p.location],
          theme: AppTheme.light,
        );

        final bar = tester.widget<AppBar>(appBar);
        final theme = Theme.of(tester.element(appBar));
        expect(bar.elevation, 0);
        expect(bar.scrolledUnderElevation, 0);
        expect(bar.backgroundColor, theme.scaffoldBackgroundColor);

        final arrow = tester.widget<IconButton>(backArrow);
        expect(
          arrow.style!.foregroundColor!.resolve({}),
          theme.colorScheme.onSurface,
        );
      });

      testWidgets('follows dark mode instead of staying a light-mode colour', (
        tester,
      ) async {
        await pumpAt(
          tester,
          at: RouteNames.welcome,
          then: [p.location],
          theme: AppTheme.dark,
        );

        final theme = Theme.of(tester.element(appBar));
        expect(
          tester.widget<AppBar>(appBar).backgroundColor,
          theme.scaffoldBackgroundColor,
        );
        expect(
          tester
              .widget<IconButton>(backArrow)
              .style!
              .foregroundColor!
              .resolve({}),
          theme.colorScheme.onSurface,
        );
      });

      testWidgets('takes the user back to the welcome screen it was opened '
          'from', (tester) async {
        await pumpAt(tester, at: RouteNames.welcome, then: [p.location]);
        expect(p.page, findsOneWidget);

        await tapBack(tester);

        expect(welcome, findsOneWidget);
        expect(p.page, findsNothing);
      });

      testWidgets('goes to the welcome screen when there is nothing under it '
          'to go back to', (tester) async {
        final router = await pumpAt(tester, at: p.location);
        expect(router.canPop(), isFalse);

        await tapBack(tester);

        expect(welcome, findsOneWidget);
        expect(p.page, findsNothing);
      });

      testWidgets('leaves the headline below the bar, not behind it', (
        tester,
      ) async {
        await pumpAt(tester, at: RouteNames.welcome, then: [p.location]);

        final headline = p == pages['LoginPage']
            ? find.text('Welcome back')
            : find.text('Join FixUp Moto');
        expect(
          tester.getTopLeft(headline).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(appBar).dy),
        );
      });

      testWidgets('is switched off while a request is running, and back on '
          'after', (tester) async {
        final states = StreamController<AuthState>();
        addTearDown(states.close);
        await pumpAt(
          tester,
          at: RouteNames.welcome,
          then: [p.location],
          states: states.stream,
        );
        bool enabled() =>
            tester.widget<IconButton>(backArrow).onPressed != null;
        expect(enabled(), isTrue);

        // A short pump, not pump(): the event needs a moment to reach the bar.
        states.add(const AuthLoading());
        await tester.pump(const Duration(milliseconds: 50));
        expect(enabled(), isFalse);

        states.add(const AuthError('Wrong password'));
        await tester.pump(const Duration(seconds: 1));
        expect(enabled(), isTrue);
      });
    });
  }

  group('back through Register and Login', () {
    testWidgets('Register opened from Login goes back to Login, and then to '
        'Welcome', (tester) async {
      await pumpAt(
        tester,
        at: RouteNames.welcome,
        then: [RouteNames.login, RouteNames.register],
      );
      expect(find.byType(RegisterPage), findsOneWidget);

      await tapBack(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);

      await tapBack(tester);
      expect(welcome, findsOneWidget);
    });

    testWidgets('the system back button does the same as the arrow', (
      tester,
    ) async {
      final router = await pumpAt(
        tester,
        at: RouteNames.welcome,
        then: [RouteNames.login],
      );

      // What Android's back button asks the router to do.
      router.pop();
      await tester.pumpAndSettle();

      expect(welcome, findsOneWidget);
    });
  });

  test('the bar is the standard height, so a Scaffold can use it', () {
    expect(
      const AuthAppBar().preferredSize,
      const Size.fromHeight(kToolbarHeight),
    );
  });
}
