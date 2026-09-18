import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_formatter.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';
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
/// Both [ServicesBloc] and [BookingsBloc] fetch immediately on mount now that
/// `BookingsRepositoryImpl.getBookings()` targets the confirmed
/// `BrowseTrans`/`SERVICEBOOKINGHISTORYBYMEMBER` endpoint.
class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<ServicesBloc>()..add(const ServicesListRequested()),
        ),
        BlocProvider(
          create: (_) => sl<BookingsBloc>()..add(const BookingsListRequested()),
        ),
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
  final _panelController = PanelController();
  String _query = '';
  DateTimeRange? _dateRange;

  // Mounts the filter SlidingUpPanel into the app's root Overlay rather than
  // this page's own widget tree — MainShell always paints its NavigationBar
  // above this page's body in z-order (extendBody doesn't change that), so a
  // panel living inside this Scaffold could only ever slide up *underneath*
  // the nav bar. The root Overlay sits above MainShell entirely (the same
  // layer showModalBottomSheet(useRootNavigator: true) uses), which is what
  // actually lets the panel cover the bar when opened.
  OverlayEntry? _filterOverlayEntry;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _insertFilterOverlay());
  }

  void _insertFilterOverlay() {
    if (!mounted) return;
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: SlidingUpPanel(
          controller: _panelController,
          minHeight: 0,
          maxHeight: 300,
          // Defaults to false — without it, sliding_up_panel skips its whole
          // backdrop branch (panel.dart:275) and the dim/tap-to-close layer
          // never exists at all, which is why touches and visuals were
          // passing straight through to whatever's behind the panel.
          backdropEnabled: true,
          backdropColor: Colors.grey,
          // Tapping the dimmed area closes the panel (this is already the
          // package default, kept explicit here since it's the whole point
          // of enabling the backdrop).
          backdropTapClosesPanel: true,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          panel: _FilterPanel(
            initialRange: _dateRange,
            onApply: _applyDateRange,
            onClose: _panelController.close,
          ),
        ),
      ),
    );
    _filterOverlayEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  @override
  void dispose() {
    _filterOverlayEntry?.remove();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _onMyBookings => _tabController.index == 0;

  /// Inclusive on both ends. No range set means everything matches.
  bool _withinRange(DateTime date) {
    final range = _dateRange;
    if (range == null) return true;
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(range.start) && !day.isAfter(range.end);
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

  void _applyDateRange(DateTimeRange? range) => setState(() {
    _dateRange = range;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(color: AppColors.backgroundDark),
          cursorColor: AppColors.backgroundDark,
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
                ? 'Search your bookings'
                : 'Search service history',
            hintStyle: TextStyle(color: AppColors.grey400, fontSize: 14),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Advanced filter',
            onPressed: _panelController.open,
          ),
        ],
        bottom: TabBar(
          dividerColor: Colors.transparent,
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Bookings'),
            Tab(text: 'History'),
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
        // SlidingUpPanel now lives in the root Overlay (see
        // _insertFilterOverlay) rather than here, so this is back to plain
        // page content — no LayoutBuilder/MediaQuery workaround needed
        // either, since that was only ever fixing SlidingUpPanel's own
        // `body:` sizing, which it no longer has.
        child: TabBarView(
          controller: _tabController,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BlocConsumer<BookingsBloc, BookingsState>(
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
                    BookingsError(:final message) => Center(
                      child: Text(message),
                    ),
                    BookingActionSuccess() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    BookingsLoaded(:final bookings) => _buildBookingsList(
                      context,
                      bookings,
                    ),
                  };
                },
              ),
            ),
            ServicesHistoryView(query: _query, dateRange: _dateRange),
          ],
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

  Widget _buildBookingsList(
    BuildContext context,
    List<BookingEntity> bookings,
  ) {
    if (bookings.isEmpty) return const Center(child: Text('No bookings yet'));

    final filtered = _filterBookings(bookings);
    if (filtered.isEmpty) {
      return const Center(child: Text('No bookings match your search'));
    }

    return RefreshIndicator(
      onRefresh: () async =>
          context.read<BookingsBloc>().add(const BookingsListRequested()),
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final booking = filtered[index];
          return Card(
            // Flat, bordered look instead of the theme's default shadow —
            // elevation: 0 removes the shadow entirely rather than just
            // hiding its color, which would still reserve shadow space.
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[300]!),
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
                                DateFormatter.toFullDateTime(
                                  booking.scheduledAt,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: booking.status),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Text(
                      '${booking.plateNo} · ${booking.unitId}',
                      style: TextStyle(fontSize: 14),
                    ),
                    if (booking.notes != null) ...[
                      const SizedBox(height: 4),
                      Text(booking.notes ?? '', style: TextStyle(fontSize: 12)),
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

/// Content of the sliding advanced-filter panel — a date range for now,
/// per the current scope; more fields (status, workshop) can be added here
/// later without touching how the panel itself is opened/closed.
class _FilterPanel extends StatefulWidget {
  final DateTimeRange? initialRange;
  final ValueChanged<DateTimeRange?> onApply;
  final VoidCallback onClose;

  const _FilterPanel({
    required this.initialRange,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late DateTimeRange? _draft = widget.initialRange;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: _draft,
    );
    if (picked != null) setState(() => _draft = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle — signals this whole area can be dragged, matching
          // the sliding_up_panel convention.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grey400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Advanced Filter',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              _draft == null
                  ? 'Select date range'
                  : '${DateFormatter.toShortDate(_draft!.start)} '
                        '- ${DateFormatter.toShortDate(_draft!.end)}',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _draft = null);
                    widget.onApply(null);
                    widget.onClose();
                  },
                  // app_theme.dart gives ElevatedButton a themed 52-tall
                  // minimumSize but has no matching outlinedButtonTheme, so
                  // OutlinedButton was falling back to Material 3's default
                  // (~40 tall) — explicitly matching Apply's height here.
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_draft);
                    widget.onClose();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Coloured badge showing the booking status string verbatim (the backend
/// sends Bahasa Indonesia text, e.g. "MENUNGGU KONFIRMASI" — not a fixed
/// enum), so only the one confirmed value gets its own colour; anything else
/// stays neutral until more of the vocabulary is confirmed against the
/// backend, rather than guessing translations/other status strings.
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toUpperCase()) {
      'MENUNGGU KONFIRMASI' => AppColors.warning,
      _ => AppColors.grey600,
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
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
