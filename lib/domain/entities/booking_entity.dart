import 'package:equatable/equatable.dart';

/// Represents a single service booking made by the user.
class BookingEntity extends Equatable {
  final String id;

  /// The service this booking is for.
  final String serviceId;
  final String serviceName;

  /// Scheduled date and time (stored as UTC, displayed in local time).
  final DateTime scheduledAt;

  /// Current status — one of: pending, confirmed, in_progress, completed, cancelled.
  final String status;

  /// Optional notes from the user (max 500 chars per [AppConstants.maxBookingNotesLength]).
  final String? notes;

  /// Total price charged at the time of booking.
  final double price;

  const BookingEntity({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.scheduledAt,
    required this.status,
    required this.price,
    this.notes,
  });

  /// Convenience getter — true for bookings that haven't happened yet.
  bool get isUpcoming =>
      scheduledAt.isAfter(DateTime.now()) && status != 'cancelled';

  @override
  List<Object?> get props => [
        id, serviceId, serviceName, scheduledAt, status, price, notes,
      ];
}
