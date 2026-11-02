import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/profile_repository.dart';

class ChangePasswordUseCase extends UseCase<void, ChangePasswordParams> {
  final ProfileRepository repository;
  ChangePasswordUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ChangePasswordParams params) {
    return repository.changePassword(
      oldPassword: params.oldPassword,
      newPassword: params.newPassword,
    );
  }
}

class ChangePasswordParams extends Equatable {
  final String oldPassword;
  final String newPassword;
  const ChangePasswordParams({
    required this.oldPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [oldPassword, newPassword];
}
