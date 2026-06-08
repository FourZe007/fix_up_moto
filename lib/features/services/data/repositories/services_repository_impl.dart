import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/domain/repositories/services_repository.dart';
import 'package:fix_up_moto/features/services/data/datasources/services_remote_data_source.dart';

class ServicesRepositoryImpl implements ServicesRepository {
  final ServicesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  const ServicesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ServiceEntity>>> getServices({
    String? categoryId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final models = await remoteDataSource.getServices(categoryId: categoryId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ServiceEntity>> getServiceDetail(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final model = await remoteDataSource.getServiceDetail(id);
      return Right(model.toEntity());
    } on NotFoundException {
      return const Left(NotFoundFailure('Service not found'));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
