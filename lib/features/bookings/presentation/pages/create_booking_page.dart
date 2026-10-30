import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/widgets/booking_date_strip.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
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

/// Saturday and Sunday can't be booked for — the calendar greys them out, so
/// someone who wants a weekend day picks a weekday instead (e.g. the Friday
/// before).
bool isBookableDay(DateTime day) =>
    day.weekday != DateTime.saturday && day.weekday != DateTime.sunday;

/// [from], or the next day after it that [isBookableDay]. [showDatePicker]
/// asserts that its initialDate passes selectableDayPredicate, so "tomorrow"
/// can't be handed over as-is on a Friday or Saturday.
DateTime firstBookableDay(DateTime from) {
  var day = from;
  while (!isBookableDay(day)) {
    day = day.add(const Duration(days: 1));
  }
  return day;
}

/// Workshop and bike pickers sharing one card, split by a divider line.
///
/// Each half keeps the exact row styling the standalone tiles used (icon,
/// content, chevron) — only the outer shell changed, from two separate
/// [Material] cards to one, so the pair reads as a single "booking setup"
/// unit instead of two unrelated rows. Scoped to this file since Create
/// Booking is the only page that needs them combined; Home still uses
/// [WorkshopPickerTile] standalone. The date has its own section below
/// (a [BookingDateStrip]), since a row that opens a popup hid the rules.
class _BookingSetupCard extends StatelessWidget {
  final WorkshopEntity? selectedWorkshop;
  final VoidCallback onTapWorkshop;
  final BikeEntity? selectedBike;
  final VoidCallback onTapBike;

  const _BookingSetupCard({
    required this.selectedWorkshop,
    required this.onTapWorkshop,
    required this.selectedBike,
    required this.onTapBike,
  });

  @override
  Widget build(BuildContext context) {
    final selectedWorkshop = this.selectedWorkshop;
    final selectedBike = this.selectedBike;

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
                ? const Text('Pilih bengkel favorit kamu')
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
            icon: Icons.two_wheeler_outlined,
            onTap: onTapBike,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            content: selectedBike == null
                ? const Text('Pilih motor Anda')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedBike.unitId,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        selectedBike.plateNo,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
  /// How far ahead a service can be booked — the strip and the full calendar
  /// both stop here.
  static const _bookingWindowDays = 90;

  final _notesController = TextEditingController();
  final _stripController = ScrollController();

  /// The earliest day on offer: tomorrow, since there is no same-day booking.
  /// Fixed when the page opens, so the strip doesn't shift if it stays open
  /// past midnight.
  late final DateTime _firstDay = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );

  late DateTime? _selectedDate = firstBookableDay(_firstDay);
  _TimeSlot? _selectedTimeSlot;
  BikeEntity? _selectedBike;

  @override
  void dispose() {
    _notesController.dispose();
    _stripController.dispose();
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

  /// The full calendar, for jumping to a date far beyond what the strip shows
  /// at a glance. Same rules as the strip, then the strip follows the pick.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? firstBookableDay(_firstDay),
      firstDate: _firstDay,
      lastDate: DateUtils.addDaysToDate(_firstDay, _bookingWindowDays),
      selectableDayPredicate: isBookableDay,
      // Shown when a blocked date is typed in (keyboard mode) — the only place
      // inside the popup where the rules can be explained.
      errorInvalidText: 'Akhir pekan dan hari ini tidak tersedia',
      errorFormatText: 'Format tanggal tidak valid',
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    if (_stripController.hasClients) {
      _stripController.animateTo(
        BookingDateStrip.offsetFor(
          _firstDay,
          picked,
        ).clamp(0.0, _stripController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Bottom sheet rather than a full pushed route — unlike workshops (which
  /// carry maps/addresses that justify their own page), picking a bike is a
  /// smaller, in-context decision. Gives its own [BikesBloc] since this page
  /// doesn't otherwise provide one.
  Future<void> _pickBike() async {
    final picked = await showModalBottomSheet<BikeEntity>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _BikePickerSheet(),
    );
    if (picked != null && mounted) setState(() => _selectedBike = picked);
  }

  void _submit() {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih tanggal dan jam')),
      );
      return;
    }
    if (_selectedBike == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan pilih motor Anda')));
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

    // Guaranteed non-null by this page's own doc comment (a workshop must
    // already be selected before CreateBookingPage is ever reached).
    final workshop = context.read<SelectedWorkshopCubit>().state!;

    context.read<BookingsBloc>().add(
      BookingCreateRequested(
        // serviceId: serviceId,
        scheduledAt: scheduledAt,
        branch: workshop.branch,
        shop: workshop.shop,
        plateNo: _selectedBike!.plateNo,
        unitId: _selectedBike!.unitId,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  /// The day strip, with the booking rules written once beneath it. The
  /// weekend rule is [isBookableDay]; "Open Mon - Fri" and the legend line
  /// state it, so change them together.
  Widget _buildDateSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Pilih Tanggal', style: textTheme.labelLarge),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Buka Senin - Jumat',
                style: textTheme.bodySmall,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BookingDateStrip(
          controller: _stripController,
          firstDay: _firstDay,
          dayCount: _bookingWindowDays + 1,
          selectedDate: _selectedDate,
          isEnabled: isBookableDay,
          onSelected: (day) => setState(() => _selectedDate = day),
        ),
        const SizedBox(height: 12),
        Text(
          '*Booking tidak tersedia pada hari Sabtu dan Minggu. Booking minimal satu hari sebelumnya.',
          style: textTheme.bodySmall,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _pickDate,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text(
              'Lihat kalender lengkap',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  /// Time slot picker — only these three windows are bookable, shown as three
  /// equal chips across the page.
  Widget _buildTimeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pilih Jam', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _timeSlots.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _TimeSlotChip(
                  label: _timeSlots[i].label,
                  selected: _selectedTimeSlot == _timeSlots[i],
                  onTap: () =>
                      setState(() => _selectedTimeSlot = _timeSlots[i]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Matches AppBarTheme.backgroundColor (app_theme.dart) so the two read
      // as one continuous orange surface — this is what shows through the
      // body's cut top corners below, not just an empty background.
      backgroundColor: AppTheme.brandBackdrop(context),
      appBar: AppBar(title: const Text('Book Servis')),
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
        child: LightSurfaceScope(
          child: SafeArea(
            top: false,
            child: BlocListener<BookingsBloc, BookingsState>(
              listener: (context, state) {
                if (state is BookingActionSuccess) {
                  // Captured once, as an object — not re-derived from context
                  // inside the action below, since context.pop() right after
                  // this deactivates CreateBookingPage's own context. A
                  // ScaffoldMessengerState reference stays valid regardless;
                  // looking it up again from a deactivated context is what
                  // throws "Looking up a deactivated widget's ancestor".
                  final messenger = ScaffoldMessenger.of(context);

                  // Tell the Bookings tab (alive underneath) its list is out of
                  // date, so it reloads now. Read before the pop below, while
                  // this context is still active.
                  context.read<DataRefreshCubit>().invalidate(
                    DataKind.bookings,
                  );

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(state.message.toLowerCase()),
                      action: SnackBarAction(
                        label: 'Tutup',
                        onPressed: messenger.clearSnackBars,
                      ),
                    ),
                  );

                  // Pop back to the bookings list after a successful booking
                  context.pop();
                } else if (state is BookingsError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              child: Column(
                children: [
                  // The form scrolls; the summary bar below stays put, so the
                  // Confirm button is always in reach (and the keyboard no
                  // longer overflows the page when Notes is focused).
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BlocBuilder<SelectedWorkshopCubit, WorkshopEntity?>(
                            builder: (context, selected) => _BookingSetupCard(
                              selectedWorkshop: selected,
                              onTapWorkshop: _changeWorkshop,
                              selectedBike: _selectedBike,
                              onTapBike: _pickBike,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDateSection(context),
                          const SizedBox(height: 20),
                          _buildTimeSection(context),
                          const SizedBox(height: 20),
                          // Optional notes field
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Catatan (opsional)',
                              hintText:
                                  'Permintaan khusus atau informasi untuk mekanik',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // This page's BookingsBloc is its own instance (see
                  // CreateBookingPage), so BookingsLoading here can only mean
                  // "the booking is being created" — never a list refresh.
                  BlocBuilder<BookingsBloc, BookingsState>(
                    builder: (context, state) => _SummaryBar(
                      date: _selectedDate,
                      timeLabel: _selectedTimeSlot?.label,
                      bike: _selectedBike,
                      isLoading: state is BookingsLoading,
                      onConfirm: _submit,
                    ),
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

/// One of the three bookable time windows — a full-width tap target, filled in
/// the brand colour once chosen.
class _TimeSlotChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeSlotChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.grey200,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Center(
              // Scales down rather than wrapping on a narrow phone.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom bar: repeats what is about to be booked next to the Confirm
/// button, and says what is still missing instead of leaving the button
/// disabled with no explanation.
class _SummaryBar extends StatelessWidget {
  final DateTime? date;
  final String? timeLabel;
  final BikeEntity? bike;
  final bool isLoading;
  final VoidCallback onConfirm;

  const _SummaryBar({
    required this.date,
    required this.timeLabel,
    required this.bike,
    required this.isLoading,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    final timeLabel = this.timeLabel;
    final bike = this.bike;
    final textTheme = Theme.of(context).textTheme;
    final strong = textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final muted = textTheme.bodyMedium?.copyWith(color: AppColors.grey600);
    final complete = date != null && timeLabel != null && bike != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: date == null
                        ? 'Pilih tanggal'
                        : DateTimeFormatter.toDisplayDateId(date),
                    style: date == null ? muted : strong,
                  ),
                  TextSpan(text: '  ·  ', style: muted),
                  TextSpan(
                    text: timeLabel ?? 'Pilih jam',
                    style: timeLabel == null ? muted : strong,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              bike == null
                  ? 'Pilih motor Anda'
                  : '${bike.unitId} · ${bike.plateNo}',
              style: textTheme.bodySmall?.copyWith(
                color: bike == null ? AppColors.grey600 : null,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              // Disabled while in flight to prevent a double-tap from
              // creating the same booking twice, and until everything is
              // chosen.
              onPressed: complete && !isLoading ? onConfirm : null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Konfirmasi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet content for [_CreateBookingViewState._pickBike] — its own
/// [BikesBloc] (this page doesn't otherwise provide one), listing the
/// member's registered bikes and returning the tapped one via
/// `Navigator.pop(context, bike)`.
class _BikePickerSheet extends StatelessWidget {
  const _BikePickerSheet();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BikesBloc>()..add(const BikesLoadRequested()),
      child: SafeArea(
        top: false,
        child: BlocBuilder<BikesBloc, BikesState>(
          builder: (context, state) {
            return switch (state) {
              BikesInitial() ||
              BikesLoading() ||
              BikesAdded() ||
              BikesUpdated() ||
              BikesDeleted() => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              BikesError(:final message) => SizedBox(
                height: 160,
                child: Center(child: Text(message)),
              ),
              BikesLoaded(:final bikes) =>
                bikes.isEmpty
                    ? const SizedBox(
                        height: 160,
                        child: Center(child: Text('Belum ada motor terdaftar')),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: bikes.length,
                        itemBuilder: (context, index) {
                          final bike = bikes[index];
                          return ListTile(
                            leading: const Icon(Icons.two_wheeler_outlined),
                            title: Text(bike.unitId),
                            subtitle: Text(bike.plateNo),
                            onTap: () => Navigator.of(context).pop(bike),
                          );
                        },
                      ),
            };
          },
        ),
      ),
    );
  }
}
