import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/domain/repositories/auth_repository.dart';

/// Clears the local session (token + cached user) and invalidates the
/// server-side session.
///
/// Returns `Right(null)` on success.
/// Returns `Left(CacheFailure)` if local storage deletion fails.
class LogoutUseCase extends UseCase<void, NoParams> {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.logout();
  }
}
