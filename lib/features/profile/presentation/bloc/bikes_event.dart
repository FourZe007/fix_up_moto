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
  final String plateNumber;
  final String unitId; // brand name with its variant
  final String chasisNo;
  final String engineNo;
  final String color;
  final int year;
  final String photo;

  const BikeAddRequested({
    required this.memberId,
    required this.plateNumber,
    required this.unitId, // brand name with its variant
    required this.chasisNo,
    required this.engineNo,
    required this.color,
    required this.year,
    required this.photo,
  });

  @override
  List<Object> get props => [
    memberId,
    plateNumber,
    unitId,
    chasisNo,
    engineNo,
    color,
    year,
    photo,
  ];
}
