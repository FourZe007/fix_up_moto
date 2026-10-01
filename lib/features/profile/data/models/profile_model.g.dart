// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) => ProfileModel(
  id: json['MemberID'] as String,
  name: json['MemberName'] as String,
  status: json['Status'] as String,
  isActive: _boolFromJson(json['Active']),
  qty: (json['Qty'] as num).toInt(),
  point: (json['Point'] as num).toInt(),
  email: json['EmailAddress'] as String?,
  phone: json['PhoneNo'] as String?,
);

Map<String, dynamic> _$ProfileModelToJson(ProfileModel instance) =>
    <String, dynamic>{
      'MemberID': instance.id,
      'MemberName': instance.name,
      'EmailAddress': instance.email,
      'PhoneNo': instance.phone,
      'Status': instance.status,
      'Active': instance.isActive,
      'Qty': instance.qty,
      'Point': instance.point,
    };
