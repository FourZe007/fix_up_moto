import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';
import 'package:fix_up_moto/features/bookings/domain/repositories/bookings_repository.dart';
import 'package:fix_up_moto/features/bookings/data/datasources/bookings_remote_data_source.dart';

class BookingsRepositoryImpl implements BookingsRepository {
  final BookingsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  /// Same reasoning as HomeRepositoryImpl: BrowseTrans has no "who am I"
  /// projection of its own, every call must supply MemberID itself, and the
  /// cached session (read through Auth's own repository, not a use case —
  /// see HomeRepositoryImpl's doc comment for why) is the only place it
  /// exists on the client.
  final AuthRepository authRepository;

  const BookingsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.authRepository,
  });

  @override
  Future<Either<Failure, List<BookingEntity>>> getBookings() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    final currentUserResult = await authRepository.getCurrentUser();

    return currentUserResult.fold((failure) async => Left(failure), (
      user,
    ) async {
      if (user == null) {
        return const Left(AuthFailure('No signed-in member found'));
      }

      try {
        final models = await remoteDataSource.getBookings(user.id);
        return Right(models.map((m) => m.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(
          AuthFailure('Session expired. Please sign in again.'),
        );
      } on ForbiddenException catch (e) {
        return Left(PermissionFailure(e.message));
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message, statusCode: e.statusCode));
      }
    });
  }

  @override
  Future<Either<Failure, BookingEntity>> createBooking({
    required String serviceId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      final model = await remoteDataSource.createBooking(
        serviceId: serviceId,
        scheduledAt: scheduledAt,
        notes: notes,
      );
      return Right(model.toEntity());
    } on UnauthorizedException {
      return const Left(AuthFailure('Session expired. Please sign in again.'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> cancelBooking(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }
    try {
      await remoteDataSource.cancelBooking(id);
      return const Right(null);
    } on UnauthorizedException {
      return const Left(AuthFailure('Session expired. Please sign in again.'));
    } on ForbiddenException catch (e) {
      return Left(PermissionFailure(e.message));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
