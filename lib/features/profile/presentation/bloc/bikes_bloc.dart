import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/add_bike_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/get_bikes_usecase.dart';
import 'bikes_event.dart';
import 'bikes_state.dart';

/// The member's registered bikes — split out from [ProfileBloc] since it's a
/// separate, growing domain (more bike-specific actions planned, reusable
/// from other screens) rather than the member's own account data. Depends on
/// GetBikesUseCase/AddBikeUseCase unchanged — only which Bloc calls them
/// moved.
class BikesBloc extends Bloc<BikesEvent, BikesState> {
  final GetBikesUseCase _getBikes;
  final AddBikeUseCase _addBike;

  BikesBloc({
    required GetBikesUseCase getBikes,
    required AddBikeUseCase addBike,
  }) : _getBikes = getBikes,
       _addBike = addBike,
       super(const BikesInitial()) {
    on<BikesLoadRequested>(_onLoadRequested);
    on<BikeAddRequested>(_onAddRequested);
  }

  Future<void> _onLoadRequested(
    BikesLoadRequested event,
    Emitter<BikesState> emit,
  ) async {
    emit(const BikesLoading());
    final result = await _getBikes(GetBikesParams(memberId: event.memberId));
    result.fold(
      (f) => emit(BikesError(f.message)),
      (bikes) => emit(BikesLoaded(bikes)),
    );
  }

  Future<void> _onAddRequested(
    BikeAddRequested event,
    Emitter<BikesState> emit,
  ) async {
    emit(const BikesLoading());
    final result = await _addBike(
      AddBikeParams(
        brand: event.brand,
        model: event.model,
        year: event.year,
        plateNumber: event.plateNumber,
      ),
    );
    result.fold(
      (f) => emit(BikesError(f.message)),
      // Emit success then re-load the list so it reflects the new bike —
      // same pattern BookingsBloc uses after creating a booking.
      (_) {
        emit(const BikeActionSuccess('Bike added successfully'));
        add(BikesLoadRequested(memberId: event.memberId));
      },
    );
  }
}
