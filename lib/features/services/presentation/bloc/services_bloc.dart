import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/services/domain/usecases/get_services_usecase.dart';
import 'services_event.dart';
import 'services_state.dart';

class ServicesBloc extends Bloc<ServicesEvent, ServicesState> {
  final GetServicesUseCase _getServices;

  ServicesBloc({required GetServicesUseCase getServices})
    : _getServices = getServices,
      super(const ServicesInitial()) {
    on<ServicesListRequested>(_onListRequested);
    on<ServicesRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onListRequested(
    ServicesListRequested event,
    Emitter<ServicesState> emit,
  ) async {
    emit(const ServicesLoading());
    await _load(event.serviceType, event.plateNo, emit);
  }

  /// Like [_onListRequested], but a list already on screen stays there while the
  /// new one is fetched. With nothing on screen to keep, it is an ordinary load.
  Future<void> _onRefreshRequested(
    ServicesRefreshRequested event,
    Emitter<ServicesState> emit,
  ) async {
    final current = state;
    if (current is! ServicesLoaded) {
      emit(const ServicesLoading());
      await _load(event.serviceType, event.plateNo, emit);
      return;
    }

    final refreshing = ServicesLoaded(current.services, refreshing: true);
    emit(refreshing);

    // Another request (a different bike, say) may take over while this one is
    // on its way; its answer then belongs on screen, not this one's.
    await _load(
      event.serviceType,
      event.plateNo,
      emit,
      stillWanted: () => identical(state, refreshing),
    );
  }

  Future<void> _load(
    String serviceType,
    String plateNo,
    Emitter<ServicesState> emit, {
    bool Function()? stillWanted,
  }) async {
    final result = await _getServices(
      GetServicesParams(serviceType: serviceType, plateNo: plateNo),
    );
    if (stillWanted != null && !stillWanted()) return;
    result.fold(
      (f) => emit(ServicesError(f.message)),
      (list) => emit(ServicesLoaded(list)),
    );
  }
}
