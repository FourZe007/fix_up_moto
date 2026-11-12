import 'package:equatable/equatable.dart';

import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';

sealed class PasswordResetState extends Equatable {
  const PasswordResetState();
  @override
  List<Object?> get props => [];
}

final class PasswordResetInitial extends PasswordResetState {
  const PasswordResetInitial();
}

final class PasswordResetLoading extends PasswordResetState {
  const PasswordResetLoading();
}

/// The number belongs to a member: the page can now ask for the code.
final class PasswordResetMemberFound extends PasswordResetState {
  final PasswordResetMember member;
  const PasswordResetMemberFound(this.member);

  @override
  List<Object?> get props => [member];
}

/// The new password is set.
final class PasswordResetSuccess extends PasswordResetState {
  const PasswordResetSuccess();
}

final class PasswordResetError extends PasswordResetState {
  final String message;
  const PasswordResetError(this.message);

  @override
  List<Object?> get props => [message];
}
