// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingModel _$BookingModelFromJson(Map<String, dynamic> json) => BookingModel(
  id: json['id'] as String,
  serviceId: json['service_id'] as String,
  serviceName: json['service_name'] as String,
  scheduledAt: _dateFromJson(json['scheduled_at'] as String),
  status: json['status'] as String,
  price: (json['price'] as num).toDouble(),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$BookingModelToJson(BookingModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'service_id': instance.serviceId,
      'service_name': instance.serviceName,
      'scheduled_at': _dateToJson(instance.scheduledAt),
      'status': instance.status,
      'notes': instance.notes,
      'price': instance.price,
    };
