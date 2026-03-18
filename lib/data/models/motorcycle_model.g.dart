// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motorcycle_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MotorcycleModel _$MotorcycleModelFromJson(Map<String, dynamic> json) =>
    MotorcycleModel(
      id: json['id'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: (json['year'] as num).toInt(),
      plateNumber: json['plate_number'] as String,
    );

Map<String, dynamic> _$MotorcycleModelToJson(MotorcycleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'brand': instance.brand,
      'model': instance.model,
      'year': instance.year,
      'plate_number': instance.plateNumber,
    };
