import 'package:equatable/equatable.dart';

/// Represents a single service booking made by the user.
///
/// Fields mirror `BrowseTrans` (`Jenis: "SERVICEBOOKINGHISTORYBYMEMBER"`)
/// directly — see `BookingModel` for the raw JSON keys.
class BookingEntity extends Equatable {
  /// `BookingID` — the natural unique identifier for this record.
  final String id;

  /// Workshop/branch name where the booking was made.
  final String bsName;
  final String bsAddress;

  /// `BookDate` + `BookTime` combined into one local [DateTime].
  final DateTime scheduledAt;

  /// The motorcycle booked in for service.
  final String plateNo;
  final String unitId;

  /// Server-provided status string (e.g. "MENUNGGU KONFIRMASI") — shown
  /// verbatim rather than mapped to a fixed enum, since the full set of
  /// possible values hasn't been confirmed against the backend yet.
  final String status;

  final String? notes;

  const BookingEntity({
    required this.id,
    required this.bsName,
    required this.bsAddress,
    required this.scheduledAt,
    required this.plateNo,
    required this.unitId,
    required this.status,
    this.notes,
  });

  /// Convenience getter — true for bookings that haven't happened yet.
  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());

  @override
  List<Object?> get props => [
    id,
    bsName,
    bsAddress,
    scheduledAt,
    plateNo,
    unitId,
    status,
    notes,
  ];
}
