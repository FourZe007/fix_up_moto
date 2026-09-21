import 'package:equatable/equatable.dart';

sealed class BikesEvent extends Equatable {
  const BikesEvent();
  @override
  List<Object?> get props => [];
}

final class BikesLoadRequested extends BikesEvent {
  final String memberId;

  const BikesLoadRequested({required this.memberId});
}

final class BikeAddRequested extends BikesEvent {
  final String memberId;
  final String brand;
  final String model;
  final int year;
  final String plateNumber;

  const BikeAddRequested({
    required this.memberId,
    required this.brand,
    required this.model,
    required this.year,
    required this.plateNumber,
  });

  @override
  List<Object> get props => [memberId, brand, model, year, plateNumber];
}
