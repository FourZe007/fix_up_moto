import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/password_reset/domain/repositories/password_reset_repository.dart';

/// Sets a new password for a member who has forgotten the old one.
class ResetPasswordUseCase extends UseCase<void, ResetPasswordParams> {
  final PasswordResetRepository repository;
  ResetPasswordUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ResetPasswordParams params) {
    return repository.resetPassword(
      memberId: params.memberId,
      newPassword: params.newPassword,
    );
  }
}

class ResetPasswordParams extends Equatable {
  final String memberId;

  /// Exactly as typed — passwords are never trimmed.
  final String newPassword;

  const ResetPasswordParams({
    required this.memberId,
    required this.newPassword,
  });

  @override
  List<Object> get props => [memberId, newPassword];
}
