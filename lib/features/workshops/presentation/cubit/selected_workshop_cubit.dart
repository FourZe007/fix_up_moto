import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';

/// The workshop the member intends to visit — shared across Home and the
/// booking flow.
///
/// App-scoped like [AuthBloc], not page-scoped: picking a workshop on one
/// screen must be visible on every other screen that reads it (Home's picker
/// and Create Booking's picker are two views onto the same choice, not two
/// independent ones), so a page-scoped factory would defeat the point.
/// Register with `registerLazySingleton` and provide via `BlocProvider.value`
/// at the app root, the same pairing [AuthBloc] uses and for the same reason.
class SelectedWorkshopCubit extends Cubit<WorkshopEntity?> {
  SelectedWorkshopCubit() : super(null);

  void select(WorkshopEntity workshop) => emit(workshop);
}
