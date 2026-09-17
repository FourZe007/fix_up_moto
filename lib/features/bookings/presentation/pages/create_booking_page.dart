import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_formatter.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';

/// A bookable slot. The workshop only accepts these three windows — this
/// isn't a UI simplification, it's a real business rule, so the picker
/// offers exactly these three rather than a free-form [showTimePicker].
class _TimeSlot {
  final String label;
  final TimeOfDay start;
  const _TimeSlot(this.label, this.start);
}

const _timeSlots = [
  _TimeSlot('09:00 - 10:00', TimeOfDay(hour: 9, minute: 0)),
  _TimeSlot('10:00 - 11:00', TimeOfDay(hour: 10, minute: 0)),
  _TimeSlot('14:00 - 15:00', TimeOfDay(hour: 14, minute: 0)),
];

/// Workshop and date pickers sharing one card, split by a divider line.
///
/// Each half keeps the exact row styling the standalone tiles used (icon,
/// content, chevron) — only the outer shell changed, from two separate
/// [Material] cards to one, so the pair reads as a single "booking setup"
/// unit instead of two unrelated rows. Scoped to this file since Create
/// Booking is the only page that needs them combined; Home still uses
/// [WorkshopPickerTile] standalone.
class _BookingSetupCard extends StatelessWidget {
  final WorkshopEntity? selectedWorkshop;
  final VoidCallback onTapWorkshop;
  final DateTime? selectedDate;
  final VoidCallback onTapDate;

  const _BookingSetupCard({
    required this.selectedWorkshop,
    required this.onTapWorkshop,
    required this.selectedDate,
    required this.onTapDate,
  });

  @override
  Widget build(BuildContext context) {
    final selectedWorkshop = this.selectedWorkshop;
    final selectedDate = this.selectedDate;

    return Material(
      // Same value as chipTheme.backgroundColor (app_theme.dart) — matches
      // the time-slot chips below, so the whole page reads as one consistent
      // "neutral surface" language rather than two unrelated greys.
      color: AppColors.grey200,
      // Elevation/shadow, matching app_theme.dart's cardTheme, is this app's
      // established way of signaling "raised, tappable surface" — pairs with
      // the color match above rather than replacing it.
      elevation: 4,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _SetupRow(
            icon: Icons.storefront_outlined,
            onTap: onTapWorkshop,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            content: selectedWorkshop == null
                ? const Text('Select workshop from the existing list')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedWorkshop.bsName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        selectedWorkshop.bsAddress,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          // The dividing line the combined card was asked for — deliberately
          // plain black rather than the theme's divider grey, per request.
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade300,
            indent: 14,
            endIndent: 14,
          ),

          _SetupRow(
            icon: Icons.calendar_today_outlined,
            onTap: onTapDate,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            content: selectedDate == null
                ? const Text('Select a date')
                : Text(
                    // "Today"/"Tomorrow" for near dates — the common case,
                    // since bookings are usually made a day or two ahead —
                    // falling back to "Mon, 16 Mar 2026" further out.
                    DateFormatter.toRelativeLabel(selectedDate),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One half of [_BookingSetupCard] — icon, content, chevron. [borderRadius]
/// is only the top or bottom corners so each row's ink splash doesn't bleed
/// a rounded edge into the shared divider in the middle.
class _SetupRow extends StatelessWidget {
  final IconData icon;
  final Widget content;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _SetupRow({
    required this.icon,
    required this.content,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: content),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

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
  _TimeSlot? _selectedTimeSlot;

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

  void _submit(String serviceId) {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    // Combine date and the slot's start time into a single DateTime
    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTimeSlot!.start.hour,
      _selectedTimeSlot!.start.minute,
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
      // Matches AppBarTheme.backgroundColor (app_theme.dart) so the two read
      // as one continuous orange surface — this is what shows through the
      // body's cut top corners below, not just an empty background.
      backgroundColor: AppColors.primary,
      appBar: AppBar(title: const Text('Book Service')),
      // top: false — the AppBar already accounts for the status bar itself;
      // this only guards "Confirm Booking" at the bottom from the gesture
      // nav bar, since this page has no bottomNavigationBar to reserve that
      // space the way MainShell's tabs do.
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          // Top-only — the bottom already meets the screen edge, so rounding
          // it wouldn't be visible against anything.
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: BlocListener<BookingsBloc, BookingsState>(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlocBuilder<SelectedWorkshopCubit, WorkshopEntity?>(
                    builder: (context, selected) => _BookingSetupCard(
                      selectedWorkshop: selected,
                      onTapWorkshop: _changeWorkshop,
                      selectedDate: _selectedDate,
                      onTapDate: _pickDate,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Time slot picker — only these three windows are bookable.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Select Time',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final slot in _timeSlots)
                        ChoiceChip(
                          label: Text(slot.label),
                          selected: _selectedTimeSlot == slot,
                          onSelected: (_) =>
                              setState(() => _selectedTimeSlot = slot),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Optional notes field
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText:
                          'Any special requests or information for the mechanic',
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
        ),
      ),
    );
  }
}
