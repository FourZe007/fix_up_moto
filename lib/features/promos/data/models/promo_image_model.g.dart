// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promo_image_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PromoImageModel _$PromoImageModelFromJson(Map<String, dynamic> json) =>
    PromoImageModel(
      line: (json['Line'] as num).toInt(),
      base64Image: json['Base64Image'] as String,
    );

Map<String, dynamic> _$PromoImageModelToJson(PromoImageModel instance) =>
    <String, dynamic>{
      'Line': instance.line,
      'Base64Image': instance.base64Image,
    };
