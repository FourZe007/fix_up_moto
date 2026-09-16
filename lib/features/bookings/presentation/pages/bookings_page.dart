import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_formatter.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/pages/services_page.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';

/// The Bookings tab: past service history and current bookings, as two
/// segments of one tab rather than two separate tabs — both are about the
/// member's visits to FixUp Moto, one past and one upcoming.
///
/// [ServicesBloc] fetches immediately on mount, matching every other tab.
/// [BookingsBloc] deliberately does **not** — its backend endpoint
/// (`BrowseBooking`) is still unverified/not ready, so this tab stays on
/// [BookingsInitial] (rendered as the empty state below) rather than firing a
/// request at an endpoint that isn't there. Wire `BookingsListRequested()`
/// back in here once that endpoint is confirmed.
class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              sl<ServicesBloc>()..add(const ServicesListRequested()),
        ),
        BlocProvider(create: (_) => sl<BookingsBloc>()),
      ],
      child: const _BookingsView(),
    );
  }
}

class _BookingsView extends StatelessWidget {
  const _BookingsView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bookings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Bookings'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            BlocConsumer<BookingsBloc, BookingsState>(
              listener: (context, state) {
                if (state is BookingActionSuccess) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              builder: (context, state) {
                return switch (state) {
                  // Initial is never followed by a fetch right now (see
                  // BookingsPage's doc comment) — it's the default empty
                  // state, not a momentary loading flicker.
                  BookingsInitial() => const Center(
                    child: Text('No bookings yet'),
                  ),
                  BookingsLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  BookingsError(:final message) => Center(child: Text(message)),
                  BookingActionSuccess() => const Center(
                    child: CircularProgressIndicator(),
                  ),
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
                                    // "Mon, 10 Mar 2026 at 10:30 AM"
                                    DateFormatter.toFullDateTime(
                                      booking.scheduledAt,
                                    ),
                                  ),
                                  trailing: _StatusBadge(status: booking.status),
                                  // Show cancel option only for upcoming bookings
                                  onLongPress: booking.isUpcoming
                                      ? () =>
                                          _confirmCancel(context, booking.id)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                };
              },
            ),
            const ServicesHistoryView(),
          ],
        ),
        // Only shown on "My Bookings" (tab index 0) — History has no create
        // action of its own. Builder gives a context below DefaultTabController
        // so DefaultTabController.of(context) can actually find it; AnimatedBuilder
        // rebuilds just this button when the active tab changes.
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, _) => tabController.index == 0
                  ? FloatingActionButton(
                      onPressed: () => _openCreateBooking(context),
                      child: const Icon(Icons.add),
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  /// Gates entry to [CreateBookingPage] on a workshop already being selected
  /// — checked and resolved *before* pushing that page at all, so it's never
  /// visible mid-pick. (An earlier version instead asked CreateBookingPage to
  /// check for itself right after mounting, which meant the form flashed on
  /// screen for a frame before the picker slid on top of it.)
  Future<void> _openCreateBooking(BuildContext context) async {
    final cubit = context.read<SelectedWorkshopCubit>();

    if (cubit.state == null) {
      final picked = await context.push<WorkshopEntity>(RouteNames.workshops);
      if (picked == null) return; // backed out — stay on Bookings, untouched
      if (!context.mounted) return;
      cubit.select(picked);
    }

    if (context.mounted) context.push(RouteNames.createBooking);
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
      'confirmed' => Colors.green,
      'pending' => Colors.orange,
      'cancelled' => Colors.red,
      'completed' => Colors.blue,
      'in_progress' => Colors.teal,
      _ => Colors.grey,
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
