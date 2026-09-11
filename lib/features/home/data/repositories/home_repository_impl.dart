import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/domain/repositories/home_repository.dart';
import 'package:fix_up_moto/features/home/data/datasources/home_remote_data_source.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  /// Auth's repository, not a use case: [HomeRepositoryImpl] is itself a
  /// repository, and use cases are meant for the presentation layer to
  /// consume, not for one repository to call into another. Reading through
  /// [AuthRepository.getCurrentUser] also means the CacheException → Failure
  /// translation already written there isn't duplicated here.
  final AuthRepository authRepository;

  const HomeRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.authRepository,
  });

  @override
  Future<Either<Failure, DashboardStatsEntity>> getDashboardStats() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    // The dashboard is keyed to the signed-in member, and the backend has no
    // "who am I" endpoint — every /apiSAMP/* call expects the caller to
    // supply MemberID itself. The cached session, read here, is the only
    // place that ID exists on the client.
    final currentUserResult = await authRepository.getCurrentUser();

    return currentUserResult.fold(
      (failure) async => Left(failure),
      (user) async {
        if (user == null) {
          // The router guard makes this screen unreachable while signed out,
          // so this only fires if the cache was cleared out from under an
          // already-open Home tab (e.g. a logout on another screen mid-fetch).
          return const Left(AuthFailure('No signed-in member found'));
        }

        try {
          final model = await remoteDataSource.getMotorcycleStats(user.id);
          return Right(model.toEntity());
        } on ServerException catch (e) {
          return Left(ServerFailure(e.message, statusCode: e.statusCode));
        }
      },
    );
  }
}
