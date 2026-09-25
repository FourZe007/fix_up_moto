import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';

abstract class BikesRepository {
  Future<Either<Failure, List<BikeEntity>>> getBikes({
    required String memberId,
  });

  Future<Either<Failure, BikeEntity>> addBike({
    required String memberId,
    required String plateNumber,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required int year,
    required String photo,
  });
}
