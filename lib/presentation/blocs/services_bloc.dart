import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/domain/usecases/get_service_detail_usecase.dart';
import 'package:fix_up_moto/domain/usecases/get_services_usecase.dart';
import 'services_event.dart';
import 'services_state.dart';

class ServicesBloc extends Bloc<ServicesEvent, ServicesState> {
  final GetServicesUseCase _getServices;
  final GetServiceDetailUseCase _getServiceDetail;

  ServicesBloc({
    required GetServicesUseCase getServices,
    required GetServiceDetailUseCase getServiceDetail,
  })  : _getServices = getServices,
        _getServiceDetail = getServiceDetail,
        super(const ServicesInitial()) {
    on<ServicesListRequested>(_onListRequested);
    on<ServiceDetailRequested>(_onDetailRequested);
  }

  Future<void> _onListRequested(
    ServicesListRequested event,
    Emitter<ServicesState> emit,
  ) async {
    emit(const ServicesLoading());
    final result = await _getServices(
      GetServicesParams(categoryId: event.categoryId),
    );
    result.fold(
      (f) => emit(ServicesError(f.message)),
      (list) => emit(ServicesLoaded(list)),
    );
  }

  Future<void> _onDetailRequested(
    ServiceDetailRequested event,
    Emitter<ServicesState> emit,
  ) async {
    emit(const ServicesLoading());
    final result = await _getServiceDetail(
      ServiceDetailParams(event.serviceId),
    );
    result.fold(
      (f) => emit(ServicesError(f.message)),
      (service) => emit(ServiceDetailLoaded(service)),
    );
  }
}
