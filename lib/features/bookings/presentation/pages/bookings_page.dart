import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/widgets/adaptive_dialog.dart';
import 'package:fix_up_moto/core/widgets/app_spinner.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/refresh/refresh_on.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/models/bike_plate_label.dart';
import 'package:fix_up_moto/features/bookings/presentation/models/booking_date_range.dart';
import 'package:fix_up_moto/features/bookings/presentation/widgets/booking_filter_sheet.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/pages/services_page.dart';

/// The Bookings tab: past service history and current bookings, as two
/// segments of one tab rather than two separate tabs — both are about the
/// member's visits to FixUp Moto, one past and one upcoming.
///
/// [BookingsBloc] fetches immediately on mount, for the confirmed
/// `BrowseTrans`/`SERVICEBOOKINGHISTORYBYMEMBER` endpoint. [ServicesBloc] cannot:
/// Riwayat asks `BrowseTrans`/`SERVICEHISTORY` about one bike's plate (and
/// nothing else — no member id), so the page first loads the member's bikes
/// through [BikesBloc], picks the first one, and only then asks for its history.
class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // No initial events on any of these: the date range and the chosen
        // plate live in _BookingsViewState, which dispatches the first loads
        // itself (see its initState and _onBikes).
        BlocProvider(create: (_) => sl<ServicesBloc>()),
        BlocProvider(create: (_) => sl<BookingsBloc>()),
        BlocProvider(create: (_) => sl<BikesBloc>()),
      ],
      child: const _BookingsView(),
    );
  }
}

class _BookingsView extends StatefulWidget {
  const _BookingsView();

  @override
  State<_BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<_BookingsView>
    with SingleTickerProviderStateMixin {
  // Owning the TabController directly (rather than DefaultTabController)
  // lets the AppBar's search hint and the FAB react to tab changes via a
  // plain listener, instead of the old Builder+AnimatedBuilder workaround
  // needed just to reach an inherited controller from inside the AppBar.
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  /// Date-only (midnight) bounds, matching how [_withinRange] compares days:
  /// tomorrow to one month later until the member picks another range.
  DateTimeRange _dateRange = BookingRangePreset.defaultRange(DateTime.now());

  /// Whether the member is looking at something other than the default range.
  /// The filter button and a chip under the tabs say so when it is.
  bool get _filterActive =>
      _dateRange != BookingRangePreset.defaultRange(DateTime.now());

  // ── Riwayat (service history) ─────────────────────────────────────────────
  // Its own filter, apart from [_dateRange]: that one looks ahead from tomorrow
  // for upcoming bookings, so applied to past visits it would hide every one.
  // The panel looks the same on both tabs, so it opens on that same default
  // range here too; the page just does not treat the default as a cut.

  /// The member's bikes, as last loaded. Kept here (not read off the bloc when
  /// the panel opens) because the bloc's state is a spinner while it reloads.
  List<BikeEntity> _bikes = const [];

  /// The bike whose history Riwayat shows. Required by the backend, so it is
  /// null only until the bikes have loaded (or if the member has none): the
  /// first bike is picked the moment they do.
  String? _plateNo;

  /// Past visits are cut to this range on the device. Null (the start, and
  /// whenever the panel is applied on its default range) shows them all: the
  /// default is tomorrow to a month ahead, which no past visit falls inside.
  DateTimeRange? _historyRange;

  /// Whether Riwayat is on something other than what it opens on (every date,
  /// the first bike). The plate is always set, so it only counts when it is not
  /// the first bike.
  bool get _historyFilterActive =>
      _historyRange != null ||
      (_bikes.isNotEmpty && _plateNo != _bikes.first.plateNo);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
    _loadBookings();
    _loadBikes();
  }

  // Opens the filter SlidingUpPanel as a transparent route on the *root*
  // navigator rather than inside this page's widget tree — MainShell always
  // paints its NavigationBar above this page's body in z-order (extendBody
  // doesn't change that), so a panel living inside this Scaffold could only
  // ever slide up *underneath* the nav bar. The root navigator sits above
  // MainShell entirely, which is what lets the panel cover the bar.
  //
  // It has to be a route, not a manual OverlayEntry in the root Overlay: the
  // Navigator keeps every route below such entries, so the date range picker
  // (also a root-navigator route) opened *under* the panel and its dimmed
  // backdrop swallowed every tap on it. Routes stack in push order, so the
  // picker lands on top of this one.
  //
  // The tab cannot change while the panel is open, so which of the two panels
  // to build is decided here, once.
  void _openFilter() {
    final history = !_onMyBookings;
    // Riwayat has nothing to choose between without a bike. (The filter button
    // is disabled then; this guards a stale tap.)
    if (history && _bikes.isEmpty) return;

    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      // The panel's own backdrop dims the page and closes the panel on a tap,
      // so the route adds neither a barrier nor a transition of its own.
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => history
          ? BookingFilterSheet(
              initialRange:
                  _historyRange ??
                  BookingRangePreset.defaultRange(DateTime.now()),
              bikes: _bikes,
              initialPlateNo: _plateNo,
              onApply: _applyHistoryFilter,
            )
          : BookingFilterSheet(
              initialRange: _dateRange,
              onApply: (range, _) => _applyDateRange(range),
            ),
    );
  }

  /// The filter button works on My Bookings always, and on Riwayat once there is
  /// a bike to choose.
  bool get _canOpenFilter => _onMyBookings || _bikes.isNotEmpty;

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _onMyBookings => _tabController.index == 0;

  /// Inclusive on both ends.
  bool _withinRange(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(_dateRange.start) && !day.isAfter(_dateRange.end);
  }

  /// Matches on workshop name, plate number, or motorcycle model — the
  /// things someone actually remembers about a booking.
  List<BookingEntity> _filterBookings(List<BookingEntity> bookings) {
    final query = _query.toLowerCase();
    return bookings.where((b) {
      final matchesQuery =
          query.isEmpty ||
          b.bsName.toLowerCase().contains(query) ||
          b.plateNo.toLowerCase().contains(query) ||
          b.unitId.toLowerCase().contains(query);
      return matchesQuery && _withinRange(b.scheduledAt);
    }).toList();
  }

  /// Fetches the bookings inside the current [_dateRange] from the backend.
  void _loadBookings() => context.read<BookingsBloc>().add(
    BookingsListRequested(range: _dateRange),
  );

  // The panel's "Reset" and the chip's cross both pass the default range.
  // The new range is fetched from the backend rather than only filtered on the
  // device.
  void _applyDateRange(DateTimeRange range) {
    // The panel is a route of its own and can outlive this page's State.
    if (!mounted) return;
    setState(() => _dateRange = range);
    _loadBookings();
  }

  void _resetDateRange() =>
      _applyDateRange(BookingRangePreset.defaultRange(DateTime.now()));

  /// Fetches the member's bikes: the plates Riwayat can ask about.
  void _loadBikes() =>
      context.read<BikesBloc>().add(const BikesLoadRequested());

  /// Fetches the history of the chosen bike. Nothing to ask without a plate.
  void _loadHistory() {
    final plateNo = _plateNo;
    if (plateNo == null) return;
    context.read<ServicesBloc>().add(ServicesListRequested(plateNo: plateNo));
  }

  /// The bikes arrived (first load, or a reload after one was added, edited or
  /// deleted). Keeps the chosen plate if that bike is still there; otherwise
  /// picks the first one, and with none there is nothing to show.
  void _onBikes(BuildContext context, BikesState state) {
    if (state is! BikesLoaded) return;

    final bikes = state.bikes;
    final before = _plateNo;
    final stillThere = bikes.any((bike) => bike.plateNo == before);
    final plateNo = stillThere
        ? before
        : (bikes.isEmpty ? null : bikes.first.plateNo);

    setState(() {
      _bikes = bikes;
      _plateNo = plateNo;
    });
    // Only a different bike changes what Riwayat shows.
    if (plateNo != before) _loadHistory();
  }

  /// From the Riwayat panel. A new plate is fetched from the backend; a new
  /// date range only changes what is cut from what is already loaded. The
  /// panel's default range (what it opens on, and what "Reset" gives) is no cut
  /// at all, as it is for My Bookings, where the default is simply not a filter.
  void _applyHistoryFilter(DateTimeRange range, String? plateNo) {
    // The panel is a route of its own and can outlive this page's State.
    if (!mounted) return;
    final changedPlate = plateNo != null && plateNo != _plateNo;
    final isDefault = range == BookingRangePreset.defaultRange(DateTime.now());
    setState(() {
      _historyRange = isDefault ? null : range;
      if (plateNo != null) _plateNo = plateNo;
    });
    if (changedPlate) _loadHistory();
  }

  void _resetHistoryRange() => setState(() => _historyRange = null);

  @override
  Widget build(BuildContext context) {
    // The bar is orange in light mode (dark text) and black in dark mode
    // (white text) — a fixed dark colour would vanish on the black bar.
    final searchColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : AppColors.backgroundDark;

    // This tab stays alive while hidden, so it reloads the moment a booking is
    // created elsewhere (the create page signals DataKind.bookings), and its
    // plate list the moment a bike is added, edited or deleted (DataKind.bikes).
    //
    // The bikes listener sits here, above both tabs, rather than inside
    // Riwayat: the TabBarView only builds the tab on screen, and the first
    // bike must be picked (and its history asked for) whichever tab is open.
    return RefreshOn(
      kind: DataKind.bookings,
      onRefresh: (_) => _loadBookings(),
      child: RefreshOn(
        kind: DataKind.bikes,
        onRefresh: (_) => _loadBikes(),
        child: BlocListener<BikesBloc, BikesState>(
          listener: _onBikes,
          child: _scaffold(context, searchColor),
        ),
      ),
    );
  }

  Widget _scaffold(BuildContext context, Color searchColor) {
    final filterOn = _onMyBookings ? _filterActive : _historyFilterActive;
    final filterName = _onMyBookings ? 'Filter tanggal' : 'Filter riwayat';

    return Scaffold(
      // MainShell.backdropOf repeats this colour for the iOS tab bar's strip.
      backgroundColor: AppTheme.brandBackdrop(context),
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          style: TextStyle(color: searchColor),
          cursorColor: searchColor,
          decoration: InputDecoration(
            border: InputBorder.none,
            // isDense + a tight contentPadding collapse the default
            // InputDecoration height (~48+) down to fit the AppBar's title
            // slot instead of visually overflowing it.
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            // Same search bar, different target — swaps with the active tab
            // rather than being two separate fields.
            hintText: _onMyBookings
                ? 'Cari booking kamu'
                : 'Cari riwayat servis',
            hintStyle: TextStyle(color: AppColors.grey400, fontSize: 14),
          ),
        ),
        actions: [
          // My Bikes Button
          IconButton(
            icon: const Icon(Icons.motorcycle_rounded),
            tooltip: 'Motor Saya',
            onPressed: () => context.push(RouteNames.myBikes),
          ),

          // Filter button — a dot on it says a filter is on. It follows the
          // tab: dates on My Bookings, bike and dates on Riwayat (where it
          // waits for a bike).
          IconButton(
            icon: Badge(
              isLabelVisible: filterOn,
              smallSize: 10,
              backgroundColor: Colors.white,
              child: const Icon(Icons.tune),
            ),
            tooltip: filterOn ? '$filterName (aktif)' : filterName,
            onPressed: _canOpenFilter ? _openFilter : null,
          ),
        ],
        bottom: TabBar(
          dividerColor: Colors.transparent,
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Bookings'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          // Top-only — the bottom already meets the screen edge, so rounding
          // it wouldn't be visible against anything.
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // The filter SlidingUpPanel is a root-navigator route (see
        // _openFilter) rather than part of this page, so this is plain page
        // content — no LayoutBuilder/MediaQuery workaround needed either,
        // since that was only ever fixing SlidingUpPanel's own `body:` sizing,
        // which it no longer has.
        child: LightSurfaceScope(
          child: Column(
            children: [
              // Says which range My Bookings is cut to, once it is not the
              // default; its cross goes back to the default.
              if (_onMyBookings && _filterActive)
                _ActiveRangeChip(
                  range: _dateRange,
                  onTap: _openFilter,
                  onClear: _resetDateRange,
                ),
              // Riwayat always says which bike it shows (the backend answers
              // per plate, so there is always one), and which dates once cut.
              if (!_onMyBookings && _plateNo != null)
                _HistoryChips(
                  plateLabel:
                      _bikes
                          .where((bike) => bike.plateNo == _plateNo)
                          .map((bike) => bike.plateLabel)
                          .firstOrNull ??
                      _plateNo!,
                  range: _historyRange,
                  onTap: _openFilter,
                  onClearRange: _resetHistoryRange,
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: BlocConsumer<BookingsBloc, BookingsState>(
                        listener: (context, state) {
                          if (state is BookingActionSuccess) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(state.message)),
                            );
                          }
                        },
                        builder: (context, state) {
                          return switch (state) {
                            // Only visible for the first frame: initState dispatches
                            // the first load, which moves the bloc on to Loading.
                            BookingsInitial() => Center(
                              child: Column(
                                spacing: 12,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Belum ada pemesanan'),

                                  OutlinedButton.icon(
                                    onPressed: _loadBookings,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Muat ulang'),
                                  ),
                                ],
                              ),
                            ),
                            BookingsLoading() => const Center(
                              child: Column(
                                spacing: 20,
                                mainAxisSize: MainAxisSize.min,
                                children: [AppSpinner(), Text('Loading...')],
                              ),
                            ),
                            BookingsError(:final message) => Center(
                              child: Text(message),
                            ),
                            BookingActionSuccess() => const Center(
                              child: Column(
                                spacing: 20,
                                mainAxisSize: MainAxisSize.min,
                                children: [AppSpinner(), Text('Loading...')],
                              ),
                            ),
                            BookingsLoaded(:final bookings) =>
                              _buildBookingsList(context, bookings),
                          };
                        },
                      ),
                    ),
                    _buildHistory(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Only shown on "My Bookings" (tab index 0) — History has no create
      // action of its own.
      floatingActionButton: _onMyBookings
          ? FloatingActionButton(
              onPressed: () => _openCreateBooking(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// The Riwayat tab. Once a bike is chosen it shows that bike's history; until
  /// then there is nothing to ask the backend about, so it shows where the
  /// member is on the way to one: loading the bikes, failing to, or having none.
  Widget _buildHistory() {
    final plateNo = _plateNo;
    if (plateNo != null) {
      return ServicesHistoryView(
        query: _query,
        dateRange: _historyRange,
        plateNo: plateNo,
      );
    }

    return BlocBuilder<BikesBloc, BikesState>(
      builder: (context, state) {
        return switch (state) {
          BikesError(:final message) => Center(
            child: Column(
              spacing: 12,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(message, textAlign: TextAlign.center),
                OutlinedButton.icon(
                  key: const Key('history-bikes-retry'),
                  onPressed: _loadBikes,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Muat ulang'),
                ),
              ],
            ),
          ),
          BikesLoaded(:final bikes) when bikes.isEmpty => Center(
            key: const Key('history-no-bikes'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                spacing: 12,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Belum ada motor terdaftar',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    'Riwayat servis ditampilkan per motor. Tambahkan motor '
                    'kamu dulu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.grey700),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(RouteNames.myBikes),
                    icon: const Icon(Icons.motorcycle_rounded),
                    label: const Text('Motor Saya'),
                  ),
                ],
              ),
            ),
          ),
          // Not loaded yet (or loaded a moment ago, before the page has picked
          // the first bike): the same spinner as everywhere else.
          _ => const Center(
            child: Column(
              spacing: 20,
              mainAxisSize: MainAxisSize.min,
              children: [AppSpinner(), Text('Loading...')],
            ),
          ),
        };
      },
    );
  }

  Widget _buildBookingsList(
    BuildContext context,
    List<BookingEntity> bookings,
  ) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          spacing: 12,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Belum ada pemesanan', style: TextStyle(fontSize: 14)),

            OutlinedButton.icon(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh),
              label: const Text('Muat ulang'),
              style: OutlinedButton.styleFrom(
                iconSize: 16,
                minimumSize: Size.zero,
                padding: const EdgeInsets.all(16),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filterBookings(bookings);
    if (filtered.isEmpty) {
      return const Center(child: Text('No bookings match your search'));
    }

    return RefreshIndicator.adaptive(
      onRefresh: () async => _loadBookings(),
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final booking = filtered[index];
          return Card(
            // Flat, bordered look instead of the theme's default shadow —
            // elevation: 0 removes the shadow entirely rather than just
            // hiding its color, which would still reserve shadow space.
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              // The same warm hairline as the Riwayat card and the invoices,
              // so the two tabs' cards read as one design.
              side: const BorderSide(color: AppColors.peachHairline),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              // Show cancel option only for upcoming bookings
              onLongPress: booking.isUpcoming
                  ? () => _confirmCancel(context, booking.id)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                // Every branch name repeats "FIXUP MOTO - ";
                                // only the location itself is worth the
                                // title's attention.
                                _branchLocationName(booking.bsName),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                // "Mon, 10 Mar 2026 • 10:30 AM"
                                DateTimeFormatter.toFullDateTime(
                                  booking.scheduledAt,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.grey700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusLabel(status: booking.status),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppColors.peachHairline),
                    ),
                    Text(
                      '${booking.plateNo} · ${booking.unitId}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.grey700,
                      ),
                    ),
                    if (booking.notes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        booking.notes ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Strips the repeated "FIXUP MOTO - " brand prefix every `bsName` carries
  /// — e.g. "FIXUP MOTO - KEDUNG TARUKAN" → "KEDUNG TARUKAN" — so the card
  /// title shows only the branch location, which is the part that actually
  /// distinguishes one booking from another. Falls back to the full name if
  /// the prefix isn't there.
  String _branchLocationName(String bsName) {
    final match = RegExp(
      r'^FIXUP MOTO\s*-\s*',
      caseSensitive: false,
    ).firstMatch(bsName);
    if (match == null) return bsName;
    return bsName.substring(match.end).trim();
  }

  /// Opens [CreateBookingPage]. There used to be a workshop list in front of it
  /// when none was chosen; now the form picks a default itself (the first open
  /// workshop) and lets the member change it from its own workshop row.
  void _openCreateBooking(BuildContext context) =>
      context.push(RouteNames.createBooking);

  void _confirmCancel(BuildContext context, String bookingId) {
    showAdaptiveDialog<void>(
      context: context,
      // The dialog's own context for closing it, not the page's: the dialog
      // lives on the root navigator, and the page's nearest navigator may be a
      // tab's own, which popping would close the page under it instead.
      builder: (dialogContext) => AdaptiveAlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          AdaptiveDialogAction(
            // Red on iOS; an ordinary button on Android, as before.
            isDestructive: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<BookingsBloc>().add(
                BookingCancelRequested(bookingId),
              );
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}

/// The range the lists are cut to, as a chip under the tabs: tap it to change
/// the range, its cross to go back to the default. Shown only while the range
/// is not the default.
class _ActiveRangeChip extends StatelessWidget {
  final DateTimeRange range;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ActiveRangeChip({
    required this.range,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          key: const Key('bookings-range-chip'),
          avatar: const Icon(
            Icons.date_range_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          label: Text(range.chipLabel),
          onPressed: onTap,
          onDeleted: onClear,
          deleteButtonTooltipMessage: 'Hapus filter tanggal',
          backgroundColor: AppColors.peachMist,
          side: const BorderSide(color: AppColors.peachHairline),
        ),
      ),
    );
  }
}

/// What Riwayat is showing, as chips under the tabs: the bike (always — there
/// is no "all bikes"), and the date range once it is cut. Tapping either opens
/// the panel; the range's cross goes back to every date. The bike has no cross,
/// since one is required.
class _HistoryChips extends StatelessWidget {
  final String plateLabel;
  final DateTimeRange? range;
  final VoidCallback onTap;
  final VoidCallback onClearRange;

  const _HistoryChips({
    required this.plateLabel,
    required this.range,
    required this.onTap,
    required this.onClearRange,
  });

  @override
  Widget build(BuildContext context) {
    final range = this.range;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            InputChip(
              key: const Key('history-plate-chip'),
              avatar: const Icon(
                Icons.motorcycle_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              label: Text(plateLabel),
              onPressed: onTap,
              backgroundColor: AppColors.peachMist,
              side: const BorderSide(color: AppColors.peachHairline),
            ),
            if (range != null)
              InputChip(
                key: const Key('history-range-chip'),
                avatar: const Icon(
                  Icons.date_range_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: Text(range.chipLabel),
                onPressed: onTap,
                onDeleted: onClearRange,
                deleteButtonTooltipMessage: 'Hapus filter tanggal',
                backgroundColor: AppColors.peachMist,
                side: const BorderSide(color: AppColors.peachHairline),
              ),
          ],
        ),
      ),
    );
  }
}

/// The booking status string verbatim (the backend sends Bahasa Indonesia
/// text, e.g. "MENUNGGU KONFIRMASI" — not a fixed enum), as plain coloured text
/// like the amount on the Riwayat card, with no tinted, outlined box. Only the
/// one confirmed value gets its own colour; anything else stays neutral until
/// more of the vocabulary is confirmed against the backend, rather than
/// guessing translations/other status strings.
class _StatusLabel extends StatelessWidget {
  final String status;
  const _StatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toUpperCase()) {
      'MENUNGGU KONFIRMASI' => AppColors.warning,
      _ => AppColors.grey600,
    };

    return Text(
      status,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
