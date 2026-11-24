import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fix_up_moto/core/helpers/haptics.dart';
import 'package:fix_up_moto/core/tour/field_guide.dart';
import 'package:fix_up_moto/core/tour/field_guide_help_button.dart';
import 'package:fix_up_moto/core/tour/field_guide_player.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';
import 'package:fix_up_moto/core/widgets/app_spinner.dart';
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
import 'package:fix_up_moto/core/services/location_service.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/domain/nearest_workshop.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_bloc.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_event.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_state.dart';
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

  /// True while the default workshop is being looked up, so the empty row says
  /// so instead of inviting a pick the page is about to make itself.
  final bool loadingWorkshop;

  /// Keys on the two rows, which the field guide lights up one at a time.
  final Key? workshopKey;
  final Key? bikeKey;

  const _BookingSetupCard({
    required this.selectedWorkshop,
    required this.onTapWorkshop,
    required this.selectedBike,
    required this.onTapBike,
    this.loadingWorkshop = false,
    this.workshopKey,
    this.bikeKey,
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
            key: workshopKey,
            icon: Icons.storefront_outlined,
            onTap: onTapWorkshop,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            content: selectedWorkshop == null
                ? Text(
                    loadingWorkshop
                        ? 'Memuat bengkel...'
                        : 'Pilih bengkel favorit kamu',
                  )
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
            key: bikeKey,
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
    super.key,
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
/// **The workshop is chosen here, not before.** No step in front of this page
/// asks for one (the Bookings tab's button, `startGuidedBooking` and a service's
/// "Book Again" all push straight in). If [SelectedWorkshopCubit] already holds
/// one (picked on Home, or earlier) it is shown as it is; if not, the page looks
/// up the workshop list itself and selects the **nearest open** one to where the
/// member is (see [LocationService]; an inactive workshop cannot be picked in the
/// list either), or the first open one in the list when the app cannot tell where
/// they are. The member sees a real default with a row to change it. Until a
/// workshop is there, Konfirmasi stays off, and if the list cannot be loaded the
/// row reads "Pilih bengkel favorit kamu" and opens the list the usual way.
class CreateBookingPage extends StatelessWidget {
  /// True when the booking was started away from the Bookings tab, by the
  /// first-task guidance (see `FirstTaskStep.createBooking`). Once it is made,
  /// the confirmation then points to the Booking tab, where the member can see
  /// it, instead of leaving them to find it. False (the default) is the plain
  /// confirmation, as for every other way of getting here.
  final bool pointToBookings;

  /// Switches on the field guide: a help button in the app bar that walks the
  /// member through everything on the page (see `FieldGuidePlayer`), remembering
  /// on the phone that it has been seen. Null (the default) leaves the page
  /// exactly as it was.
  final SharedPreferences? guidePrefs;

  /// Whether the guide also plays by itself, once, the first time the page opens
  /// on a phone that has not seen it. The router sets it for a member whose first
  /// booking is still to make; anyone else only has the help button. Ignored
  /// without [guidePrefs].
  final bool autoGuide;

  const CreateBookingPage({
    super.key,
    this.pointToBookings = false,
    this.guidePrefs,
    this.autoGuide = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<BookingsBloc>()),
        // Lazy: only built, and only asks the server, when the view reads it
        // because no workshop is chosen yet (see _findDefaultWorkshop).
        BlocProvider(
          create: (_) => sl<WorkshopsBloc>()..add(const WorkshopsRequested()),
        ),
      ],
      child: _CreateBookingView(
        pointToBookings: pointToBookings,
        guidePrefs: guidePrefs,
        autoGuide: autoGuide,
      ),
    );
  }
}

class _CreateBookingView extends StatefulWidget {
  final bool pointToBookings;
  final SharedPreferences? guidePrefs;
  final bool autoGuide;

  const _CreateBookingView({
    required this.pointToBookings,
    required this.guidePrefs,
    required this.autoGuide,
  });

  @override
  State<_CreateBookingView> createState() => _CreateBookingViewState();
}

class _CreateBookingViewState extends State<_CreateBookingView> {
  /// How far ahead a service can be booked — the strip and the full calendar
  /// both stop here.
  static const _bookingWindowDays = 90;

  final _notesController = TextEditingController();
  final _stripController = ScrollController();

  // One key per thing the field guide lights up, in the page's order.
  final _workshopKey = GlobalKey();
  final _bikeKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _timeKey = GlobalKey();
  final _notesKey = GlobalKey();
  final _summaryKey = GlobalKey();

  /// The form's own scroll, so the end of the guide can take it back to the top.
  final _scroll = ScrollController();

  /// True while the guide plays: the app bar's help button steps aside for it.
  final _guideActive = ValueNotifier<bool>(false);

  /// Blank scroll room under the form while the guide plays (0 otherwise), so
  /// the last steps can scroll up to where the others sit (see
  /// [FieldGuidePlayer]).
  double _guideRoom = 0;

  late final FieldGuidePlayer _player;

  /// True while the default workshop is being looked up (none was chosen when
  /// the page opened).
  bool _findingWorkshop = false;
  StreamSubscription<WorkshopsState>? _workshopsSub;

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
  void initState() {
    super.initState();
    _player = FieldGuidePlayer(
      guideId: FieldGuideId.createBooking,
      steps: _guideSteps,
      state: this,
      prefs: widget.guidePrefs,
      scroll: _scroll,
      active: _guideActive,
      onRoomChanged: (room) => setState(() => _guideRoom = room),
    );
    // The guide waits for the workshop lookup: it may put the system's location
    // prompt on screen, and the guide's Bengkel card talks about the result.
    if (widget.autoGuide) {
      _player.autoPlayOnce(ready: () => !_findingWorkshop);
    }
    _findDefaultWorkshop();
  }

  /// With no workshop chosen yet, looks the list up and selects the nearest open
  /// workshop (the first open one if the member's position is unknown). Reads the
  /// workshops bloc only in that case, so a member who already has a choice costs
  /// no request, and asks for a position only then too. Never overrides a pick:
  /// if the member chose one from the row while this was going on, theirs wins.
  void _findDefaultWorkshop() {
    if (context.read<SelectedWorkshopCubit>().state != null) return;

    _findingWorkshop = true;
    _workshopsSub = context.read<WorkshopsBloc>().stream.listen((state) async {
      if (state is WorkshopsLoaded) await _chooseDefault(state.workshops);
      if (!mounted) return;
      if (state is WorkshopsLoaded || state is WorkshopsError) {
        unawaited(_workshopsSub?.cancel());
        _workshopsSub = null;
        setState(() => _findingWorkshop = false);
      }
    });
  }

  /// How long to wait for the member's position before booking on without it.
  ///
  /// A safety net, not the real bound: the location service limits the fix to a
  /// few seconds itself. It is long on purpose, because the wait includes the
  /// member reading the system's location prompt, which covers this page and
  /// cannot be hurried; this only stops a service that never answers from holding
  /// the booking up for good.
  static const _locationWait = Duration(seconds: 30);

  Future<void> _chooseDefault(List<WorkshopEntity> workshops) async {
    final here = await sl<LocationService>().currentPosition().timeout(
      _locationWait,
      onTimeout: () => null,
    );
    // The page may be gone, or the member may have picked a workshop while the
    // position was being found: theirs wins.
    if (!mounted) return;
    final chosen = context.read<SelectedWorkshopCubit>();
    if (chosen.state != null) return;

    final pick =
        (here == null ? null : nearestWorkshop(workshops, here)) ??
        firstActiveWorkshop(workshops);
    if (pick != null) chosen.select(pick);
  }

  @override
  void dispose() {
    unawaited(_workshopsSub?.cancel());
    // Takes the guide off the screen too (a back press mid-guide).
    _player.dispose();
    _guideActive.dispose();
    _scroll.dispose();
    _notesController.dispose();
    _stripController.dispose();
    super.dispose();
  }

  /// What the guide says, in the page's top-to-bottom order. The booking rules
  /// quoted here (Monday to Friday, a day ahead, the three time windows) are the
  /// ones the page enforces ([isBookableDay], [_timeSlots]); change them together.
  ///
  /// "Wajib diisi" is true of what [_submit] refuses to go on without (a date,
  /// a time and a bike). The date already holds the earliest day on offer, so the
  /// member only changes it if they want another. The workshop is chosen before
  /// the page opens, and the last step is a button: neither gets a tag.
  late final List<FieldGuideStep> _guideSteps = [
    FieldGuideStep(
      key: _workshopKey,
      title: 'Bengkel',
      message:
          'Bengkel tempat motor Anda akan diservis. Bengkel terdekat dari '
          'lokasi Anda dipilih otomatis (bengkel pertama jika lokasi tidak '
          'aktif); pastikan sesuai, atau ketuk untuk memilih bengkel lain.',
    ),
    FieldGuideStep(
      key: _bikeKey,
      title: 'Motor',
      message: 'Pilih motor yang akan diservis dari daftar motor Anda.',
      required: true,
      // The one thing a first-time member is most likely to trip on. Kept short:
      // the card has to fit under the bike row on a small phone.
      warning:
          'Jangan lupa, Anda harus mengisi data motor terlebih dahulu sebelum '
          'bisa membuat booking.',
    ),
    FieldGuideStep(
      key: _dateKey,
      title: 'Tanggal',
      message:
          'Geser dan pilih tanggal servis. Booking hanya tersedia Senin sampai '
          'Jumat dan minimal satu hari sebelumnya. Untuk tanggal yang lebih '
          'jauh, ketuk "Lihat kalender lengkap".',
      required: true,
    ),
    FieldGuideStep(
      key: _timeKey,
      title: 'Jam',
      message:
          'Pilih salah satu dari tiga jam servis: 09:00 - 10:00, 10:00 - 11:00, '
          'atau 14:00 - 15:00.',
      required: true,
    ),
    FieldGuideStep(
      key: _notesKey,
      title: 'Catatan',
      message:
          'Tulis permintaan khusus atau informasi untuk mekanik, misalnya '
          'keluhan pada motor Anda.',
      required: false,
    ),
    FieldGuideStep(
      key: _summaryKey,
      title: 'Konfirmasi',
      message:
          'Periksa ringkasan booking Anda di sini, lalu ketuk Konfirmasi. Jika '
          'ada yang belum dipilih, tombolnya belum bisa ditekan.',
      // The bar is fixed at the bottom of the screen: no room below it.
      cardAbove: true,
    ),
  ];

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
      // The default datetime pad is digits-only on many phones, with no "/" to
      // type a date by hand.
      keyboardType: TextInputType.text,
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
  ///
  /// The sheet answers with the tapped bike, or with [_PickerAnswer.addBike]
  /// when the member has none and asked to add one (see [_addBikeThenPick]).
  Future<void> _pickBike() async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _BikePickerSheet(),
    );
    if (!mounted) return;
    if (picked is BikeEntity) {
      setState(() => _selectedBike = picked);
    } else if (picked == _PickerAnswer.addBike) {
      await _addBikeThenPick();
    }
  }

  /// For a member with no bike: opens Add Bike on top of this page, and once a
  /// bike has really been saved, opens the picker again so the new bike is one
  /// tap away. The booking they were filling in is still here, as they left it.
  ///
  /// Add Bike tells the rest of the app (stats, bike list) itself; this only
  /// needs to know it succeeded. Backing out (`null`/`false`) leaves the member
  /// where they were, with no bike chosen.
  Future<void> _addBikeThenPick() async {
    final added = await context.push<bool>(RouteNames.addBike);
    if (added == true && mounted) await _pickBike();
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

    // Normally there already is one (see the class comment); not if the list
    // could not be loaded and none was picked by hand.
    final workshop = context.read<SelectedWorkshopCubit>().state;
    if (workshop == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan pilih bengkel')));
      return;
    }

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
          key: _dateKey,
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
          key: _timeKey,
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
      appBar: AppBar(
        title: const Text('Book Servis'),
        actions: [
          // Plays the field guide again, any time: the automatic one only
          // happens once, and only for a member with a first booking to make.
          if (widget.guidePrefs != null)
            FieldGuideHelpButton(
              buttonKey: const Key('create-booking-guide-button'),
              active: _guideActive,
              onPressed: _player.play,
            ),
        ],
      ),
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
                  Haptics.success();

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

                  if (widget.pointToBookings) {
                    // The member did not come from the Bookings tab, so the
                    // page they land on is not their bookings: say where it is,
                    // with a button that goes there. Like [messenger], taken
                    // before the pop below.
                    final router = GoRouter.of(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Booking berhasil! Lihat di tab Booking.',
                        ),
                        // A pointer, not a notice to keep: it goes by itself
                        // (a snack bar with a button would otherwise stay).
                        persist: false,
                        duration: const Duration(seconds: 10),
                        action: SnackBarAction(
                          label: 'Lihat',
                          onPressed: () => router.go(RouteNames.bookings),
                        ),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(state.message.toLowerCase()),
                        action: SnackBarAction(
                          label: 'Tutup',
                          onPressed: messenger.clearSnackBars,
                        ),
                      ),
                    );
                  }

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
                      controller: _scroll,
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
                              loadingWorkshop: _findingWorkshop,
                              workshopKey: _workshopKey,
                              bikeKey: _bikeKey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDateSection(context),
                          const SizedBox(height: 20),
                          _buildTimeSection(context),
                          const SizedBox(height: 20),
                          // Optional notes field
                          TextFormField(
                            key: _notesKey,
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Catatan (opsional)',
                              hintText:
                                  'Permintaan khusus atau informasi untuk mekanik',
                            ),
                          ),
                          // Only while the field guide plays (see [_guideRoom]).
                          if (_guideRoom > 0) SizedBox(height: _guideRoom),
                        ],
                      ),
                    ),
                  ),
                  // This page's BookingsBloc is its own instance (see
                  // CreateBookingPage), so BookingsLoading here can only mean
                  // "the booking is being created" — never a list refresh.
                  BlocBuilder<SelectedWorkshopCubit, WorkshopEntity?>(
                    builder: (context, workshop) =>
                        BlocBuilder<BookingsBloc, BookingsState>(
                          builder: (context, state) => _SummaryBar(
                            key: _summaryKey,
                            date: _selectedDate,
                            timeLabel: _selectedTimeSlot?.label,
                            bike: _selectedBike,
                            hasWorkshop: workshop != null,
                            isLoading: state is BookingsLoading,
                            onConfirm: _submit,
                          ),
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

  /// Whether a workshop is chosen: the booking needs one, and the page picks a
  /// default itself, so it is only missing while that is loading or if it failed.
  final bool hasWorkshop;
  final bool isLoading;
  final VoidCallback onConfirm;

  const _SummaryBar({
    super.key,
    required this.date,
    required this.timeLabel,
    required this.bike,
    this.hasWorkshop = true,
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
    final complete =
        date != null && timeLabel != null && bike != null && hasWorkshop;

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
                      child: AppSpinner(
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

/// What the bike picker answers besides a bike.
enum _PickerAnswer {
  /// The member has no bike and wants to add one now.
  addBike,
}

/// The picker for a member with no bike registered. A booking needs a bike, so
/// instead of a dead end it says why and offers the way forward: closing the
/// sheet with [_PickerAnswer.addBike], which [_CreateBookingViewState] answers
/// by opening Add Bike.
///
/// "Belum ada motor terdaftar" is the same line Riwayat shows for the same case.
class _NoBikesYet extends StatelessWidget {
  const _NoBikesYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          const Icon(
            Icons.two_wheeler_outlined,
            size: 40,
            color: AppColors.primary,
          ),
          Text(
            'Belum ada motor terdaftar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Daftarkan motor Anda dulu untuk membuat booking.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('booking-add-bike'),
              onPressed: () => Navigator.of(context).pop(_PickerAnswer.addBike),
              child: const Text('Tambah Motor'),
            ),
          ),
        ],
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
                child: Center(child: AppSpinner()),
              ),
              BikesError(:final message) => SizedBox(
                height: 160,
                child: Center(child: Text(message)),
              ),
              BikesLoaded(:final bikes) =>
                bikes.isEmpty
                    ? const _NoBikesYet()
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
