import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_formatter.dart';
import 'package:fix_up_moto/presentation/blocs/bookings_bloc.dart';
import 'package:fix_up_moto/presentation/blocs/bookings_event.dart';
import 'package:fix_up_moto/presentation/blocs/bookings_state.dart';

/// Lists all bookings for the authenticated user.
class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BookingsBloc>()..add(const BookingsListRequested()),
      child: const _BookingsView(),
    );
  }
}

class _BookingsView extends StatelessWidget {
  const _BookingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: BlocConsumer<BookingsBloc, BookingsState>(
        listener: (context, state) {
          if (state is BookingActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            BookingsInitial() || BookingsLoading() =>
              const Center(child: CircularProgressIndicator()),
            BookingsError(:final message) => Center(child: Text(message)),
            BookingActionSuccess() =>
              const Center(child: CircularProgressIndicator()),
            BookingsLoaded(:final bookings) => bookings.isEmpty
                ? const Center(child: Text('No bookings yet'))
                : RefreshIndicator(
                    onRefresh: () async => context
                        .read<BookingsBloc>()
                        .add(const BookingsListRequested()),
                    child: ListView.builder(
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return Card(
                          child: ListTile(
                            title: Text(booking.serviceName),
                            subtitle: Text(
                              // Uses DateFormatter to display "Mon, 10 Mar 2026 at 10:30 AM"
                              DateFormatter.toFullDateTime(booking.scheduledAt),
                            ),
                            trailing: _StatusBadge(status: booking.status),
                            // Show cancel option only for upcoming bookings
                            onLongPress: booking.isUpcoming
                                ? () => _confirmCancel(context, booking.id)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
          };
        },
      ),
    );
  }

  void _confirmCancel(BuildContext context, String bookingId) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<BookingsBloc>()
                  .add(BookingCancelRequested(bookingId));
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Coloured badge showing the booking status string.
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // Map status string to a colour — extend as needed for new statuses
    final color = switch (status) {
      'confirmed'   => Colors.green,
      'pending'     => Colors.orange,
      'cancelled'   => Colors.red,
      'completed'   => Colors.blue,
      'in_progress' => Colors.teal,
      _             => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
