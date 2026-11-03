import 'package:equatable/equatable.dart';

import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';

sealed class OtpEvent extends Equatable {
  const OtpEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened: make a code and send it.
final class OtpStarted extends OtpEvent {
  final OtpRequest request;

  const OtpStarted(this.request);

  @override
  List<Object> get props => [request];
}

/// The member typed a full code and asked to check it.
final class OtpCodeSubmitted extends OtpEvent {
  final String code;

  const OtpCodeSubmitted(this.code);

  @override
  List<Object> get props => [code];
}

/// "Kirim ulang kode": make a new code and send it. The old one dies.
final class OtpResendRequested extends OtpEvent {
  const OtpResendRequested();
}

/// One second passed. Sent by the bloc to itself, never by the page.
final class OtpTicked extends OtpEvent {
  const OtpTicked();
}
