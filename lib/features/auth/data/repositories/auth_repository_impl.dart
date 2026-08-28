import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
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
  Future<Either<Failure, UserEntity>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final userModel = await remoteDataSource.register(
        name: name,
        email: email,
        password: password,
      );
      await localDataSource.cacheUser(userModel);
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    // The two halves are separated on purpose. Previously the local clear sat
    // after the server call inside one try block, so anything the remote threw
    // that wasn't a ServerException — a NotFoundException from a 404, say —
    // escaped and left the session on disk. The user tapped Sign Out and stayed
    // signed in.
    try {
      await remoteDataSource.logout();
    } catch (_) {
      // Best effort, and deliberately catching everything: 404, 500, offline,
      // timeout all warrant the same response, which is to carry on. A member
      // must always be able to sign out of their own device regardless of what
      // the backend has to say about it.
    }

    try {
      // This is what actually ends the session — the cached member record IS
      // the session, so clearing it is the whole of signing out.
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
