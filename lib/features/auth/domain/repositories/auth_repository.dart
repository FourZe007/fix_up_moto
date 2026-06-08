import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';

/// Abstract contract for authentication operations.
///
/// **Why an interface here?**
/// The Domain layer declares *what* operations exist but not *how* they work.
/// The Data layer provides the concrete [AuthRepositoryImpl] that hits the
/// network and local storage. This inversion means:
/// - Domain has zero dependency on Dio, FlutterSecureStorage, or any platform
/// - Tests can swap in a fake repository without touching networking code
///
/// All methods return `Either<Failure, T>`:
/// - `Left(Failure)` — something went wrong; caller pattern-matches on type
/// - `Right(T)`      — success; caller extracts the value
abstract class AuthRepository {
  /// Authenticates the user with [email] and [password].
  ///
  /// On success: caches the returned token locally and returns the [UserEntity].
  /// On failure: returns [AuthFailure] for bad credentials, [ServerFailure]
  /// for API errors, or [NetworkFailure] if offline.
  Future<Either<Failure, UserEntity>> login(String email, String password);

  /// Creates a new account with [name], [email], and [password].
  ///
  /// On success: auto-logs in and returns the created [UserEntity].
  Future<Either<Failure, UserEntity>> register({
    required String name,
    required String email,
    required String password,
  });

  /// Invalidates the server-side session and clears all locally cached tokens.
  Future<Either<Failure, void>> logout();

  /// Reads the currently authenticated user from the local cache.
  ///
  /// Returns `Right(UserEntity)` if a cached session exists,
  /// `Right(null)` if the user has never logged in or has logged out,
  /// or `Left(CacheFailure)` if the storage read fails unexpectedly.
  Future<Either<Failure, UserEntity?>> getCurrentUser();
}
