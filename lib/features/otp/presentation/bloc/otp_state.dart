import 'package:equatable/equatable.dart';

/// What the OTP page should show. **No state ever carries the code**: it lives
/// only inside [OtpBloc], so it cannot end up in a log, a snapshot or a widget.
sealed class OtpState extends Equatable {
  const OtpState();

  @override
  List<Object?> get props => [];
}

final class OtpInitial extends OtpState {
  const OtpInitial();
}

/// A code was made and is on its way to the backend.
final class OtpSending extends OtpState {
  const OtpSending();
}

/// The code is out; the member can type it.
final class OtpAwaitingCode extends OtpState {
  /// Seconds until "Kirim ulang" works again. 0 means it works now.
  final int resendIn;

  /// Seconds until the code stops being accepted.
  final int expiresIn;

  /// Wrong tries left before the code is thrown away.
  final int attemptsLeft;

  /// The last code that was submitted was wrong.
  final bool lastWasWrong;

  const OtpAwaitingCode({
    required this.resendIn,
    required this.expiresIn,
    required this.attemptsLeft,
    this.lastWasWrong = false,
  });

  @override
  List<Object> get props => [resendIn, expiresIn, attemptsLeft, lastWasWrong];
}

enum OtpUnusableReason { expired, tooManyAttempts }

/// The code can no longer be used; only a new one helps.
final class OtpCodeUnusable extends OtpState {
  final OtpUnusableReason reason;

  /// Seconds until "Kirim ulang" works again. 0 means it works now.
  final int resendIn;

  const OtpCodeUnusable({required this.reason, required this.resendIn});

  @override
  List<Object> get props => [reason, resendIn];
}

/// The backend would not take the code (no connection, a refusal, …). Nothing
/// was delivered, so there is nothing to type: only trying again helps.
final class OtpSendFailed extends OtpState {
  final String message;

  const OtpSendFailed(this.message);

  @override
  List<Object> get props => [message];
}

/// The right code was typed. The page closes with `true`.
final class OtpVerified extends OtpState {
  const OtpVerified();
}
