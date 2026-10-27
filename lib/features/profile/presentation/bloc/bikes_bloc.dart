import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/add_bike_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/delete_bike_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/get_bikes_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/update_bike_usecase.dart';
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
  final UpdateBikeUseCase _updateBike;
  final DeleteBikeUseCase _deleteBike;

  BikesBloc({
    required GetBikesUseCase getBikes,
    required AddBikeUseCase addBike,
    required UpdateBikeUseCase updateBike,
    required DeleteBikeUseCase deleteBike,
  }) : _getBikes = getBikes,
       _addBike = addBike,
       _updateBike = updateBike,
       _deleteBike = deleteBike,
       super(const BikesInitial()) {
    on<BikesLoadRequested>(_onLoadRequested);
    on<BikeAddRequested>(_onAddRequested);
    on<BikeUpdateRequested>(_onUpdateRequested);
    on<BikeDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    BikesLoadRequested event,
    Emitter<BikesState> emit,
  ) async {
    emit(const BikesLoading());
    final result = await _getBikes(GetBikesParams());
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
        plateNumber: event.plateNumber,
        unitId: event.unitId,
        chasisNo: event.chasisNo,
        engineNo: event.engineNo,
        color: event.color,
        year: event.year,
        photo: event.photo,
      ),
    );

    result.fold(
      (f) => emit(BikesError(f.message)),
      // Emit success then re-load the list so it reflects the new bike —
      // same pattern BookingsBloc uses after creating a booking.
      (_) {
        emit(const BikesAdded('Bike added successfully'));
        add(BikesLoadRequested());
      },
    );
  }

  Future<void> _onUpdateRequested(
    BikeUpdateRequested event,
    Emitter<BikesState> emit,
  ) async {
    emit(const BikesLoading());

    final result = await _updateBike(
      UpdateBikeParams(
        line: event.line,
        plateNo: event.plateNo,
        unitId: event.unitId,
        chasisNo: event.chasisNo,
        engineNo: event.engineNo,
        color: event.color,
        year: event.year,
        photo: event.photo,
      ),
    );

    // No list re-load here, unlike an add: the edit page owns its own
    // (separate) BikesBloc, so a reload would fill a list nobody is showing.
    // The page that opened it reloads its own from the pop result instead.
    result.fold(
      (f) => emit(BikesError(f.message)),
      (_) => emit(const BikesUpdated('Bike updated successfully')),
    );
  }

  Future<void> _onDeleteRequested(
    BikeDeleteRequested event,
    Emitter<BikesState> emit,
  ) async {
    emit(const BikesLoading());

    final result = await _deleteBike(DeleteBikeParams(line: event.line));

    // Unlike an edit, the list lives on the page that owns this bloc, so it is
    // reloaded either way: on success to drop the bike, and on a refusal so the
    // error doesn't leave the page showing an error screen in place of the
    // list the member just asked to change (the reason reaches them through
    // BikesError, which the page shows as a snackbar).
    result.fold(
      (f) => emit(BikesError(f.message)),
      (_) => emit(const BikesDeleted('Bike deleted successfully')),
    );
    add(const BikesLoadRequested());
  }
}
