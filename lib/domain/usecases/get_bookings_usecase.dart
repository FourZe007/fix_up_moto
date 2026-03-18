import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/booking_entity.dart';
import 'package:fix_up_moto/domain/repositories/bookings_repository.dart';

class GetBookingsUseCase extends NoParamsUseCase<List<BookingEntity>> {
  final BookingsRepository repository;
  GetBookingsUseCase(this.repository);

  @override
  Future<Either<Failure, List<BookingEntity>>> call() {
    return repository.getBookings();
  }
}
