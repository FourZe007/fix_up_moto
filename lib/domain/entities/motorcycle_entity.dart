import 'package:equatable/equatable.dart';

/// A motorcycle registered to the user for service tracking.
class MotorcycleEntity extends Equatable {
  final String id;
  final String brand;    // e.g. "Honda"
  final String model;    // e.g. "CB500F"
  final int year;        // e.g. 2022
  final String plateNumber;

  const MotorcycleEntity({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.plateNumber,
  });

  @override
  List<Object> get props => [id, brand, model, year, plateNumber];
}
