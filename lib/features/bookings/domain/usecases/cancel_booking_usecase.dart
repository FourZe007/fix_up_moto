import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/repositories/bookings_repository.dart';

class CancelBookingUseCase extends UseCase<void, CancelBookingParams> {
  final BookingsRepository repository;
  CancelBookingUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(CancelBookingParams params) {
    return repository.cancelBooking(params.bookingId);
  }
}

class CancelBookingParams extends Equatable {
  final String bookingId;
  const CancelBookingParams(this.bookingId);

  @override
  List<Object> get props => [bookingId];
}
