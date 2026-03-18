import 'package:equatable/equatable.dart';

sealed class BookingsEvent extends Equatable {
  const BookingsEvent();
  @override
  List<Object?> get props => [];
}

/// Load (or refresh) the booking list.
final class BookingsListRequested extends BookingsEvent {
  const BookingsListRequested();
}

/// Create a new booking.
final class BookingCreateRequested extends BookingsEvent {
  final String serviceId;
  final DateTime scheduledAt;
  final String? notes;

  const BookingCreateRequested({
    required this.serviceId,
    required this.scheduledAt,
    this.notes,
  });

  @override
  List<Object?> get props => [serviceId, scheduledAt, notes];
}

/// Cancel an existing booking.
final class BookingCancelRequested extends BookingsEvent {
  final String bookingId;
  const BookingCancelRequested(this.bookingId);

  @override
  List<Object> get props => [bookingId];
}
