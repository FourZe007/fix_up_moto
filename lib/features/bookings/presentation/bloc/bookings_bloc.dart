import 'dart:developer';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/cancel_booking_usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/create_booking_usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/get_bookings_usecase.dart';
import 'bookings_event.dart';
import 'bookings_state.dart';

class BookingsBloc extends Bloc<BookingsEvent, BookingsState> {
  final GetBookingsUseCase _getBookings;
  final CreateBookingUseCase _createBooking;
  final CancelBookingUseCase _cancelBooking;

  /// The range of the most recent list request. Null until the first one.
  /// Used to reload the same window after a create or cancel, and to drop a
  /// list response that arrives after a newer request has replaced it.
  DateTimeRange? _lastRange;

  BookingsBloc({
    required GetBookingsUseCase getBookings,
    required CreateBookingUseCase createBooking,
    required CancelBookingUseCase cancelBooking,
  }) : _getBookings = getBookings,
       _createBooking = createBooking,
       _cancelBooking = cancelBooking,
       super(const BookingsInitial()) {
    on<BookingsListRequested>(_onListRequested);
    on<BookingCreateRequested>(_onCreateRequested);
    on<BookingCancelRequested>(_onCancelRequested);
  }

  Future<void> _onListRequested(
    BookingsListRequested event,
    Emitter<BookingsState> emit,
  ) async {
    final range = event.range;
    _lastRange = range;
    emit(const BookingsLoading());
    final result = await _getBookings(
      GetBookingsParams(range.start, range.end),
    );

    // Handlers run concurrently, so two requests can be in flight at once
    // (e.g. the filter changed twice quickly). If a newer range has been
    // requested since, this response is for a window the user has left —
    // applying it would overwrite the list with the wrong dates.
    if (range != _lastRange) return;

    result.fold(
      (f) => emit(BookingsError(f.message)),
      (list) => emit(BookingsLoaded(list)),
    );
  }

  Future<void> _onCreateRequested(
    BookingCreateRequested event,
    Emitter<BookingsState> emit,
  ) async {
    log('onCreateRequested: ${event.toString()}');
    emit(const BookingsLoading());
    final result = await _createBooking(
      CreateBookingParams(
        // serviceId: event.serviceId,
        scheduledAt: event.scheduledAt,
        branch: event.branch,
        shop: event.shop,
        plateNo: event.plateNo,
        unitId: event.unitId,
        notes: event.notes,
      ),
    );

    result.fold(
      (f) => emit(BookingsError(f.message)),
      // Emit success then re-load the list so it reflects the new booking
      (_) {
        emit(const BookingActionSuccess('Booking confirmed!'));
        _reloadLastRange();
      },
    );
  }

  Future<void> _onCancelRequested(
    BookingCancelRequested event,
    Emitter<BookingsState> emit,
  ) async {
    emit(const BookingsLoading());
    final result = await _cancelBooking(CancelBookingParams(event.bookingId));
    result.fold((f) => emit(BookingsError(f.message)), (_) {
      emit(const BookingActionSuccess('Booking cancelled'));
      _reloadLastRange();
    });
  }

  /// Re-fetches the window the user is looking at. Does nothing when no list
  /// was ever requested on this bloc — e.g. Create Booking's own instance,
  /// which never shows a list, so there is nothing to refresh (and no range
  /// to refresh it with).
  void _reloadLastRange() {
    final range = _lastRange;
    if (range != null) add(BookingsListRequested(range: range));
  }
}
