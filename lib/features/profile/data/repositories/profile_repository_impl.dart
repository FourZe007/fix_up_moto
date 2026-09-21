import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/profile_repository.dart';
import 'package:fix_up_moto/features/profile/data/datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  const ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserEntity>> getProfile() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final model = await remoteDataSource.getProfile();
      return Right(model.toEntity());
    } on UnauthorizedException {
      return const Left(AuthFailure('Session expired. Please sign in again.'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    required String name,
    String? phone,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final model = await remoteDataSource.updateProfile(
        name: name,
        phone: phone,
      );
      return Right(model.toEntity());
    } on UnauthorizedException {
      return const Left(AuthFailure('Session expired. Please sign in again.'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
