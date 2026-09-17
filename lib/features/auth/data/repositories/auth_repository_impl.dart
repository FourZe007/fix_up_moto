import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_remote_data_source.dart';

/// Concrete implementation of [AuthRepository].
///
/// Acts as the **translation bridge** between the Data layer and the Domain
/// contract. Its responsibilities are:
/// 1. Check connectivity before network calls
/// 2. Call the appropriate data source (remote or local)
/// 3. Catch raw [Exception]s and convert them to typed [Failure]s
/// 4. Return [Either<Failure, Entity>] — never throws across layer boundaries
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  const AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserEntity>> login(
    String phone,
    String password,
  ) async {
    // Check connectivity first to give an immediate, friendly error instead
    // of waiting for a 30-second Dio timeout.
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      log(
        'Auth Repo Impl: phone: $phone; password: $password',
        name: 'AuthRepoImpl login',
      );
      final userModel = await remoteDataSource.login(phone, password);

      // Persist the user in secure storage so the next launch skips login
      await localDataSource.cacheUser(userModel);

      // Convert model → entity before returning to the Domain layer
      return Right(userModel.toEntity());
    } on UnauthorizedException {
      // HTTP 401 — wrong phone/password combination
      return const Left(AuthFailure('Invalid phone number or password'));
    } on AccountInactiveException catch (e) {
      // Credentials were correct but the membership is barred from signing in.
      // Pass the server's own wording straight through — it knows why.
      return Left(AuthFailure(e.message));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      // Login succeeded but we couldn't cache the session —
      // return success anyway; worst case the user re-logs in next launch.
      // Log this in production with your preferred crash reporter.
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, GoogleAccountIdentity>> getGoogleIdentity() async {
    // No connectivity check — this only talks to Google, not the backend.
    try {
      final identity = await remoteDataSource.getGoogleIdentity();
      return Right(identity);
    } on GoogleSignInCancelledException {
      // Deliberately its own arm: the BLoC checks for this type and stays
      // silent rather than showing an error the user did not cause.
      return const Left(AuthCancelledFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> submitGoogleAccount({
    required String name,
    required String phone,
    required String email,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final userModel = await remoteDataSource.submitGoogleAccount(
        name: name,
        phone: phone,
        email: email,
      );
      await localDataSource.cacheUser(userModel);

      // Remember this email→phone link regardless of which phase succeeded
      // (existing login, or fresh registration) — either way, this Google
      // account now has a working phone, and the next sign-in with it should
      // skip the complete-profile form entirely.
      await localDataSource.rememberGooglePhone(email: email, phone: phone);

      return Right(userModel.toEntity());
    } on AccountInactiveException catch (e) {
      return Left(AuthFailure(e.message));
    } on UnauthorizedException {
      return const Left(AuthFailure('Session expired. Please sign in again.'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String?>> getRememberedGooglePhone(
    String email,
  ) async {
    try {
      final phone = await localDataSource.getRememberedGooglePhone(email);
      return Right(phone);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String name,
    required String phone,
    String? email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final userModel = await remoteDataSource.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
      );
      await localDataSource.cacheUser(userModel);
      return Right(userModel.toEntity());
    } on UnauthorizedException {
      return const Left(AuthFailure('Session expired. Please sign in again.'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    // No remote call: there is no logout endpoint on this backend, and no
    // server-side session to invalidate even if there were one — the cached
    // member record IS the session, so clearing it locally is the whole of
    // signing out.
    try {
      await localDataSource.clearUser();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final userModel = await localDataSource.getCachedUser();

      // null is a valid return — means "not logged in", not an error
      return Right(userModel?.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
