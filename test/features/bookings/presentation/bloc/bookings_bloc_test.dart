import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/result_message_model.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/cancel_booking_usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/create_booking_usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/get_bookings_usecase.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';

class MockGetBookings extends Mock implements GetBookingsUseCase {}

class MockCreateBooking extends Mock implements CreateBookingUseCase {}

class MockCancelBooking extends Mock implements CancelBookingUseCase {}

void main() {
  late MockGetBookings getBookings;
  late MockCreateBooking createBooking;
  late MockCancelBooking cancelBooking;

  final tRange = DateTimeRange(
    start: DateTime(2026, 10, 3),
    end: DateTime(2026, 11, 3),
  );
  final tParams = GetBookingsParams(tRange.start, tRange.end);

  setUpAll(() {
    registerFallbackValue(GetBookingsParams(DateTime(2026), DateTime(2026)));
    registerFallbackValue(const CancelBookingParams('x'));
    registerFallbackValue(
      CreateBookingParams(
        scheduledAt: DateTime(2026),
        branch: 'b',
        shop: 's',
        plateNo: 'p',
        unitId: 'u',
      ),
    );
  });

  setUp(() {
    getBookings = MockGetBookings();
    createBooking = MockCreateBooking();
    cancelBooking = MockCancelBooking();
    when(
      () => getBookings(any()),
    ).thenAnswer((_) async => const Right(<BookingEntity>[]));
    when(() => cancelBooking(any())).thenAnswer((_) async => const Right(null));
    when(() => createBooking(any())).thenAnswer(
      (_) async => const Right(ResultMessageModel(resultMessage: 'ok')),
    );
  });

  BookingsBloc buildBloc() => BookingsBloc(
    getBookings: getBookings,
    createBooking: createBooking,
    cancelBooking: cancelBooking,
  );

  final tCreate = BookingCreateRequested(
    scheduledAt: DateTime(2026, 10, 4, 9),
    branch: 'b',
    shop: 's',
    plateNo: 'p',
    unitId: 'u',
  );

  blocTest<BookingsBloc, BookingsState>(
    'passes the requested range to the use case as begin/end dates',
    build: buildBloc,
    act: (bloc) => bloc.add(BookingsListRequested(range: tRange)),
    expect: () => [const BookingsLoading(), const BookingsLoaded([])],
    verify: (_) => verify(() => getBookings(tParams)).called(1),
  );

  blocTest<BookingsBloc, BookingsState>(
    'reloads with the same range after a cancel instead of dropping it',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(BookingsListRequested(range: tRange));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const BookingCancelRequested('B-1'));
    },
    // Once for the initial load, once for the reload after the cancel.
    verify: (_) => verify(() => getBookings(tParams)).called(2),
  );

  blocTest<BookingsBloc, BookingsState>(
    'reloads with the same range after a create on a bloc that has loaded a list',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(BookingsListRequested(range: tRange));
      await Future<void>.delayed(Duration.zero);
      bloc.add(tCreate);
    },
    verify: (_) => verify(() => getBookings(tParams)).called(2),
  );

  // Create Booking's page owns a bloc that never loads a list, so there is
  // no range to reload with — this used to throw a null-check error.
  blocTest<BookingsBloc, BookingsState>(
    'creates without a prior list request: no reload, no error',
    build: buildBloc,
    act: (bloc) => bloc.add(tCreate),
    expect: () => [
      const BookingsLoading(),
      const BookingActionSuccess('Booking confirmed!'),
    ],
    verify: (_) => verifyNever(() => getBookings(any())),
  );

  final older = DateTimeRange(
    start: DateTime(2026, 9, 1),
    end: DateTime(2026, 9, 30),
  );
  final slowOlder = Completer<Either<Failure, List<BookingEntity>>>();

  blocTest<BookingsBloc, BookingsState>(
    'ignores a slow response for an older range once a newer one is requested',
    build: buildBloc,
    setUp: () => when(
      () => getBookings(GetBookingsParams(older.start, older.end)),
    ).thenAnswer((_) => slowOlder.future),
    act: (bloc) async {
      bloc.add(BookingsListRequested(range: older));
      await Future<void>.delayed(Duration.zero);
      bloc.add(BookingsListRequested(range: tRange));
      await Future<void>.delayed(Duration.zero);

      // The older response lands last, after the newer one has been applied.
      slowOlder.complete(const Left(ServerFailure('stale')));
    },
    wait: const Duration(milliseconds: 50),
    // No BookingsError('stale') at the end.
    expect: () => [const BookingsLoading(), const BookingsLoaded([])],
  );
}
