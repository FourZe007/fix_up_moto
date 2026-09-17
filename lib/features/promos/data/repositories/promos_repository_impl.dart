import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/promos/data/datasources/promos_remote_data_source.dart';
import 'package:fix_up_moto/features/promos/domain/entities/promo_image_entity.dart';
import 'package:fix_up_moto/features/promos/domain/repositories/promos_repository.dart';

class PromosRepositoryImpl implements PromosRepository {
  final PromosRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  const PromosRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<PromoImageEntity>>> getPromoImages() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final models = await remoteDataSource.getPromoImages();
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
}
