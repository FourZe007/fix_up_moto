import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/bikes_repository.dart';

class AddBikeUseCase extends UseCase<BikeEntity, AddBikeParams> {
  final BikesRepository repository;
  AddBikeUseCase(this.repository);

  @override
  Future<Either<Failure, BikeEntity>> call(AddBikeParams params) {
    return repository.addBike(
      memberId: params.memberId,
      plateNumber: params.plateNumber,
      unitId: params.unitId,
      chasisNo: params.chasisNo,
      engineNo: params.engineNo,
      color: params.color,
      year: params.year,
      photo: params.photo,
    );
  }
}

class AddBikeParams extends Equatable {
  final String memberId;
  final String plateNumber;
  final String unitId; // brand name with its variant
  final String chasisNo;
  final String engineNo;
  final String color;
  final int year;
  final String photo;

  const AddBikeParams({
    required this.memberId,
    required this.plateNumber,
    required this.unitId, // brand name with its variant
    required this.chasisNo,
    required this.engineNo,
    required this.color,
    required this.year,
    required this.photo,
  });

  @override
  List<Object> get props => [
    memberId,
    plateNumber,
    unitId,
    chasisNo,
    engineNo,
    color,
    year,
    photo,
  ];
}
