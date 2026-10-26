import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';

abstract class BikesRepository {
  Future<Either<Failure, List<BikeEntity>>> getBikes(
    /*{
    required String memberId,
  }*/
  );

  // Returns the raw confirmation message the backend sends back
  // (REGISTERMOTOR's response has no full bike record to hand back, just a
  // `ResultMessage` string), not a BikeEntity — nothing currently consumes
  // this value beyond confirming success, so there's nothing to reconstruct
  // an entity out of.
  Future<Either<Failure, String>> addBike({
    // required String memberId,
    required String plateNumber,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required String year,
    required String photo,
  });

  // Saves changes to a registered bike. [plateNo] is the bike's key — the
  // backend has no other identifier — so it is the original plate, unchanged,
  // and the edit form never lets it be edited. Nothing comes back to use, like
  // ProfileRepository.updateProfile: the caller just reloads the list.
  Future<Either<Failure, void>> updateBike({
    required String plateNo,
    required String unitId, // brand name with its variant
    required String chasisNo,
    required String engineNo,
    required String color,
    required String year,
    required String photo,
  });
}
