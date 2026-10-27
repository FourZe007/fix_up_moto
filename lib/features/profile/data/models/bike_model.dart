import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';

part 'bike_model.g.dart';

/// JSON model for a single record from `BrowseTrans`'s bike-list projection.
///
/// `Year` arrives as a string (e.g. "2023"), not a number — [BikeEntity]
/// keeps it as `String` too, so [toEntity] passes it through unchanged.
///
/// `Line` is the record's own row number, and what an edit or a delete sends to
/// say which bike it means — the plate is not a key. Whether it arrives as a
/// number or a string isn't known, so both are taken and kept as a string, and
/// a missing one becomes `''`.
@JsonSerializable()
class BikeModel {
  @JsonKey(name: 'Line', fromJson: _lineFromJson)
  final String line;

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
    required this.line,
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

  static String _lineFromJson(Object? value) => value?.toString() ?? '';

  BikeEntity toEntity() => BikeEntity(
    line: line,
    unitId: unitId,
    plateNo: plateNo,
    chasisNo: chasisNo,
    engineNo: engineNo,
    color: color,
    year: year,
    photo: photo,
  );
}
