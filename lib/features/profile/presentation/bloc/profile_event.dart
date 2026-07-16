import 'package:equatable/equatable.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

final class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

final class ProfileUpdateRequested extends ProfileEvent {
  final String name;
  final String? phone;
  const ProfileUpdateRequested({required this.name, this.phone});

  @override
  List<Object?> get props => [name, phone];
}

final class MotorcyclesLoadRequested extends ProfileEvent {
  const MotorcyclesLoadRequested();
}

final class MotorcycleAddRequested extends ProfileEvent {
  final String brand;
  final String model;
  final int year;
  final String plateNumber;

  const MotorcycleAddRequested({
    required this.brand,
    required this.model,
    required this.year,
    required this.plateNumber,
  });

  @override
  List<Object> get props => [brand, model, year, plateNumber];
}
