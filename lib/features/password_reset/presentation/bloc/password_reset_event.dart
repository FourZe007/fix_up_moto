import 'package:equatable/equatable.dart';

sealed class PasswordResetEvent extends Equatable {
  const PasswordResetEvent();
  @override
  List<Object?> get props => [];
}

/// The member typed their phone number and asked for a code: find who it
/// belongs to first.
final class PasswordResetMemberRequested extends PasswordResetEvent {
  /// As typed.
  final String phone;
  const PasswordResetMemberRequested(this.phone);

  @override
  List<Object?> get props => [phone];
}

/// The member chose a new password after typing the right code. The password is
/// exactly as typed — never trimmed.
final class PasswordResetSubmitted extends PasswordResetEvent {
  final String memberId;
  final String newPassword;
  const PasswordResetSubmitted({
    required this.memberId,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [memberId, newPassword];
}
