import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/domain/usecases/cancel_booking_usecase.dart';
import 'package:fix_up_moto/domain/usecases/create_booking_usecase.dart';
import 'package:fix_up_moto/domain/usecases/get_bookings_usecase.dart';
import 'bookings_event.dart';
import 'bookings_state.dart';

class BookingsBloc extends Bloc<BookingsEvent, BookingsState> {
  final GetBookingsUseCase _getBookings;
  final CreateBookingUseCase _createBooking;
  final CancelBookingUseCase _cancelBooking;

  BookingsBloc({
    required GetBookingsUseCase getBookings,
    required CreateBookingUseCase createBooking,
    required CancelBookingUseCase cancelBooking,
  })  : _getBookings = getBookings,
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
    emit(const BookingsLoading());
    final result = await _getBookings();
    result.fold(
      (f) => emit(BookingsError(f.message)),
      (list) => emit(BookingsLoaded(list)),
    );
  }

  Future<void> _onCreateRequested(
    BookingCreateRequested event,
    Emitter<BookingsState> emit,
  ) async {
    emit(const BookingsLoading());
    final result = await _createBooking(
      CreateBookingParams(
        serviceId: event.serviceId,
        scheduledAt: event.scheduledAt,
        notes: event.notes,
      ),
    );
    result.fold(
      (f) => emit(BookingsError(f.message)),
      // Emit success then re-load the list so it reflects the new booking
      (_) {
        emit(const BookingActionSuccess('Booking confirmed!'));
        add(const BookingsListRequested());
      },
    );
  }

  Future<void> _onCancelRequested(
    BookingCancelRequested event,
    Emitter<BookingsState> emit,
  ) async {
    emit(const BookingsLoading());
    final result = await _cancelBooking(CancelBookingParams(event.bookingId));
    result.fold(
      (f) => emit(BookingsError(f.message)),
      (_) {
        emit(const BookingActionSuccess('Booking cancelled'));
        add(const BookingsListRequested());
      },
    );
  }
}
