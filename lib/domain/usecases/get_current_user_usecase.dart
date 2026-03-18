import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/user_entity.dart';
import 'package:fix_up_moto/domain/repositories/auth_repository.dart';

/// Reads the currently authenticated user from the local cache.
///
/// Called on app start to restore a previous session without requiring
/// the user to log in again. Returns:
/// - `Right(UserEntity)` — a valid cached session was found
/// - `Right(null)`       — no session exists (first launch, or after logout)
/// - `Left(CacheFailure)` — storage read failed unexpectedly
class GetCurrentUserUseCase extends NoParamsUseCase<UserEntity?> {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity?>> call() {
    return repository.getCurrentUser();
  }
}
