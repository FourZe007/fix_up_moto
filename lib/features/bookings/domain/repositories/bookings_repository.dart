import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';

abstract class BookingsRepository {
  /// Returns all bookings for the authenticated user, newest first.
  Future<Either<Failure, List<BookingEntity>>> getBookings();

  /// Creates a new booking and returns the confirmed [BookingEntity].
  Future<Either<Failure, BookingEntity>> createBooking({
    required String serviceId,
    required DateTime scheduledAt,
    String? notes,
  });

  /// Cancels the booking with [id]. Returns void on success.
  Future<Either<Failure, void>> cancelBooking(String id);
}
