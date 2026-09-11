import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/workshops/domain/usecases/get_workshops_usecase.dart';
import 'workshops_event.dart';
import 'workshops_state.dart';

/// Provided at the [WorkshopListPage] level — not global — since it's only
/// needed there.
class WorkshopsBloc extends Bloc<WorkshopsEvent, WorkshopsState> {
  final GetWorkshopsUseCase _getWorkshops;

  WorkshopsBloc({required GetWorkshopsUseCase getWorkshops})
      : _getWorkshops = getWorkshops,
        super(const WorkshopsInitial()) {
    on<WorkshopsRequested>(_onRequested);
  }

  Future<void> _onRequested(
    WorkshopsRequested event,
    Emitter<WorkshopsState> emit,
  ) async {
    emit(const WorkshopsLoading());
    final result = await _getWorkshops();
    result.fold(
      (failure) => emit(WorkshopsError(failure.message)),
      (workshops) => emit(WorkshopsLoaded(workshops)),
    );
  }
}
