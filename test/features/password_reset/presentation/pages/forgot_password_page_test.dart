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
import 'package:fix_up_moto/features/otp/domain/entities/otp_channel.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_bloc.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_event.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_state.dart';
import 'package:fix_up_moto/features/password_reset/presentation/pages/forgot_password_page.dart';

import '../../../../support/otp_stand_in.dart';

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

  /// Pushes states into the page's bloc, as a lookup would.
  final StreamController<PasswordResetState> states;

  /// The stand-in for the code page that a found member opens.
  final OtpStandIn otp;

  /// The `extra` of every time the new-password page (a stand-in) was opened.
  final List<Object?> resetOpenedWith;

  const Harness(this.bloc, this.states, this.otp, this.resetOpenedWith);
}

/// Opens the page on top of a stand-in Login, the way the app does, so popping
/// can be checked by where it lands.
Future<Harness> pumpForgotPassword(WidgetTester tester) async {
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

  final otp = OtpStandIn();
  final resetOpenedWith = <Object?>[];
  final router = GoRouter(
    initialLocation: RouteNames.login,
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (_, _) => const Scaffold(body: Text('login-page')),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: RouteNames.resetPassword,
        builder: (_, state) {
          resetOpenedWith.add(state.extra);
          return const Scaffold(body: Text('reset-password-page'));
        },
      ),
      otp.route,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  unawaited(router.push(RouteNames.forgotPassword));
  await tester.pumpAndSettle();

  return Harness(bloc, states, otp, resetOpenedWith);
}

void main() {
  setUpAll(() => registerFallbackValue(const PasswordResetMemberRequested('')));
  tearDown(() => sl.reset());

  final phoneField = find.widgetWithText(TextFormField, 'Phone number');
  final sendButton = find.byKey(const Key('forgot-password-send'));

  Future<void> tapSend(WidgetTester tester) async {
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pump();
  }

  bool phoneEnabled(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(of: phoneField, matching: find.byType(TextField)),
      )
      .enabled!;

  group('what it shows', () {
    testWidgets('asks for the phone number, with the headline and the '
        'WhatsApp promise', (tester) async {
      await pumpForgotPassword(tester);

      expect(find.byKey(const Key('forgot-password-page')), findsOneWidget);
      expect(find.text('Lupa password?'), findsOneWidget);
      expect(find.textContaining('lewat WhatsApp'), findsOneWidget);
      expect(phoneField, findsOneWidget);
      // The fixed prefix, like Login's field.
      expect(find.text('+62'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Kirim Kode'), findsOneWidget);
    });

    testWidgets('sits on the same warm wash as Login', (tester) async {
      await pumpForgotPassword(tester);

      expect(find.byType(WarmWash), findsOneWidget);
    });

    testWidgets('tells a Google member they have no password to reset', (
      tester,
    ) async {
      await pumpForgotPassword(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('forgot-password-google-note')),
          matching: find.textContaining('Akun Google tidak memakai password'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('has a way back to Login', (tester) async {
      await pumpForgotPassword(tester);

      expect(find.text('Sudah ingat password?'), findsOneWidget);
      await tester.ensureVisible(find.text('Masuk'));
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('login-page'), findsOneWidget);
    });
  });

  group('sending the code', () {
    testWidgets('asks for the number first: nothing is looked up while it is '
        'empty', (tester) async {
      final h = await pumpForgotPassword(tester);

      await tapSend(tester);

      expect(find.text('Phone number is required'), findsOneWidget);
      verifyNever(() => h.bloc.add(any()));
    });

    testWidgets('rejects a number that is too short', (tester) async {
      final h = await pumpForgotPassword(tester);

      await tester.enterText(phoneField, '12');
      await tapSend(tester);

      expect(find.text('Enter a valid phone number'), findsOneWidget);
      verifyNever(() => h.bloc.add(any()));
    });

    testWidgets('looks the number up, as the subscriber number the field '
        'shows (a typed leading 0 is dropped)', (tester) async {
      final h = await pumpForgotPassword(tester);

      await tester.enterText(phoneField, '0812-3456-7890');
      await tapSend(tester);

      verify(
        () => h.bloc.add(const PasswordResetMemberRequested('81234567890')),
      ).called(1);
    });

    testWidgets('does not open the code page until the member is found', (
      tester,
    ) async {
      final h = await pumpForgotPassword(tester);

      await tester.enterText(phoneField, '81234567890');
      await tapSend(tester);

      expect(h.otp.opened, isEmpty);
    });

    testWidgets('shows a spinner and locks the form while it looks', (
      tester,
    ) async {
      final h = await pumpForgotPassword(tester);

      h.states.add(const PasswordResetLoading());
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget<ElevatedButton>(sendButton).onPressed, isNull);
      expect(phoneEnabled(tester), isFalse);
      expect(find.text('Kirim Kode'), findsNothing);
    });
  });

  group('once the member is found', () {
    testWidgets('asks for a code over WhatsApp, to the found number, for a '
        'reset', (tester) async {
      final h = await pumpForgotPassword(tester);

      h.states.add(const PasswordResetMemberFound(tMember));
      await tester.pumpAndSettle();

      expect(h.otp.opened, hasLength(1));
      final request = h.otp.opened.single;
      expect(request.purpose, OtpPurpose.resetPassword);
      expect(request.channel, OtpChannel.whatsapp);
      expect(request.destination, '81234567890');
    });

    testWidgets('opens the new-password page with the member, only after the '
        'right code', (tester) async {
      final h = await pumpForgotPassword(tester);

      h.states.add(const PasswordResetMemberFound(tMember));
      await tester.pumpAndSettle();
      // Still on the code page: not through yet.
      expect(h.resetOpenedWith, isEmpty);

      await tester.tap(OtpStandIn.correct);
      await tester.pumpAndSettle();

      expect(find.text('reset-password-page'), findsOneWidget);
      expect(h.resetOpenedWith, [tMember]);
    });

    testWidgets('goes no further when the code page is backed out of, and '
        'keeps the number typed', (tester) async {
      final h = await pumpForgotPassword(tester);
      await tester.enterText(phoneField, '81234567890');

      h.states.add(const PasswordResetMemberFound(tMember));
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.cancel);
      await tester.pumpAndSettle();

      expect(h.resetOpenedWith, isEmpty);
      expect(find.byKey(const Key('forgot-password-page')), findsOneWidget);
      expect(find.text('81234567890'), findsOneWidget);
    });

    testWidgets('can ask again after backing out', (tester) async {
      final h = await pumpForgotPassword(tester);

      h.states.add(const PasswordResetMemberFound(tMember));
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.cancel);
      await tester.pumpAndSettle();

      // A second lookup that ends the same way opens the code page again.
      h.states.add(const PasswordResetLoading());
      await tester.pump(const Duration(milliseconds: 50));
      h.states.add(const PasswordResetMemberFound(tMember));
      await tester.pumpAndSettle();

      expect(h.otp.opened, hasLength(2));
    });
  });

  group('when the lookup fails', () {
    testWidgets('shows the reason in a red snackbar, tidied from the '
        'server\'s capitals, and stays put', (tester) async {
      final h = await pumpForgotPassword(tester);
      await tester.enterText(phoneField, '81234567890');

      h.states.add(const PasswordResetError('NOMOR TELEPON BELUM TERDAFTAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nomor Telepon Belum Terdaftar'), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        ThemeData().colorScheme.error,
      );
      expect(h.otp.opened, isEmpty);
      expect(find.text('81234567890'), findsOneWidget);
    });
  });
}
