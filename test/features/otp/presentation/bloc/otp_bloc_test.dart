import 'dart:async';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/otp/domain/otp_code_generator.dart';
import 'package:fix_up_moto/features/otp/domain/usecases/send_otp_usecase.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_bloc.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_event.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_state.dart';

class MockSendOtp extends Mock implements SendOtpUseCase {}

/// Hands out the codes it was given, in order, instead of random ones.
class FakeGenerator extends OtpCodeGenerator {
  final List<String> codes;
  int _next = 0;

  FakeGenerator(this.codes) : super(random: Random(1));

  @override
  String generate() => codes[_next++];
}

void main() {
  const first = '123456';
  const second = '654321';
  final tRequest = OtpRequest.toPhone(
    purpose: OtpPurpose.register,
    phone: '081234567890',
  );

  late MockSendOtp send;
  late StreamController<void> clock;
  late OtpBloc bloc;
  late List<OtpState> states;
  var built = false;

  setUpAll(
    () => registerFallbackValue(SendOtpParams(request: tRequest, code: '')),
  );

  setUp(() {
    send = MockSendOtp();
    clock = StreamController<void>.broadcast();
    when(() => send(any())).thenAnswer((_) async => const Right(unit));
    states = [];
    built = false;
  });

  tearDown(() async {
    if (built) await bloc.close();
    await clock.close();
  });

  /// A bloc that makes [codes] in turn and counts seconds only when the test
  /// says so.
  void build([List<String> codes = const [first, second]]) {
    built = true;
    bloc = OtpBloc(
      sendOtp: send,
      generator: FakeGenerator(codes),
      ticker: () => clock.stream,
    );
    bloc.stream.listen(states.add);
  }

  /// Opens the verification and waits until the code is out.
  Future<void> start() async {
    bloc.add(OtpStarted(tRequest));
    await pumpEventQueue();
  }

  Future<void> submit(String code) async {
    bloc.add(OtpCodeSubmitted(code));
    await pumpEventQueue();
  }

  Future<void> seconds(int count) async {
    for (var i = 0; i < count; i++) {
      clock.add(null);
      await pumpEventQueue();
    }
  }

  const waiting = OtpAwaitingCode(
    resendIn: OtpBloc.resendSeconds,
    expiresIn: OtpBloc.lifetimeSeconds,
    attemptsLeft: OtpBloc.maxAttempts,
  );

  test('the numbers: a code lasts 5 minutes, a resend waits 60 seconds, 5 '
      'tries', () {
    expect(OtpBloc.lifetimeSeconds, 300);
    expect(OtpBloc.resendSeconds, 60);
    expect(OtpBloc.maxAttempts, 5);
  });

  group('starting', () {
    test(
      'makes a code, sends it to the request\'s place, and waits for it',
      () async {
        build();

        await start();

        expect(states, [const OtpSending(), waiting]);
        verify(
          () => send(SendOtpParams(request: tRequest, code: first)),
        ).called(1);
      },
    );

    test('a send that fails ends in a failure with its message', () async {
      when(() => send(any())).thenAnswer(
        (_) async => const Left(NetworkFailure('Tidak ada koneksi')),
      );
      build();

      await start();

      expect(states, [
        const OtpSending(),
        const OtpSendFailed('Tidak ada koneksi'),
      ]);
    });

    test('nothing can be verified after a failed send, even the code that '
        'was made', () async {
      when(
        () => send(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('x')));
      build();
      await start();
      states.clear();

      await submit(first);

      expect(states, isEmpty);
    });
  });

  group('checking the code', () {
    test('the right code verifies, and the clock stops', () async {
      build();
      await start();
      states.clear();

      await submit(first);

      expect(states, [const OtpVerified()]);
      expect(clock.hasListener, isFalse);
    });

    test('a code that was verified cannot be used again', () async {
      build();
      await start();
      await submit(first);
      states.clear();

      await submit(first);

      expect(states, isEmpty);
    });

    test('a wrong code costs a try and says so', () async {
      build();
      await start();
      states.clear();

      await submit('000000');

      expect(states, [
        const OtpAwaitingCode(
          resendIn: OtpBloc.resendSeconds,
          expiresIn: OtpBloc.lifetimeSeconds,
          attemptsLeft: 4,
          lastWasWrong: true,
        ),
      ]);
    });

    test('five wrong codes throw the code away, and then even the right one '
        'fails', () async {
      build();
      await start();
      states.clear();

      for (var i = 0; i < OtpBloc.maxAttempts; i++) {
        await submit('00000$i');
      }

      expect(
        states.last,
        const OtpCodeUnusable(
          reason: OtpUnusableReason.tooManyAttempts,
          resendIn: OtpBloc.resendSeconds,
        ),
      );

      states.clear();
      await submit(first);
      expect(states, isEmpty, reason: 'the real code is dead too');
    });
  });

  group('time', () {
    test('counts the resend wait down, and the code\'s life with it', () async {
      build();
      await start();
      states.clear();

      await seconds(3);

      expect(
        states.last,
        const OtpAwaitingCode(
          resendIn: 57,
          expiresIn: 297,
          attemptsLeft: OtpBloc.maxAttempts,
        ),
      );
    });

    test(
      'a code dies after five minutes, and then even the right one fails',
      () async {
        build();
        await start();

        await seconds(OtpBloc.lifetimeSeconds);

        expect(
          states.last,
          const OtpCodeUnusable(reason: OtpUnusableReason.expired, resendIn: 0),
        );

        states.clear();
        await submit(first);
        expect(states, isEmpty);
      },
    );

    test('a wrong-code notice stays up as the clock runs', () async {
      build();
      await start();
      await submit('000000');

      await seconds(2);

      expect((states.last as OtpAwaitingCode).lastWasWrong, isTrue);
    });
  });

  group('sending another code', () {
    test(
      'is refused before the wait is over, so nobody can spam a phone',
      () async {
        build();
        await start();
        await seconds(59);
        states.clear();

        bloc.add(const OtpResendRequested());
        await pumpEventQueue();

        expect(states, isEmpty);
        verify(() => send(any())).called(1);
      },
    );

    test('works once the wait is over, makes a fresh code and kills the old '
        'one', () async {
      build();
      await start();
      await seconds(OtpBloc.resendSeconds);
      states.clear();

      bloc.add(const OtpResendRequested());
      await pumpEventQueue();

      expect(states, [const OtpSending(), waiting]);
      verify(
        () => send(SendOtpParams(request: tRequest, code: second)),
      ).called(1);

      states.clear();
      await submit(first);
      expect(
        (states.single as OtpAwaitingCode).lastWasWrong,
        isTrue,
        reason: 'the first code no longer works',
      );
      await submit(second);
      expect(states.last, const OtpVerified());
    });

    test('is the way out of a dead code, once the wait is over', () async {
      build();
      await start();
      for (var i = 0; i < OtpBloc.maxAttempts; i++) {
        await submit('00000$i');
      }
      // Dead, but the 60 seconds have not passed: still refused.
      bloc.add(const OtpResendRequested());
      await pumpEventQueue();
      verify(() => send(any())).called(1);

      await seconds(OtpBloc.resendSeconds);
      expect(
        states.last,
        const OtpCodeUnusable(
          reason: OtpUnusableReason.tooManyAttempts,
          resendIn: 0,
        ),
      );
      expect(clock.hasListener, isFalse, reason: 'nothing left to count');

      states.clear();
      bloc.add(const OtpResendRequested());
      await pumpEventQueue();

      expect(states, [const OtpSending(), waiting]);
    });

    test('is allowed at once after a send that failed', () async {
      var calls = 0;
      when(() => send(any())).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Left(NetworkFailure('Tidak ada koneksi'))
            : const Right(unit);
      });
      build();
      await start();
      states.clear();

      bloc.add(const OtpResendRequested());
      await pumpEventQueue();

      expect(states, [const OtpSending(), waiting]);
    });

    test('a double tap while one is being sent sends only one', () async {
      build();
      await start();
      await seconds(OtpBloc.resendSeconds);

      bloc
        ..add(const OtpResendRequested())
        ..add(const OtpResendRequested());
      await pumpEventQueue();

      verify(() => send(any())).called(2); // the first code, and one resend
    });
  });

  group('the code itself', () {
    test('never appears in a state', () async {
      build();
      await start();
      await submit('000000');
      await seconds(3);
      await submit(first);

      for (final state in states) {
        expect(state.props.map((p) => '$p'), isNot(contains(first)));
        expect('$state', isNot(contains(first)));
      }
    });

    test('is not printed with its parameters either', () {
      final params = SendOtpParams(request: tRequest, code: first);

      expect(params.toString(), isNot(contains(first)));
    });
  });

  test('closing stops the clock', () async {
    build();
    await start();
    expect(clock.hasListener, isTrue);

    await bloc.close();

    expect(clock.hasListener, isFalse);
  });
}
