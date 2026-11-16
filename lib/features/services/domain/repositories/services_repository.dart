import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';

abstract class ServicesRepository {
  /// Returns the service history of the bike with [plateNo]. The plate is
  /// required: the backend answers per plate, never per member.
  Future<Either<Failure, List<ServiceEntity>>> getServices({
    String serviceType = 'SERVICEHISTORY',
    required String plateNo,
  });
}
