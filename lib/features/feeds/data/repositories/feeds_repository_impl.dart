import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/feeds/data/datasources/feeds_remote_data_source.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';
import 'package:fix_up_moto/features/feeds/domain/repositories/feeds_repository.dart';

class FeedsRepositoryImpl implements FeedsRepository {
  final FeedsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  const FeedsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<FeedEntity>>> getFeeds() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final models = await remoteDataSource.getFeeds();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
