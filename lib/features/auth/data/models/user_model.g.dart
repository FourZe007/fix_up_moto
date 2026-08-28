// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['MemberID'] as String,
  name: json['MemberName'] as String,
  status: json['Memo'] as String,
  isActive: _boolFromJson(json['Flag']),
  email: json['EmailAddress'] as String?,
  phone: json['PhoneNo'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  createdAt: _dateFromJson(json['created_at'] as String?),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'MemberID': instance.id,
  'MemberName': instance.name,
  'EmailAddress': instance.email,
  'PhoneNo': instance.phone,
  'Flag': instance.isActive,
  'Memo': instance.status,
  'avatar_url': instance.avatarUrl,
  'created_at': _dateToJson(instance.createdAt),
};
