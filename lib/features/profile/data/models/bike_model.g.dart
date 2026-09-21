// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bike_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BikeModel _$BikeModelFromJson(Map<String, dynamic> json) => BikeModel(
  unitId: json['UnitID'] as String,
  plateNo: json['PlateNo'] as String,
  chasisNo: json['ChasisNo'] as String,
  engineNo: json['EngineNo'] as String,
  color: json['Color'] as String,
  year: json['Year'] as String,
  photo: json['Photo'] as String,
);

Map<String, dynamic> _$BikeModelToJson(BikeModel instance) => <String, dynamic>{
  'UnitID': instance.unitId,
  'PlateNo': instance.plateNo,
  'ChasisNo': instance.chasisNo,
  'EngineNo': instance.engineNo,
  'Color': instance.color,
  'Year': instance.year,
  'Photo': instance.photo,
};
