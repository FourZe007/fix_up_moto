import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/domain/repositories/workshops_repository.dart';

class GetWorkshopsUseCase extends NoParamsUseCase<List<WorkshopEntity>> {
  final WorkshopsRepository repository;
  GetWorkshopsUseCase(this.repository);

  @override
  Future<Either<Failure, List<WorkshopEntity>>> call() {
    return repository.getWorkshops();
  }
}
