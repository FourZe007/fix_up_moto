import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';

part 'bike_model.g.dart';

/// JSON model for a single record from `BrowseTrans`'s bike-list projection.
///
/// `Year` arrives as a string (e.g. "2023"), not a number — kept as `String`
/// here to match the wire format exactly, parsed to `int` only in [toEntity].
/// `Line` (a row/sequence number in the raw response) isn't mapped — nothing
/// in the app needs it.
@JsonSerializable()
class BikeModel {
  @JsonKey(name: 'UnitID')
  final String unitId;

  @JsonKey(name: 'PlateNo')
  final String plateNo;

  @JsonKey(name: 'ChasisNo')
  final String chasisNo;

  @JsonKey(name: 'EngineNo')
  final String engineNo;

  @JsonKey(name: 'Color')
  final String color;

  @JsonKey(name: 'Year')
  final String year;

  @JsonKey(name: 'Photo')
  final String photo;

  const BikeModel({
    required this.unitId,
    required this.plateNo,
    required this.chasisNo,
    required this.engineNo,
    required this.color,
    required this.year,
    required this.photo,
  });

  factory BikeModel.fromJson(Map<String, dynamic> json) =>
      _$BikeModelFromJson(json);

  Map<String, dynamic> toJson() => _$BikeModelToJson(this);

  BikeEntity toEntity() => BikeEntity(
    unitId: unitId,
    plateNo: plateNo,
    chasisNo: chasisNo,
    engineNo: engineNo,
    color: color,
    year: int.tryParse(year) ?? 0,
    photo: photo,
  );
}
