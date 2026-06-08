import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';

part 'booking_model.g.dart';

@JsonSerializable()
class BookingModel {
  final String id;

  @JsonKey(name: 'service_id')
  final String serviceId;

  @JsonKey(name: 'service_name')
  final String serviceName;

  @JsonKey(name: 'scheduled_at', fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime scheduledAt;

  final String status;
  final String? notes;
  final double price;

  const BookingModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.scheduledAt,
    required this.status,
    required this.price,
    this.notes,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      _$BookingModelFromJson(json);

  Map<String, dynamic> toJson() => _$BookingModelToJson(this);

  BookingEntity toEntity() => BookingEntity(
        id: id,
        serviceId: serviceId,
        serviceName: serviceName,
        scheduledAt: scheduledAt,
        status: status,
        price: price,
        notes: notes,
      );
}

DateTime _dateFromJson(String value) =>
    DateTime.parse(value).toLocal();

String _dateToJson(DateTime value) => value.toUtc().toIso8601String();
