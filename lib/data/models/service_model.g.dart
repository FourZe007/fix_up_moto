// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceModel _$ServiceModelFromJson(Map<String, dynamic> json) => ServiceModel(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  categoryId: json['category_id'] as String,
  price: (json['price'] as num).toDouble(),
  durationMinutes: (json['duration_minutes'] as num).toInt(),
  imageUrl: json['image_url'] as String?,
  isAvailable: json['is_available'] as bool? ?? true,
);

Map<String, dynamic> _$ServiceModelToJson(ServiceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category_id': instance.categoryId,
      'price': instance.price,
      'duration_minutes': instance.durationMinutes,
      'image_url': instance.imageUrl,
      'is_available': instance.isAvailable,
    };
