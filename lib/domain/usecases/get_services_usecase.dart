import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/service_entity.dart';
import 'package:fix_up_moto/domain/repositories/services_repository.dart';

class GetServicesUseCase extends UseCase<List<ServiceEntity>, GetServicesParams> {
  final ServicesRepository repository;
  GetServicesUseCase(this.repository);

  @override
  Future<Either<Failure, List<ServiceEntity>>> call(GetServicesParams params) {
    return repository.getServices(categoryId: params.categoryId);
  }
}

class GetServicesParams extends Equatable {
  /// When null, all services are returned regardless of category.
  final String? categoryId;
  const GetServicesParams({this.categoryId});

  @override
  List<Object?> get props => [categoryId];
}
