// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workshop_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkshopModel _$WorkshopModelFromJson(Map<String, dynamic> json) =>
    WorkshopModel(
      branch: json['Branch'] as String,
      shop: json['Shop'] as String,
      bsName: json['BSName'] as String,
      bsAddress: json['BSAddress'] as String,
      operationalHours: json['OperasionalHours'] as String,
      phoneNo: json['PhoneNo'] as String,
      active: json['Active'] as bool,
      lat: (json['Lat'] as num).toDouble(),
      lng: (json['Lng'] as num).toDouble(),
    );

Map<String, dynamic> _$WorkshopModelToJson(WorkshopModel instance) =>
    <String, dynamic>{
      'Branch': instance.branch,
      'Shop': instance.shop,
      'BSName': instance.bsName,
      'BSAddress': instance.bsAddress,
      'OperasionalHours': instance.operationalHours,
      'PhoneNo': instance.phoneNo,
      'Active': instance.active,
      'Lat': instance.lat,
      'Lng': instance.lng,
    };
