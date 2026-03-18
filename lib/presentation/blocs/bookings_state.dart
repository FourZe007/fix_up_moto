import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/domain/entities/booking_entity.dart';

sealed class BookingsState extends Equatable {
  const BookingsState();
  @override
  List<Object?> get props => [];
}

final class BookingsInitial extends BookingsState { const BookingsInitial(); }
final class BookingsLoading extends BookingsState { const BookingsLoading(); }

/// Booking list loaded successfully.
final class BookingsLoaded extends BookingsState {
  final List<BookingEntity> bookings;
  const BookingsLoaded(this.bookings);

  @override
  List<Object> get props => [bookings];
}

/// A create or cancel action completed — reload the list after this.
final class BookingActionSuccess extends BookingsState {
  final String message;
  const BookingActionSuccess(this.message);

  @override
  List<Object> get props => [message];
}

final class BookingsError extends BookingsState {
  final String message;
  const BookingsError(this.message);

  @override
  List<Object> get props => [message];
}
