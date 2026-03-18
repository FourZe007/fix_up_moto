import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/user_entity.dart';
import 'package:fix_up_moto/domain/repositories/auth_repository.dart';

/// Authenticates a user with email and password.
///
/// A use case encapsulates exactly one business action. It delegates to
/// [AuthRepository] and may add cross-cutting logic (e.g. pre-validation,
/// analytics) without the Presentation layer knowing about it.
class LoginUseCase extends UseCase<UserEntity, LoginParams> {
  /// Injected via constructor — [LoginUseCase] never instantiates [AuthRepository]
  final AuthRepository repository;

  LoginUseCase(this.repository);

  /// Executes the login action.
  /// Callers invoke this like a function: `await loginUseCase(params)`
  @override
  Future<Either<Failure, UserEntity>> call(LoginParams params) {
    // Delegate entirely to the repository — no duplicated business logic
    return repository.login(params.email, params.password);
  }
}

/// Input value object for [LoginUseCase].
///
/// Grouping params into a class (instead of positional arguments) allows:
/// - Equatable comparison in bloc_test assertions
/// - Easy extension if new fields are added (e.g. deviceId for 2FA)
class LoginParams extends Equatable {
  final String email;
  final String password;

  const LoginParams({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}
