import 'package:equatable/equatable.dart';

sealed class BikesEvent extends Equatable {
  const BikesEvent();
  @override
  List<Object?> get props => [];
}

final class BikesLoadRequested extends BikesEvent {
  // final String memberId;

  const BikesLoadRequested(/*{required this.memberId}*/);
}

final class BikeAddRequested extends BikesEvent {
  final String plateNumber;
  final String unitId; // brand name with its variant
  final String chasisNo;
  final String engineNo;
  final String color;
  final String year;
  final String photo;

  const BikeAddRequested({
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
    plateNumber,
    unitId,
    chasisNo,
    engineNo,
    color,
    year,
    photo,
  ];
}

final class BikeUpdateRequested extends BikesEvent {
  /// The record's row number, exactly as the list returned it — says which bike
  /// this is. Never edited.
  final String line;

  /// An ordinary field, editable like the rest.
  final String plateNo;
  final String unitId; // brand name with its variant
  final String chasisNo;
  final String engineNo;
  final String color;
  final String year;
  final String photo;

  const BikeUpdateRequested({
    required this.line,
    required this.plateNo,
    required this.unitId,
    required this.chasisNo,
    required this.engineNo,
    required this.color,
    required this.year,
    required this.photo,
  });

  @override
  List<Object> get props => [
    line,
    plateNo,
    unitId,
    chasisNo,
    engineNo,
    color,
    year,
    photo,
  ];
}

final class BikeDeleteRequested extends BikesEvent {
  /// The record's row number, exactly as the list returned it.
  final String line;

  const BikeDeleteRequested({required this.line});

  @override
  List<Object> get props => [line];
}
