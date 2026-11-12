import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_bloc.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_event.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_state.dart';
import 'package:fix_up_moto/features/password_reset/presentation/pages/reset_password_page.dart';

class MockPasswordResetBloc
    extends MockBloc<PasswordResetEvent, PasswordResetState>
    implements PasswordResetBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

const tMember = PasswordResetMember(
  memberId: '0101202400000014',
  phone: '81234567890',
);

/// What the page needs from the outside, so tests can drive and inspect it.
class Harness {
  final MockPasswordResetBloc bloc;

  /// Pushes states into the page's bloc, as a save would.
  final StreamController<PasswordResetState> states;

  final GoRouter router;

  const Harness(this.bloc, this.states, this.router);
}

/// Opens the page on top of a stand-in Login, the way the app does, so where
/// the member lands afterwards can be checked.
Future<Harness> pumpResetPassword(WidgetTester tester) async {
  final bloc = MockPasswordResetBloc();
  final states = StreamController<PasswordResetState>.broadcast();
  addTearDown(states.close);
  whenListen(bloc, states.stream, initialState: const PasswordResetInitial());
  sl.registerFactory<PasswordResetBloc>(() => bloc);

  final authBloc = MockAuthBloc();
  whenListen(
    authBloc,
    const Stream<AuthState>.empty(),
    initialState: const AuthUnauthenticated(),
  );

  final router = GoRouter(
    initialLocation: RouteNames.login,
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (_, _) => const Scaffold(body: Text('login-page')),
      ),
      GoRoute(
        path: RouteNames.resetPassword,
        builder: (_, state) =>
            ResetPasswordPage(member: state.extra as PasswordResetMember),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  unawaited(router.push(RouteNames.resetPassword, extra: tMember));
  await tester.pumpAndSettle();

  return Harness(bloc, states, router);
}

void main() {
  setUpAll(() => registerFallbackValue(const PasswordResetMemberRequested('')));
  tearDown(() => sl.reset());

  final newField = find.widgetWithText(TextFormField, 'Sandi Baru');
  final confirmField = find.widgetWithText(
    TextFormField,
    'Konfirmasi Sandi Baru',
  );
  final saveButton = find.byKey(const Key('reset-password-save'));

  /// Fills both fields, then presses Simpan.
  Future<void> submit(
    WidgetTester tester, {
    String fresh = 'Baru12345',
    String? confirm,
  }) async {
    await tester.enterText(newField, fresh);
    await tester.enterText(confirmField, confirm ?? fresh);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
  }

  TextField textFieldOf(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      );

  group('what it shows', () {
    testWidgets('says the code was right and for which number, with the '
        'middle of it hidden', (tester) async {
      await pumpResetPassword(tester);

      expect(find.byKey(const Key('reset-password-page')), findsOneWidget);
      expect(find.text('Buat password baru'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('reset-password-subtitle')))
            .data,
        'Kode benar. Pilih password baru untuk +62 812****7890.',
      );
    });

    testWidgets('never shows the whole phone number', (tester) async {
      await pumpResetPassword(tester);

      expect(find.textContaining('81234567890'), findsNothing);
    });

    testWidgets('asks for the new password and its confirmation, and no old '
        'one', (tester) async {
      await pumpResetPassword(tester);

      expect(newField, findsOneWidget);
      expect(confirmField, findsOneWidget);
      expect(find.text('Sandi Lama'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Simpan'), findsOneWidget);
    });

    testWidgets('states the password rule under the field', (tester) async {
      await pumpResetPassword(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('password-rule'))).data,
        'Minimal 8 karakter, ada huruf besar dan angka',
      );
    });

    testWidgets('hides what is typed, behind a toggle, in both fields', (
      tester,
    ) async {
      await pumpResetPassword(tester);

      expect(textFieldOf(tester, newField).obscureText, isTrue);
      expect(textFieldOf(tester, confirmField).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    });

    testWidgets('sits on the same warm wash as Login', (tester) async {
      await pumpResetPassword(tester);

      expect(find.byType(WarmWash), findsOneWidget);
    });
  });

  group('checking the form', () {
    testWidgets('asks for a password when empty, and sends nothing', (
      tester,
    ) async {
      final h = await pumpResetPassword(tester);

      await submit(tester, fresh: '', confirm: '');

      expect(find.text('Sandi baru wajib diisi'), findsOneWidget);
      verifyNever(() => h.bloc.add(any()));
    });

    for (final weak in {
      'short': 'Ab1',
      'no capital letter': 'baru12345',
      'no digit': 'BaruBaruBaru',
    }.entries) {
      testWidgets('refuses a password with ${weak.key}, with the rule', (
        tester,
      ) async {
        final h = await pumpResetPassword(tester);

        await submit(tester, fresh: weak.value);

        // The rule appears twice: the standing hint, and the error that
        // repeats it.
        expect(
          find.text('Minimal 8 karakter, ada huruf besar dan angka'),
          findsNWidgets(2),
        );
        verifyNever(() => h.bloc.add(any()));
      });
    }

    testWidgets('refuses a confirmation that does not match', (tester) async {
      final h = await pumpResetPassword(tester);

      await submit(tester, fresh: 'Baru12345', confirm: 'Baru12346');

      expect(find.text('Konfirmasi sandi tidak sama'), findsOneWidget);
      verifyNever(() => h.bloc.add(any()));
    });
  });

  group('saving', () {
    testWidgets('sends the member and the password exactly as typed', (
      tester,
    ) async {
      final h = await pumpResetPassword(tester);

      await submit(tester, fresh: 'Baru12345');

      verify(
        () => h.bloc.add(
          const PasswordResetSubmitted(
            memberId: '0101202400000014',
            newPassword: 'Baru12345',
          ),
        ),
      ).called(1);
    });

    testWidgets('does not trim the password', (tester) async {
      final h = await pumpResetPassword(tester);

      await submit(tester, fresh: 'Baru 12345 ');

      verify(
        () => h.bloc.add(
          const PasswordResetSubmitted(
            memberId: '0101202400000014',
            newPassword: 'Baru 12345 ',
          ),
        ),
      ).called(1);
    });

    testWidgets('shows a spinner and locks the form while it saves', (
      tester,
    ) async {
      final h = await pumpResetPassword(tester);

      h.states.add(const PasswordResetLoading());
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNull);
      expect(textFieldOf(tester, newField).enabled, isFalse);
      expect(textFieldOf(tester, confirmField).enabled, isFalse);
      expect(find.text('Simpan'), findsNothing);
    });

    testWidgets('on success returns to a fresh Login with a message, and no '
        'way back into the reset', (tester) async {
      final h = await pumpResetPassword(tester);

      h.states.add(const PasswordResetSuccess());
      await tester.pumpAndSettle();

      expect(find.text('login-page'), findsOneWidget);
      expect(find.byType(ResetPasswordPage), findsNothing);
      expect(
        find.text('Password berhasil diubah. Silakan masuk.'),
        findsOneWidget,
      );
      // Login is the only page left: a back press leaves the app instead of
      // reopening the reset.
      expect(h.router.canPop(), isFalse);
    });

    testWidgets('on a refusal shows the server\'s reason in red and keeps '
        'what was typed', (tester) async {
      final h = await pumpResetPassword(tester);
      await tester.enterText(newField, 'Baru12345');
      await tester.enterText(confirmField, 'Baru12345');

      h.states.add(const PasswordResetError('MEMBER TIDAK DITEMUKAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Member Tidak Ditemukan'), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        ThemeData().colorScheme.error,
      );
      expect(find.byType(ResetPasswordPage), findsOneWidget);
      expect(textFieldOf(tester, newField).controller!.text, 'Baru12345');
      expect(textFieldOf(tester, confirmField).controller!.text, 'Baru12345');
    });
  });

  testWidgets('the back arrow returns to the phone page', (tester) async {
    await pumpResetPassword(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('login-page'), findsOneWidget);
  });
}
