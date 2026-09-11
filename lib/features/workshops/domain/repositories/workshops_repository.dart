import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';

abstract class WorkshopsRepository {
  Future<Either<Failure, List<WorkshopEntity>>> getWorkshops();
}
