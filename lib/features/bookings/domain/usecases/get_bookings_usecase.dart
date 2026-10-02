import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';
import 'package:fix_up_moto/features/bookings/domain/repositories/bookings_repository.dart';

class GetBookingsUseCase
    extends UseCase<List<BookingEntity>, GetBookingsParams> {
  final BookingsRepository repository;
  GetBookingsUseCase(this.repository);

  @override
  Future<Either<Failure, List<BookingEntity>>> call(GetBookingsParams params) {
    return repository.getBookings(params.beginDate, params.endDate);
  }
}

/// Plain [DateTime]s rather than Flutter's `DateTimeRange` — the domain layer
/// stays free of Flutter types.
class GetBookingsParams extends Equatable {
  final DateTime beginDate;
  final DateTime endDate;
  const GetBookingsParams(this.beginDate, this.endDate);

  @override
  List<Object?> get props => [beginDate, endDate];
}
