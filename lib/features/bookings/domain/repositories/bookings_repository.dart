import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/result_message_model.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';

abstract class BookingsRepository {
  /// Returns the authenticated user's bookings, newest first, bounded to
  /// [beginDate]..[endDate] by the backend.
  Future<Either<Failure, List<BookingEntity>>> getBookings(
    DateTime beginDate,
    DateTime endDate,
  );

  /// Creates a new booking and returns the confirmed [BookingEntity].
  Future<Either<Failure, ResultMessageModel>> createBooking({
    // required String serviceId,
    required DateTime scheduledAt,
    required String branch,
    required String shop,
    required String plateNo,
    required String unitId,
    String? notes,
  });

  /// Cancels the booking with [id]. Returns void on success.
  Future<Either<Failure, void>> cancelBooking(String id);
}
