import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/bikes_repository.dart';

class UpdateBikeUseCase extends UseCase<void, UpdateBikeParams> {
  final BikesRepository repository;
  UpdateBikeUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateBikeParams params) {
    return repository.updateBike(
      line: params.line,
      plateNo: params.plateNo,
      unitId: params.unitId,
      chasisNo: params.chasisNo,
      engineNo: params.engineNo,
      color: params.color,
      year: params.year,
      photo: params.photo,
    );
  }
}

class UpdateBikeParams extends Equatable {
  /// The record's row number, as the list returned it — says which bike this
  /// is. Never edited.
  final String line;

  /// An ordinary field, editable like the rest.
  final String plateNo;
  final String unitId; // brand name with its variant
  final String chasisNo;
  final String engineNo;
  final String color;
  final String year;
  final String photo;

  const UpdateBikeParams({
    required this.line,
    required this.plateNo,
    required this.unitId,
    required this.chasisNo,
    required this.engineNo,
    required this.color,
    required this.year,
    required this.photo,
  });

  @override
  List<Object> get props => [
    line,
    plateNo,
    unitId,
    chasisNo,
    engineNo,
    color,
    year,
    photo,
  ];
}
