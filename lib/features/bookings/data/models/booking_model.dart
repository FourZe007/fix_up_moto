import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';

part 'booking_model.g.dart';

/// JSON model for a single record from `BrowseTrans`
/// (`Jenis: "SERVICEBOOKINGHISTORYBYMEMBER"`).
///
/// `BookDate` ("2026-08-31") and `BookTime` ("10:00") arrive as separate
/// strings — kept separate here to match the wire format exactly, and
/// combined into one [DateTime] only in [toEntity].
@JsonSerializable()
class BookingModel {
  @JsonKey(name: 'BookingID')
  final String bookingId;

  @JsonKey(name: 'BSName')
  final String bsName;

  @JsonKey(name: 'BSAddress')
  final String bsAddress;

  @JsonKey(name: 'BookDate')
  final String bookDate;

  @JsonKey(name: 'BookTime')
  final String bookTime;

  @JsonKey(name: 'UPlateNo')
  final String plateNo;

  @JsonKey(name: 'UnitID')
  final String unitId;

  @JsonKey(name: 'Status')
  final String status;

  @JsonKey(name: 'Notes')
  final String? notes;

  const BookingModel({
    required this.bookingId,
    required this.bsName,
    required this.bsAddress,
    required this.bookDate,
    required this.bookTime,
    required this.plateNo,
    required this.unitId,
    required this.status,
    this.notes,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      _$BookingModelFromJson(json);

  Map<String, dynamic> toJson() => _$BookingModelToJson(this);

  BookingEntity toEntity() {
    final trimmedNotes = notes?.trim();
    return BookingEntity(
      id: bookingId,
      bsName: bsName,
      bsAddress: bsAddress,
      scheduledAt: _combineDateAndTime(bookDate, bookTime),
      plateNo: plateNo,
      unitId: unitId,
      status: status,
      notes: (trimmedNotes == null || trimmedNotes.isEmpty)
          ? null
          : trimmedNotes,
    );
  }
}

/// Combines a `"yyyy-MM-dd"` date and an `"HH:mm"` time into one local
/// [DateTime]. Falls back to midnight if [time] doesn't parse.
DateTime _combineDateAndTime(String date, String time) {
  final day = DateTime.parse(date);
  final parts = time.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(day.year, day.month, day.day, hour, minute);
}
