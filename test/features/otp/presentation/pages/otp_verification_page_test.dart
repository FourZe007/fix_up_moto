import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_bloc.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_event.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_state.dart';
import 'package:fix_up_moto/features/otp/presentation/pages/otp_verification_page.dart';
import '../../../../support/haptic_recorder.dart';

class MockOtpBloc extends MockBloc<OtpEvent, OtpState> implements OtpBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// What the page needs from the outside, so tests can drive and inspect it.
class Harness {
  final MockOtpBloc bloc;

  /// Pushes states into the page's OtpBloc, as the verification would.
  final StreamController<OtpState> states;

  /// What the page closed with, in order: `true` for a right code, null when
  /// it was backed out of.
  final List<bool?> results;

  const Harness(this.bloc, this.states, this.results);
}

final tPhone = OtpRequest.toPhone(
  purpose: OtpPurpose.register,
  phone: '081234567890',
);
final tEmail = OtpRequest.toEmail(
  purpose: OtpPurpose.register,
  email: 'joseph@gmail.com',
);

const tWaiting = OtpAwaitingCode(resendIn: 45, expiresIn: 290, attemptsLeft: 5);

/// Opens the page on top of a stand-in caller, the way the app does, so what it
/// closes with can be checked.
Future<Harness> pumpOtp(
  WidgetTester tester, {
  OtpRequest? request,
  OtpState initial = tWaiting,
  ThemeData? theme,
}) async {
  final bloc = MockOtpBloc();
  final states = StreamController<OtpState>.broadcast();
  addTearDown(states.close);
  whenListen(bloc, states.stream, initialState: initial);
  sl.registerFactory<OtpBloc>(() => bloc);

  final authBloc = MockAuthBloc();
  whenListen(
    authBloc,
    const Stream<AuthState>.empty(),
    initialState: const AuthUnauthenticated(),
  );

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('caller')),
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (_, state) =>
            OtpVerificationPage(request: state.extra as OtpRequest),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(theme: theme, routerConfig: router),
    ),
  );
  final results = <bool?>[];
  unawaited(
    router
        .push<bool>(RouteNames.otp, extra: request ?? tPhone)
        .then(results.add),
  );
  // Not pumpAndSettle: the sending state's spinner animates forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return Harness(bloc, states, results);
}

void main() {
  setUpAll(() => registerFallbackValue(const OtpResendRequested()));
  tearDown(() => sl.reset());

  final input = find.byKey(const Key('otp-input'));
  final submitButton = find.byKey(const Key('otp-submit'));
  final resendButton = find.byKey(const Key('otp-resend'));
  final message = find.byKey(const Key('otp-message'));

  String typed(WidgetTester tester) =>
      tester.widget<TextField>(input).controller!.text;

  String boxText(WidgetTester tester, int i) {
    final box = find.byKey(Key('otp-box-$i'));
    final texts = find.descendant(of: box, matching: find.byType(Text));
    return tester.widget<Text>(texts).data!;
  }

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(submitButton).onPressed != null;

  bool resendEnabled(WidgetTester tester) =>
      tester.widget<TextButton>(resendButton).onPressed != null;

  bool inputEnabled(WidgetTester tester) =>
      tester.widget<TextField>(input).enabled!;

  /// Pushes [state] into the page and lets it react.
  Future<void> emit(WidgetTester tester, Harness h, OtpState state) async {
    h.states.add(state);
    await tester.pump();
    await tester.pump();
  }

  group('what it shows', () {
    testWidgets('names the page and where the code went, for WhatsApp', (
      tester,
    ) async {
      await pumpOtp(tester, request: tPhone);

      expect(find.text('Verifikasi'), findsNWidgets(2)); // title and button
      expect(find.text('Kode 6 digit dikirim ke WhatsApp'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('otp-destination'))).data,
        '+62 812****7890',
      );
    });

    testWidgets('names the page and where the code went, for email', (
      tester,
    ) async {
      await pumpOtp(tester, request: tEmail);

      expect(find.text('Kode 6 digit dikirim ke email'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('otp-destination'))).data,
        'j***@gmail.com',
      );
    });

    testWidgets('sits on the warm wash, under the back-arrow bar', (
      tester,
    ) async {
      await pumpOtp(tester);

      expect(find.byType(WarmWash), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.arrow_back), findsOneWidget);
    });

    testWidgets('has six empty boxes', (tester) async {
      await pumpOtp(tester);

      for (var i = 0; i < 6; i++) {
        expect(find.byKey(Key('otp-box-$i')), findsOneWidget);
        expect(boxText(tester, i), isEmpty);
      }
      expect(find.byKey(const Key('otp-box-6')), findsNothing);
    });

    testWidgets('opens by starting the verification with its request', (
      tester,
    ) async {
      final h = await pumpOtp(tester, request: tEmail);

      verify(() => h.bloc.add(OtpStarted(tEmail))).called(1);
    });

    testWidgets('does not overflow on a small screen with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 480 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await pumpOtp(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('works in dark mode', (tester) async {
      await pumpOtp(tester, theme: ThemeData.dark());

      expect(tester.takeException(), isNull);
      expect(find.text('Kode 6 digit dikirim ke WhatsApp'), findsOneWidget);
    });
  });

  group('typing the code', () {
    testWidgets('fills the boxes as digits arrive', (tester) async {
      await pumpOtp(tester);

      await tester.enterText(input, '4829');
      await tester.pump();

      expect(
        [for (var i = 0; i < 6; i++) boxText(tester, i)],
        ['4', '8', '2', '9', '', ''],
      );
    });

    testWidgets('takes digits only, and no more than six', (tester) async {
      await pumpOtp(tester);

      await tester.enterText(input, 'ab12-34567x89');
      await tester.pump();

      expect(typed(tester), '123456');
    });

    testWidgets('keeps Verifikasi off until all six are in', (tester) async {
      await pumpOtp(tester);
      expect(submitEnabled(tester), isFalse);

      await tester.enterText(input, '48291');
      await tester.pump();
      expect(submitEnabled(tester), isFalse);

      await tester.enterText(input, '482915');
      await tester.pump();
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('sends the full code when Verifikasi is pressed', (
      tester,
    ) async {
      final h = await pumpOtp(tester);

      await tester.enterText(input, '482915');
      await tester.pump();
      await tester.tap(submitButton);
      await tester.pump();

      verify(() => h.bloc.add(const OtpCodeSubmitted('482915'))).called(1);
    });

    testWidgets('sends it from the keyboard\'s done key too', (tester) async {
      final h = await pumpOtp(tester);

      await tester.enterText(input, '482915');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verify(() => h.bloc.add(const OtpCodeSubmitted('482915'))).called(1);
    });

    testWidgets('does not send a code that is not complete', (tester) async {
      final h = await pumpOtp(tester);

      await tester.enterText(input, '4829');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verifyNever(() => h.bloc.add(any(that: isA<OtpCodeSubmitted>())));
    });
  });

  group('while it sends', () {
    testWidgets('says so, and locks the field and the buttons', (tester) async {
      await pumpOtp(tester, initial: const OtpSending());

      expect(find.text('Mengirim kode…'), findsOneWidget);
      expect(inputEnabled(tester), isFalse);
      expect(submitEnabled(tester), isFalse);
      expect(resendEnabled(tester), isFalse);
    });

    testWidgets('unlocks the field when the code is out', (tester) async {
      final h = await pumpOtp(tester, initial: const OtpSending());

      await emit(tester, h, tWaiting);

      expect(inputEnabled(tester), isTrue);
      expect(find.text('Mengirim kode…'), findsNothing);
    });

    testWidgets('puts the cursor in the field when the code is out, so the '
        'keyboard opens by itself', (tester) async {
      final h = await pumpOtp(tester, initial: const OtpSending());
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isFalse);

      await emit(tester, h, tWaiting);
      await tester.pump();

      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    });

    testWidgets('keeps the cursor in the field after a wrong code, to type '
        'again', (tester) async {
      final h = await pumpOtp(tester);
      await tester.enterText(input, '111111');

      await emit(
        tester,
        h,
        const OtpAwaitingCode(
          resendIn: 40,
          expiresIn: 280,
          attemptsLeft: 4,
          lastWasWrong: true,
        ),
      );
      await tester.pump();

      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    });
  });

  group('waiting for the code', () {
    testWidgets('shows how long the code is good for', (tester) async {
      await pumpOtp(tester);

      expect(
        find.descendant(of: message, matching: find.text('Kode berlaku 4:50')),
        findsOneWidget,
      );
    });

    testWidgets('counts the resend wait down on the button, switched off', (
      tester,
    ) async {
      await pumpOtp(tester);

      expect(find.text('Kirim ulang (45 dtk)'), findsOneWidget);
      expect(resendEnabled(tester), isFalse);
    });

    testWidgets('turns the resend on at zero, and asks for a new code', (
      tester,
    ) async {
      final h = await pumpOtp(tester);

      await emit(
        tester,
        h,
        const OtpAwaitingCode(resendIn: 0, expiresIn: 240, attemptsLeft: 5),
      );
      expect(find.text('Kirim ulang'), findsOneWidget);
      expect(resendEnabled(tester), isTrue);

      await tester.tap(resendButton);
      await tester.pump();

      verify(() => h.bloc.add(const OtpResendRequested())).called(1);
    });
  });

  group('a wrong code', () {
    testWidgets('is announced with the tries left, and the boxes are '
        'emptied for the next go', (tester) async {
      final h = await pumpOtp(tester);
      await tester.enterText(input, '111111');
      await tester.pump();
      expect(typed(tester), '111111');

      await emit(
        tester,
        h,
        const OtpAwaitingCode(
          resendIn: 40,
          expiresIn: 280,
          attemptsLeft: 4,
          lastWasWrong: true,
        ),
      );

      expect(
        find.descendant(
          of: message,
          matching: find.text('Kode salah. Sisa 4 percobaan.'),
        ),
        findsOneWidget,
      );
      expect(typed(tester), isEmpty);
      expect(inputEnabled(tester), isTrue);
    });

    testWidgets('turns the boxes red, until the next code starts to be '
        'typed', (tester) async {
      final h = await pumpOtp(tester);
      Color borderOf(int i) {
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(Key('otp-box-$i')),
                matching: find.byType(Container),
              )
              .first,
        );
        return ((container.decoration as BoxDecoration).border as Border)
            .top
            .color;
      }

      await emit(
        tester,
        h,
        const OtpAwaitingCode(
          resendIn: 40,
          expiresIn: 280,
          attemptsLeft: 4,
          lastWasWrong: true,
        ),
      );
      expect(borderOf(0), AppColors.error);
      expect(borderOf(5), AppColors.error);

      await tester.enterText(input, '4');
      await tester.pump();

      expect(borderOf(0), isNot(AppColors.error));
      expect(borderOf(5), isNot(AppColors.error));
      // The words stay, so the tries left are still in view.
      expect(find.text('Kode salah. Sisa 4 percobaan.'), findsOneWidget);
    });

    testWidgets('does not wipe what is typed next, every second after it', (
      tester,
    ) async {
      final h = await pumpOtp(tester);
      await emit(
        tester,
        h,
        const OtpAwaitingCode(
          resendIn: 40,
          expiresIn: 280,
          attemptsLeft: 4,
          lastWasWrong: true,
        ),
      );
      await tester.enterText(input, '482');
      await tester.pump();

      // One second on: same tries left, so nothing to clear.
      await emit(
        tester,
        h,
        const OtpAwaitingCode(
          resendIn: 39,
          expiresIn: 279,
          attemptsLeft: 4,
          lastWasWrong: true,
        ),
      );

      expect(typed(tester), '482');
    });
  });

  group('a dead code', () {
    testWidgets('after too many tries: says so, locks the field, and offers '
        'a new code once the wait is over', (tester) async {
      final h = await pumpOtp(tester);
      await tester.enterText(input, '111111');

      await emit(
        tester,
        h,
        const OtpCodeUnusable(
          reason: OtpUnusableReason.tooManyAttempts,
          resendIn: 0,
        ),
      );

      expect(find.text('Terlalu banyak percobaan.'), findsOneWidget);
      expect(inputEnabled(tester), isFalse);
      expect(typed(tester), isEmpty);
      expect(submitEnabled(tester), isFalse);
      expect(resendEnabled(tester), isTrue);
    });

    testWidgets('after five minutes: says it expired', (tester) async {
      final h = await pumpOtp(tester);

      await emit(
        tester,
        h,
        const OtpCodeUnusable(reason: OtpUnusableReason.expired, resendIn: 12),
      );

      expect(find.text('Kode kedaluwarsa.'), findsOneWidget);
      expect(find.text('Kirim ulang (12 dtk)'), findsOneWidget);
      expect(resendEnabled(tester), isFalse);
    });
  });

  group('when the code could not be sent', () {
    testWidgets('shows why, and offers to try again at once', (tester) async {
      final h = await pumpOtp(tester);

      await emit(tester, h, const OtpSendFailed('Tidak ada koneksi internet'));

      expect(find.text('Tidak ada koneksi internet'), findsOneWidget);
      expect(inputEnabled(tester), isFalse);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(resendEnabled(tester), isTrue);

      await tester.tap(resendButton);
      await tester.pump();
      verify(() => h.bloc.add(const OtpResendRequested())).called(1);
    });
  });

  group('closing', () {
    testWidgets('closes with true when the right code was typed', (
      tester,
    ) async {
      final h = await pumpOtp(tester);

      await emit(tester, h, const OtpVerified());
      await tester.pumpAndSettle();

      expect(h.results, [true]);
      expect(find.text('caller'), findsOneWidget);
    });

    testWidgets('gives a success tap on iOS when the right code was typed', (
      tester,
    ) async {
      final haptics = HapticRecorder.start();

      await onDevice(TargetPlatform.iOS, () async {
        final h = await pumpOtp(tester);

        await emit(tester, h, const OtpVerified());
        await tester.pumpAndSettle();

        expect(haptics.taps, [successTap]);
      });
    });

    testWidgets('closes with nothing when the back arrow is used, which the '
        'caller reads as not verified', (tester) async {
      final h = await pumpOtp(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(h.results, [null]);
      expect(find.text('caller'), findsOneWidget);
    });
  });
}
