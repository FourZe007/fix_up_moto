import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/booking_entity.dart';
import 'package:fix_up_moto/domain/repositories/bookings_repository.dart';

class CreateBookingUseCase extends UseCase<BookingEntity, CreateBookingParams> {
  final BookingsRepository repository;
  CreateBookingUseCase(this.repository);

  @override
  Future<Either<Failure, BookingEntity>> call(CreateBookingParams params) {
    return repository.createBooking(
      serviceId: params.serviceId,
      scheduledAt: params.scheduledAt,
      notes: params.notes,
    );
  }
}

class CreateBookingParams extends Equatable {
  final String serviceId;
  final DateTime scheduledAt;
  final String? notes;

  const CreateBookingParams({
    required this.serviceId,
    required this.scheduledAt,
    this.notes,
  });

  @override
  List<Object?> get props => [serviceId, scheduledAt, notes];
}
