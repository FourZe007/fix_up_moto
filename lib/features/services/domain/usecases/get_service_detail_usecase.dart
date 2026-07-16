import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/domain/repositories/services_repository.dart';

class GetServiceDetailUseCase extends UseCase<ServiceEntity, ServiceDetailParams> {
  final ServicesRepository repository;
  GetServiceDetailUseCase(this.repository);

  @override
  Future<Either<Failure, ServiceEntity>> call(ServiceDetailParams params) {
    return repository.getServiceDetail(params.serviceId);
  }
}

class ServiceDetailParams extends Equatable {
  final String serviceId;
  const ServiceDetailParams(this.serviceId);

  @override
  List<Object> get props => [serviceId];
}
