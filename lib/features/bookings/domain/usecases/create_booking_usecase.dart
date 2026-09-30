import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';
import 'package:fix_up_moto/features/bookings/domain/repositories/bookings_repository.dart';

class CreateBookingUseCase extends UseCase<BookingEntity, CreateBookingParams> {
  final BookingsRepository repository;
  CreateBookingUseCase(this.repository);

  @override
  Future<Either<Failure, BookingEntity>> call(CreateBookingParams params) {
    return repository.createBooking(
      serviceId: params.serviceId,
      scheduledAt: params.scheduledAt,
      branch: params.branch,
      shop: params.shop,
      plateNo: params.plateNo,
      unitId: params.unitId,
      notes: params.notes,
    );
  }
}

class CreateBookingParams extends Equatable {
  final String serviceId;
  final DateTime scheduledAt;
  final String branch;
  final String shop;
  final String plateNo;
  final String unitId;
  final String? notes;

  const CreateBookingParams({
    required this.serviceId,
    required this.scheduledAt,
    required this.branch,
    required this.shop,
    required this.plateNo,
    required this.unitId,
    this.notes,
  });

  @override
  List<Object?> get props => [
    serviceId,
    scheduledAt,
    branch,
    shop,
    plateNo,
    unitId,
    notes,
  ];
}
