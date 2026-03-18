import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/entities/service_entity.dart';

abstract class ServicesRepository {
  /// Returns all available services, optionally filtered by [categoryId].
  Future<Either<Failure, List<ServiceEntity>>> getServices({
    String? categoryId,
  });

  /// Returns full details for the service identified by [id].
  Future<Either<Failure, ServiceEntity>> getServiceDetail(String id);
}
