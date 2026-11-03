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
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/change_password_page.dart';

import '../../../../support/otp_stand_in.dart';

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// A phone-registered member: signs in with this number.
const tManual = UserEntity(
  id: 'M-001',
  name: 'Test Member',
  status: 'SUKSES',
  isActive: true,
  loginId: '87700001111',
);

/// What the page needs from the outside, so tests can drive and inspect it.
class Harness {
  final MockProfileBloc profile;

  /// Pushes states into the page's ProfileBloc, as a save would.
  final StreamController<ProfileState> states;

  /// The stand-in for the code page that Simpan opens first.
  final OtpStandIn otp;

  const Harness(this.profile, this.states, this.otp);
}

/// Opens the page on top of a stand-in Profile page, the way the app does, so
/// popping can be checked by where it lands.
Future<Harness> pumpChangePassword(
  WidgetTester tester, {
  UserEntity user = tManual,
}) async {
  final profileBloc = MockProfileBloc();
  final states = StreamController<ProfileState>.broadcast();
  addTearDown(states.close);
  whenListen(profileBloc, states.stream, initialState: const ProfileInitial());
  sl.registerFactory<ProfileBloc>(() => profileBloc);

  final authBloc = MockAuthBloc();
  whenListen(
    authBloc,
    const Stream<AuthState>.empty(),
    initialState: AuthAuthenticated(user),
  );

  final otp = OtpStandIn();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('profile-page')),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        builder: (_, _) => const ChangePasswordPage(),
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
  unawaited(router.push(RouteNames.changePassword));
  await tester.pumpAndSettle();

  return Harness(profileBloc, states, otp);
}

void main() {
  setUpAll(() => registerFallbackValue(const ProfileLoadRequested()));
  tearDown(() => sl.reset());

  final oldField = find.widgetWithText(TextFormField, 'Sandi Lama');
  final newField = find.widgetWithText(TextFormField, 'Sandi Baru');
  final confirmField = find.widgetWithText(
    TextFormField,
    'Konfirmasi Sandi Baru',
  );
  final saveButton = find.widgetWithText(ElevatedButton, 'Simpan');

  /// Fills the three fields, then presses Simpan.
  Future<void> submit(
    WidgetTester tester, {
    String old = 'JAngelus21',
    String fresh = 'Baru12345',
    String? confirm,
  }) async {
    await tester.enterText(oldField, old);
    await tester.enterText(newField, fresh);
    await tester.enterText(confirmField, confirm ?? fresh);
    await tester.tap(saveButton);
    await tester.pump();
  }

  String textOf(WidgetTester tester, Finder field) => tester
      .widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      )
      .controller!
      .text;

  bool isObscured(WidgetTester tester, Finder field) => tester
      .widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      )
      .obscureText;

  bool isEnabled(WidgetTester tester, Finder field) => tester
      .widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      )
      .enabled!;

  group('what it shows', () {
    testWidgets('is titled Ganti Password', (tester) async {
      await pumpChangePassword(tester);

      expect(find.byKey(const Key('change-password-page')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Ganti Password'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sits on the same warm wash as the Profile pages', (
      tester,
    ) async {
      await pumpChangePassword(tester);

      expect(find.byType(WarmWash), findsOneWidget);
    });

    testWidgets('has three empty, hidden password fields and a Simpan button', (
      tester,
    ) async {
      await pumpChangePassword(tester);

      for (final field in [oldField, newField, confirmField]) {
        expect(field, findsOneWidget);
        expect(textOf(tester, field), isEmpty);
        expect(isObscured(tester, field), isTrue);
      }
      expect(saveButton, findsOneWidget);
    });

    testWidgets('states the rule for the new password under its field', (
      tester,
    ) async {
      await pumpChangePassword(tester);

      final rule = find.byKey(const Key('password-rule'));

      expect(rule, findsOneWidget);
      expect(
        tester.widget<Text>(rule).data,
        'Minimal 8 karakter, ada huruf besar dan angka',
      );
      // And it sits below the Sandi Baru field, above the confirmation.
      expect(
        tester.getTopLeft(rule).dy,
        greaterThan(tester.getBottomLeft(newField).dy - 1),
      );
      expect(
        tester.getTopLeft(rule).dy,
        lessThan(tester.getTopLeft(confirmField).dy),
      );
    });

    testWidgets('the back arrow returns to Profile', (tester) async {
      await pumpChangePassword(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('change-password-page')), findsNothing);
      expect(find.text('profile-page'), findsOneWidget);
    });
  });

  group('checking before it sends', () {
    testWidgets('sends both passwords exactly as typed, once the code is '
        'right', (tester) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester, old: ' JAngelus21 ', fresh: 'Baru12345 ');
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.correct);
      await tester.pumpAndSettle();

      verify(
        () => harness.profile.add(
          const ProfileChangePasswordRequested(
            oldPassword: ' JAngelus21 ',
            newPassword: 'Baru12345 ',
          ),
        ),
      ).called(1);
    });

    testWidgets('asks for a code on the member\'s WhatsApp first, and sends '
        'nothing until it is typed', (tester) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester);
      await tester.pumpAndSettle();

      expect(harness.otp.opened, [
        OtpRequest.toPhone(
          purpose: OtpPurpose.changePassword,
          phone: '87700001111',
        ),
      ]);
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('sends nothing, and keeps what was typed, when the code page '
        'is backed out of', (tester) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester);
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.cancel);
      await tester.pumpAndSettle();

      verifyNever(() => harness.profile.add(any()));
      expect(find.byType(ChangePasswordPage), findsOneWidget);
      expect(textOf(tester, oldField), 'JAngelus21');
      expect(textOf(tester, newField), 'Baru12345');
    });

    testWidgets('does not ask for a code while the form is not valid', (
      tester,
    ) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester, fresh: 'Ab1');
      await tester.pumpAndSettle();

      expect(harness.otp.opened, isEmpty);
    });

    testWidgets('asks for every field when they are all blank', (tester) async {
      final harness = await pumpChangePassword(tester);

      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Sandi lama wajib diisi'), findsOneWidget);
      expect(find.text('Sandi baru wajib diisi'), findsOneWidget);
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('refuses a new password shorter than 8 characters', (
      tester,
    ) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester, fresh: 'Ab1');

      expect(
        find.text('Minimal 8 karakter, ada huruf besar dan angka'),
        // The rule line under the field, and the error that repeats it.
        findsNWidgets(2),
      );
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('refuses a new password with no capital letter', (
      tester,
    ) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester, fresh: 'baru12345');

      expect(
        find.text('Minimal 8 karakter, ada huruf besar dan angka'),
        findsNWidgets(2),
      );
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('refuses a new password with no digit', (tester) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester, fresh: 'BaruBaruBaru');

      expect(
        find.text('Minimal 8 karakter, ada huruf besar dan angka'),
        findsNWidgets(2),
      );
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('refuses a new password equal to the old one', (tester) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester, old: 'Sama12345', fresh: 'Sama12345');

      expect(
        find.text('Sandi baru harus berbeda dari sandi lama'),
        findsOneWidget,
      );
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('refuses a confirmation that does not match', (tester) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester, confirm: 'Baru12346');

      expect(find.text('Konfirmasi sandi tidak sama'), findsOneWidget);
      verifyNever(() => harness.profile.add(any()));
    });

    testWidgets('shows every problem at once, and sends nothing', (
      tester,
    ) async {
      final harness = await pumpChangePassword(tester);

      await submit(tester, old: '', fresh: 'Ab1', confirm: 'x');

      expect(find.text('Sandi lama wajib diisi'), findsOneWidget);
      expect(find.text('Konfirmasi sandi tidak sama'), findsOneWidget);
      verifyNever(() => harness.profile.add(any()));
    });
  });

  group('sending', () {
    testWidgets('disables the fields and the button, and spins', (
      tester,
    ) async {
      final harness = await pumpChangePassword(tester);

      harness.states.add(const ProfileLoading());
      await tester.pump();
      await tester.pump();

      // The label is replaced by the spinner, so find the button by type.
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final field in [oldField, newField, confirmField]) {
        expect(isEnabled(tester, field), isFalse);
      }
    });

    testWidgets('on success: says so and goes back to Profile', (tester) async {
      final harness = await pumpChangePassword(tester);

      harness.states.add(const ProfileActionSuccess('Sandi berhasil diubah'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Sandi berhasil diubah'), findsOneWidget);
      expect(find.text('profile-page'), findsOneWidget);
      expect(find.byType(ChangePasswordPage), findsNothing);
    });

    testWidgets('on a refusal: shows the server\'s reason and keeps what was '
        'typed', (tester) async {
      final harness = await pumpChangePassword(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      await tester.tap(OtpStandIn.correct);
      await tester.pumpAndSettle();

      harness.states.add(const ProfileError('Password lama salah'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Password lama salah'), findsOneWidget);
      expect(find.byType(ChangePasswordPage), findsOneWidget);
      // One correction and a retry is all a wrong old password should cost.
      expect(textOf(tester, oldField), 'JAngelus21');
      expect(textOf(tester, newField), 'Baru12345');
      expect(textOf(tester, confirmField), 'Baru12345');
      expect(isEnabled(tester, oldField), isTrue);
    });
  });

  test('the route lives at /change-password', () {
    expect(RouteNames.changePassword, '/change-password');
  });
}
