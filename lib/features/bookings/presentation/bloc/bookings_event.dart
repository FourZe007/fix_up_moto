import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

sealed class BookingsEvent extends Equatable {
  const BookingsEvent();
  @override
  List<Object?> get props => [];
}

/// Load (or refresh) the booking list for [range] — sent to the backend as
/// `BeginDate`/`EndDate`. Required and non-null: the whole chain below needs
/// both dates, so the compiler rules out "no range" here rather than the
/// BLoC having to guess a fallback window at runtime.
final class BookingsListRequested extends BookingsEvent {
  final DateTimeRange range;
  const BookingsListRequested({required this.range});

  @override
  List<Object?> get props => [range];
}

/// Create a new booking.
final class BookingCreateRequested extends BookingsEvent {
  // final String serviceId;
  final DateTime scheduledAt;
  final String branch;
  final String shop;
  final String plateNo;
  final String unitId;
  final String? notes;

  const BookingCreateRequested({
    // required this.serviceId,
    required this.scheduledAt,
    required this.branch,
    required this.shop,
    required this.plateNo,
    required this.unitId,
    this.notes,
  });

  @override
  List<Object?> get props => [
    // serviceId,
    scheduledAt,
    branch,
    shop,
    plateNo,
    unitId,
    notes,
  ];
}

/// Cancel an existing booking.
final class BookingCancelRequested extends BookingsEvent {
  final String bookingId;
  const BookingCancelRequested(this.bookingId);

  @override
  List<Object> get props => [bookingId];
}
