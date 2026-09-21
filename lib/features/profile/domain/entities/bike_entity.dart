import 'package:equatable/equatable.dart';

/// A bike registered to the user for service tracking.
///
/// Fields mirror the real `BrowseTrans` response directly — see `BikeModel`
/// for the raw JSON keys. There's no separate brand/model split in the real
/// data; `unitId` is one combined string (e.g. "YAMAHA R25"), the same shape
/// `BookingEntity.unitId` already uses for the same kind of field.
class BikeEntity extends Equatable {
  final String unitId;
  final String plateNo;
  final String chasisNo;
  final String engineNo;
  final String color;
  final int year;
  final String photo;

  const BikeEntity({
    required this.unitId,
    required this.plateNo,
    required this.chasisNo,
    required this.engineNo,
    required this.color,
    required this.year,
    this.photo = '',
  });

  @override
  List<Object> get props => [
    unitId,
    plateNo,
    chasisNo,
    engineNo,
    color,
    year,
    photo,
  ];
}
