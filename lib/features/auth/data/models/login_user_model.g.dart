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
      flag: _intFromJson(json['Flag']),
      email: json['EmailAddress'] as String?,
      isGoogleLogin: json['isGoogle'] as String? ?? '0',
      loginId: json['PhoneNo'] as String?,
    );

Map<String, dynamic> _$LoginUserModelToJson(LoginUserModel instance) =>
    <String, dynamic>{
      'MemberID': instance.id,
      'MemberName': instance.name,
      'EmailAddress': instance.email,
      'Flag': instance.flag,
      'Memo': instance.status,
      'isGoogle': instance.isGoogleLogin,
      'PhoneNo': instance.loginId,
    };
