import 'package:equatable/equatable.dart';

/// A bike registered to the user for service tracking.
///
/// Fields mirror the real `BrowseTrans` response directly — see `BikeModel`
/// for the raw JSON keys. There's no separate brand/model split in the real
/// data; `unitId` is one combined string (e.g. "YAMAHA R25"), the same shape
/// `BookingEntity.unitId` already uses for the same kind of field.
class BikeEntity extends Equatable {
  /// The record's own row number — what an edit or a delete sends to say which
  /// bike it means, since the plate can be edited and is not a key. Only ever
  /// read from the bike list; adding a bike never sends one.
  final String line;
  final String unitId;
  final String plateNo;
  final String chasisNo;
  final String engineNo;
  final String color;
  final String year;
  final String photo;

  const BikeEntity({
    this.line = '',
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
    line,
    unitId,
    plateNo,
    chasisNo,
    engineNo,
    color,
    year,
    photo,
  ];
}
