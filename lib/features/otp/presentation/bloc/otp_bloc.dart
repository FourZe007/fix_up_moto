import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/otp/domain/otp_code_generator.dart';
import 'package:fix_up_moto/features/otp/domain/otp_policy.dart';
import 'package:fix_up_moto/features/otp/domain/usecases/send_otp_usecase.dart';
import 'otp_event.dart';
import 'otp_state.dart';

/// Runs one verification: makes a code, sends it, and checks what the member
/// types against it.
///
/// **The code lives here and nowhere else.** It is a private field: never in a
/// state, an event, storage or a log. It is also checked here, on the phone,
/// which proves the member holds the WhatsApp or mailbox the code went to, but
/// cannot stop someone who calls the backend directly.
///
/// Page-scoped (`registerFactory`): each OTP page gets its own bloc, so a code
/// can never carry over from one verification to the next.
class OtpBloc extends Bloc<OtpEvent, OtpState> {
  /// How long a code is accepted. The rules live in [OtpPolicy], which the
  /// message the member receives also reads.
  static const int lifetimeSeconds = OtpPolicy.lifetimeSeconds;

  /// How long before a new code can be asked for.
  static const int resendSeconds = OtpPolicy.resendSeconds;

  /// Wrong tries before the code is thrown away.
  static const int maxAttempts = OtpPolicy.maxAttempts;

  final SendOtpUseCase _sendOtp;
  final OtpCodeGenerator _generator;
  final Stream<void> Function() _ticker;

  OtpRequest? _request;
  String? _code;
  int _resendIn = 0;
  int _expiresIn = 0;
  int _attemptsLeft = 0;
  StreamSubscription<void>? _ticking;

  /// [ticker] says when a second has passed; tests hand in their own so time
  /// can be moved by hand.
  OtpBloc({
    required SendOtpUseCase sendOtp,
    required OtpCodeGenerator generator,
    Stream<void> Function()? ticker,
  }) : _sendOtp = sendOtp,
       _generator = generator,
       _ticker = ticker ?? _everySecond,
       super(const OtpInitial()) {
    on<OtpStarted>(_onStarted);
    on<OtpResendRequested>(_onResendRequested);
    on<OtpCodeSubmitted>(_onCodeSubmitted);
    on<OtpTicked>(_onTicked);
  }

  static Stream<void> _everySecond() =>
      Stream<void>.periodic(const Duration(seconds: 1));

  Future<void> _onStarted(OtpStarted event, Emitter<OtpState> emit) async {
    _request = event.request;
    await _sendNewCode(emit);
  }

  Future<void> _onResendRequested(
    OtpResendRequested event,
    Emitter<OtpState> emit,
  ) async {
    // Only when the wait is over, or the last send failed: a double tap or a
    // stale button must not send the member a second message.
    final allowed = switch (state) {
      OtpAwaitingCode(:final resendIn) => resendIn == 0,
      OtpCodeUnusable(:final resendIn) => resendIn == 0,
      OtpSendFailed() => true,
      _ => false,
    };
    if (!allowed || _request == null) return;

    await _sendNewCode(emit);
  }

  Future<void> _sendNewCode(Emitter<OtpState> emit) async {
    _stopTicking();
    // The old code dies the moment a new one is asked for, even if the send
    // then fails: nothing the member holds can be used any more.
    _code = null;
    emit(const OtpSending());

    final code = _generator.generate();
    final result = await _sendOtp(
      SendOtpParams(request: _request!, code: code),
    );

    result.fold((failure) => emit(OtpSendFailed(failure.message)), (_) {
      _code = code;
      _resendIn = resendSeconds;
      _expiresIn = lifetimeSeconds;
      _attemptsLeft = maxAttempts;
      emit(_awaiting());
      _startTicking();
    });
  }

  void _onCodeSubmitted(OtpCodeSubmitted event, Emitter<OtpState> emit) {
    final code = _code;
    if (state is! OtpAwaitingCode || code == null) return;

    if (event.code == code) {
      _stopTicking();
      _code = null;
      emit(const OtpVerified());
      return;
    }

    _attemptsLeft -= 1;
    if (_attemptsLeft <= 0) {
      _code = null;
      emit(
        OtpCodeUnusable(
          reason: OtpUnusableReason.tooManyAttempts,
          resendIn: _resendIn,
        ),
      );
    } else {
      emit(_awaiting(lastWasWrong: true));
    }
  }

  void _onTicked(OtpTicked event, Emitter<OtpState> emit) {
    final current = state;
    if (current is! OtpAwaitingCode && current is! OtpCodeUnusable) return;

    if (_resendIn > 0) _resendIn -= 1;

    if (current is OtpAwaitingCode) {
      _expiresIn -= 1;
      if (_expiresIn <= 0) {
        _code = null;
        emit(
          OtpCodeUnusable(
            reason: OtpUnusableReason.expired,
            resendIn: _resendIn,
          ),
        );
        return;
      }
      emit(_awaiting(lastWasWrong: current.lastWasWrong));
    } else if (current is OtpCodeUnusable) {
      emit(OtpCodeUnusable(reason: current.reason, resendIn: _resendIn));
      // Nothing left to count down once "Kirim ulang" is available.
      if (_resendIn == 0) _stopTicking();
    }
  }

  OtpAwaitingCode _awaiting({bool lastWasWrong = false}) => OtpAwaitingCode(
    resendIn: _resendIn,
    expiresIn: _expiresIn,
    attemptsLeft: _attemptsLeft,
    lastWasWrong: lastWasWrong,
  );

  void _startTicking() {
    _stopTicking();
    _ticking = _ticker().listen((_) => add(const OtpTicked()));
  }

  void _stopTicking() {
    _ticking?.cancel();
    _ticking = null;
  }

  @override
  Future<void> close() {
    _stopTicking();
    _code = null;
    return super.close();
  }
}
