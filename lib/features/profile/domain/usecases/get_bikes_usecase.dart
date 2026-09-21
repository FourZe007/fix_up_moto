import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/bikes_repository.dart';

class GetBikesUseCase extends UseCase<List<BikeEntity>, GetBikesParams> {
  final BikesRepository repository;
  GetBikesUseCase(this.repository);

  @override
  Future<Either<Failure, List<BikeEntity>>> call(GetBikesParams params) =>
      repository.getBikes(memberId: params.memberId);
}

class GetBikesParams extends Equatable {
  final String memberId;

  const GetBikesParams({required this.memberId});

  @override
  List<Object> get props => [memberId];
}
