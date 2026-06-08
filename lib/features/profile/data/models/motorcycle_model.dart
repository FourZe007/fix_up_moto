import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/profile/domain/entities/motorcycle_entity.dart';

part 'motorcycle_model.g.dart';

@JsonSerializable()
class MotorcycleModel {
  final String id;
  final String brand;
  final String model;
  final int year;

  @JsonKey(name: 'plate_number')
  final String plateNumber;

  const MotorcycleModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.plateNumber,
  });

  factory MotorcycleModel.fromJson(Map<String, dynamic> json) =>
      _$MotorcycleModelFromJson(json);

  Map<String, dynamic> toJson() => _$MotorcycleModelToJson(this);

  MotorcycleEntity toEntity() => MotorcycleEntity(
        id: id,
        brand: brand,
        model: model,
        year: year,
        plateNumber: plateNumber,
      );
}
