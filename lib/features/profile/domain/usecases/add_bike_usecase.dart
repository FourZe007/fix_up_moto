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
      brand: params.brand,
      model: params.model,
      year: params.year,
      plateNumber: params.plateNumber,
    );
  }
}

class AddBikeParams extends Equatable {
  final String brand;
  final String model;
  final int year;
  final String plateNumber;

  const AddBikeParams({
    required this.brand,
    required this.model,
    required this.year,
    required this.plateNumber,
  });

  @override
  List<Object> get props => [brand, model, year, plateNumber];
}
