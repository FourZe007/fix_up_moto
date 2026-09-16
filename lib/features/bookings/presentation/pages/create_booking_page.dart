import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';
import 'package:fix_up_moto/features/workshops/presentation/widgets/workshop_picker_tile.dart';

/// Form page for creating a new service booking.
///
/// Reached via `context.push(RouteNames.createBooking)` from the Bookings
/// tab's FAB — GoRouter puts pushed routes on the Navigator as their own
/// page, not nested inside BookingsPage's widget tree, so this needs its
/// own [BookingsBloc] rather than relying on BookingsPage's provider (which
/// a pushed page can never see).
///
/// A workshop must already be selected by the time this page is reached —
/// [BookingsPage]'s FAB gates on that before ever pushing here, so this page
/// only ever needs to display [SelectedWorkshopCubit]'s current value and let
/// the user change it, never force-collect it itself.
class CreateBookingPage extends StatelessWidget {
  const CreateBookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BookingsBloc>(),
      child: const _CreateBookingView(),
    );
  }
}

class _CreateBookingView extends StatefulWidget {
  const _CreateBookingView();

  @override
  State<_CreateBookingView> createState() => _CreateBookingViewState();
}

class _CreateBookingViewState extends State<_CreateBookingView> {
  final _notesController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Re-pick from the tile — always optional, since [BookingsPage] already
  /// guaranteed a selection exists before this page was ever reached.
  Future<void> _changeWorkshop() async {
    final picked = await context.push<WorkshopEntity>(RouteNames.workshops);
    if (picked != null && mounted) {
      context.read<SelectedWorkshopCubit>().select(picked);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _submit(String serviceId) {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    // Combine date and time into a single DateTime
    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    context.read<BookingsBloc>().add(
          BookingCreateRequested(
            serviceId: serviceId,
            scheduledAt: scheduledAt,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    // TODO: pass serviceId via GoRouter extras or path parameter
    const serviceId = 'placeholder-service-id';

    return Scaffold(
      appBar: AppBar(title: const Text('Book Service')),
      body: BlocListener<BookingsBloc, BookingsState>(
        listener: (context, state) {
          if (state is BookingActionSuccess) {
            // Pop back to the bookings list after a successful booking
            Navigator.of(context).pop();
          } else if (state is BookingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlocBuilder<SelectedWorkshopCubit, WorkshopEntity?>(
                builder: (context, selected) => WorkshopPickerTile(
                  selected: selected,
                  onTap: _changeWorkshop,
                ),
              ),
              const SizedBox(height: 16),
              // Date picker row
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                ),
                onTap: _pickDate,
              ),
              // Time picker row
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  _selectedTime == null
                      ? 'Select Time'
                      : _selectedTime!.format(context),
                ),
                onTap: _pickTime,
              ),
              const SizedBox(height: 16),
              // Optional notes field
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Any special requests or information for the mechanic',
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _submit(serviceId),
                child: const Text('Confirm Booking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
