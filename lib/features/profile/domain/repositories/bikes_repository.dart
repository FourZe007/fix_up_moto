import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';

abstract class BikesRepository {
  Future<Either<Failure, List<BikeEntity>>> getBikes({
    required String memberId,
  });
  Future<Either<Failure, BikeEntity>> addBike({
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
  });
}
