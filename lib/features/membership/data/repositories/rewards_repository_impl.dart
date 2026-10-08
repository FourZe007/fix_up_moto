import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/membership/data/datasources/rewards_remote_data_source.dart';
import 'package:fix_up_moto/features/membership/domain/entities/reward_entity.dart';
import 'package:fix_up_moto/features/membership/domain/repositories/rewards_repository.dart';

class RewardsRepositoryImpl implements RewardsRepository {
  final RewardsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  /// Redeeming spends *this member's* points, and the backend has no "who am I"
  /// endpoint — the caller supplies MemberID itself. The cached session, read
  /// through Auth's own repository (see HomeRepositoryImpl for why not a use
  /// case), is the only place it exists on the client. Listing the vouchers
  /// needs no member, so only [redeemReward] reads it.
  final AuthRepository authRepository;

  const RewardsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.authRepository,
  });

  @override
  Future<Either<Failure, List<RewardEntity>>> getRewards() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final models = await remoteDataSource.getRewards();
      return Right(models.map((m) => m.toEntity()).toList());
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
  Future<Either<Failure, String>> redeemReward({
    required String pointId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    final currentUserResult = await authRepository.getCurrentUser();

    return currentUserResult.fold((failure) async => Left(failure), (
      user,
    ) async {
      if (user == null) {
        return const Left(AuthFailure('No signed-in member found'));
      }

      try {
        final result = await remoteDataSource.redeemReward(
          memberId: user.id,
          pointId: pointId,
        );

        return Right(result.resultMessage);
      } on UnauthorizedException {
        return const Left(
          AuthFailure('Session expired. Please sign in again.'),
        );
      } on ForbiddenException catch (e) {
        return Left(PermissionFailure(e.message));
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message, statusCode: e.statusCode));
      }
    });
  }
}
