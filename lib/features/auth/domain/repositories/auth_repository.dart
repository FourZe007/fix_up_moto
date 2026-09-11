import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
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
  /// Authenticates the member with [phone] and [password].
  ///
  /// [phone] is the number as the member typed it — the data layer normalises
  /// it to the subscriber form the backend expects.
  ///
  /// On success: caches the member record locally and returns the [UserEntity].
  /// On failure: returns [AuthFailure] for bad credentials or an inactive
  /// membership, [ServerFailure] for API errors, or [NetworkFailure] if offline.
  Future<Either<Failure, UserEntity>> login(String phone, String password);

  /// Opens the Google account sheet and returns the chosen account's identity.
  ///
  /// Establishes nothing with the backend — see [submitGoogleAccount] for that.
  /// Returns [AuthCancelledFailure] when the user dismisses the sheet —
  /// callers must treat that as "nothing happened", not as an error to display.
  Future<Either<Failure, GoogleAccountIdentity>> getGoogleIdentity();

  /// Completes a Google sign-up: logs in if [phone] is already registered
  /// (using a password derived from [name]), otherwise registers a new member
  /// and logs in immediately after.
  ///
  /// On success: caches the member record and returns the [UserEntity].
  Future<Either<Failure, UserEntity>> submitGoogleAccount({
    required String name,
    required String phone,
    required String email,
  });

  /// Returns the phone number this device previously linked to the Google
  /// account [email] via a successful [submitGoogleAccount], or
  /// `Right(null)` if this Google account has never completed sign-up here.
  ///
  /// Lets a returning Google sign-in skip straight to a real login instead of
  /// asking for the phone number again on the complete-profile form.
  Future<Either<Failure, String?>> getRememberedGooglePhone(String email);

  /// Creates a new account with [name], [phone], and [password] — [email] is
  /// optional.
  ///
  /// On success: auto-logs in and returns the created [UserEntity].
  Future<Either<Failure, UserEntity>> register({
    required String name,
    required String phone,
    String? email,
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
