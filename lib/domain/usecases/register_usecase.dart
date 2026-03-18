import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/user_entity.dart';
import 'package:fix_up_moto/domain/repositories/auth_repository.dart';

/// Creates a new user account and returns the created [UserEntity] on success.
/// The repository also auto-logs the user in, so no separate login call is needed.
class RegisterUseCase extends UseCase<UserEntity, RegisterParams> {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(RegisterParams params) {
    return repository.register(
      name: params.name,
      email: params.email,
      password: params.password,
    );
  }
}

/// Input value object for [RegisterUseCase].
class RegisterParams extends Equatable {
  final String name;
  final String email;
  final String password;

  const RegisterParams({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [name, email, password];
}
