import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';

sealed class BikesState extends Equatable {
  const BikesState();
  @override
  List<Object?> get props => [];
}

final class BikesInitial extends BikesState {
  const BikesInitial();
}

final class BikesLoading extends BikesState {
  const BikesLoading();
}

final class BikesLoaded extends BikesState {
  final List<BikeEntity> bikes;
  const BikesLoaded(this.bikes);

  @override
  List<Object> get props => [bikes];
}

final class BikeActionSuccess extends BikesState {
  final String message;
  const BikeActionSuccess(this.message);

  @override
  List<Object> get props => [message];
}

final class BikesError extends BikesState {
  final String message;
  const BikesError(this.message);

  @override
  List<Object> get props => [message];
}
