// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginUserModel _$LoginUserModelFromJson(Map<String, dynamic> json) =>
    LoginUserModel(
      id: json['MemberID'] as String,
      name: json['MemberName'] as String,
      status: json['Memo'] as String,
      isActive: _boolFromJson(json['Flag']),
      email: json['EmailAddress'] as String?,
      isGoogleLogin: json['isGoogle'] as String? ?? '0',
    );

Map<String, dynamic> _$LoginUserModelToJson(LoginUserModel instance) =>
    <String, dynamic>{
      'MemberID': instance.id,
      'MemberName': instance.name,
      'EmailAddress': instance.email,
      'Flag': instance.isActive,
      'Memo': instance.status,
      'isGoogle': instance.isGoogleLogin,
    };
