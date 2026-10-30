import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/bookings/presentation/models/booking_date_range.dart';

/// The Bookings date filter as the whole content of the route that
/// `_BookingsViewState._openFilter` pushes: a dimmed backdrop over the page and
/// a [SlidingUpPanel] sliding up from the bottom.
///
/// The route is transparent and has no transition of its own; this widget
/// slides the panel in when it appears and pops the route once the panel has
/// slid back out, however it was closed (Terapkan, Reset, the X, a tap on
/// the backdrop, a drag down, or the back button).
///
/// ```text
/// (o)  Filter Tanggal                                  [X]
///      Berlaku untuk My Bookings dan History
///
/// Pilihan cepat
/// [7 hari] [v 1 bulan] [Bulan ini] [3 bulan] [Pilih sendiri]
///
/// Rentang tanggal
/// [ Dari          ]  ->  [ Sampai        ]
/// [ 31 Okt 2026   ]      [ 30 Nov 2026   ]
/// 31 hari · Sab, 31 Okt sampai Sen, 30 Nov
///
/// [   Reset    ]  [      Terapkan      ]
/// ```
class BookingFilterSheet extends StatefulWidget {
  /// The range currently applied — what the panel starts on.
  final DateTimeRange initialRange;

  /// Called with the range to apply, from "Terapkan" or, with the default
  /// range, from "Reset". The panel closes itself right after.
  final ValueChanged<DateTimeRange> onApply;

  const BookingFilterSheet({
    super.key,
    required this.initialRange,
    required this.onApply,
  });

  @override
  State<BookingFilterSheet> createState() => _BookingFilterSheetState();
}

class _BookingFilterSheetState extends State<BookingFilterSheet> {
  final _controller = PanelController();

  /// Whether the panel has left position 0 since it was opened. The package
  /// reports "closed" on the first tick of the opening animation too (the
  /// value is still 0 then), and that must not pop the route.
  bool _seenOpen = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    // The controller is only attached once the panel has been built, and
    // opening after that frame is what makes it slide in rather than appear.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.open();
    });
  }

  void _onSlide(double position) {
    if (position > 0) _seenOpen = true;
  }

  void _onClosed() {
    if (!_seenOpen || _popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  /// Tall enough for the header, two rows of shortcuts, the two date cards and
  /// the buttons; grows with the text size and the gesture bar, never past
  /// most of the screen. The panel scrolls if its content is still taller.
  double _panelHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = 480 * media.textScaler.scale(1) + media.viewPadding.bottom;
    return height.clamp(0.0, media.size.height * 0.9).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // Back slides the panel down instead of leaving the page; the route is
    // popped by _onClosed when it has. (A direct Navigator.pop ignores this.)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.close();
      },
      child: SlidingUpPanel(
        controller: _controller,
        minHeight: 0,
        maxHeight: _panelHeight(context),
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
        // The package's default panel colour is Colors.white — the same
        // value as surfaceLight, so light mode is unchanged — but fixed, so
        // it has to be read from the theme to turn light grey in dark mode.
        color: Theme.of(context).colorScheme.surface,
        onPanelSlide: _onSlide,
        onPanelClosed: _onClosed,
        panel: LightSurfaceScope(
          child: _FilterPanel(
            initialRange: widget.initialRange,
            onApply: widget.onApply,
            onClose: _controller.close,
          ),
        ),
      ),
    );
  }
}

/// What is inside the panel. The member edits a draft range here; nothing
/// reaches the page until "Terapkan".
class _FilterPanel extends StatefulWidget {
  final DateTimeRange initialRange;
  final ValueChanged<DateTimeRange> onApply;
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
  late DateTimeRange _draft = widget.initialRange;

  /// The full range picker, which both "Pilih sendiri" and the two date cards
  /// open. It is a route on the root navigator, so it lands above the panel's
  /// own route.
  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateUtils.addDaysToDate(today, -365),
      lastDate: DateUtils.addDaysToDate(today, 365),
      initialDateRange: _draft,
      helpText: 'Pilih rentang tanggal',
      cancelText: 'Batal',
      confirmText: 'Simpan',
      saveText: 'Simpan',
    );
    if (picked != null && mounted) setState(() => _draft = picked);
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.grey700,
        ),
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      // A tick as well as the colour, so the choice does not rest on colour.
      showCheckmark: true,
      checkmarkColor: AppColors.primaryDark,
      backgroundColor: AppColors.peachMist,
      selectedColor: AppColors.peachLight,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.peachHairline,
        width: selected ? 1.5 : 1,
      ),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? AppColors.primaryDark : AppColors.textPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final selected = BookingRangePreset.matching(_draft, now);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // A transparent Material between the panel's coloured box and the chips
    // and cards: they paint their ink on the nearest Material, and without
    // one here Flutter refuses (in debug) because the box's colour would hide
    // the ripple.
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        // Scrolls only when the content is taller than the panel (a very large
        // text size); otherwise it takes no drag, so the panel can be dragged.
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle — signals the whole panel can be dragged.
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

            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.peachLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.date_range_outlined,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter Tanggal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Berlaku untuk My Bookings dan History',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('bookings-filter-close'),
                  tooltip: 'Tutup',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  color: AppColors.grey700,
                ),
              ],
            ),

            // ── Shortcuts ───────────────────────────────────────────────────
            _label('Pilihan cepat'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in BookingRangePreset.values)
                  _chip(
                    key: Key('bookings-preset-${preset.name}'),
                    label: preset.label,
                    selected: preset == selected,
                    onTap: () => setState(() => _draft = preset.rangeOn(now)),
                  ),
                _chip(
                  key: const Key('bookings-preset-custom'),
                  label: 'Pilih sendiri',
                  selected: selected == null,
                  onTap: _pickRange,
                ),
              ],
            ),

            // ── The range itself ────────────────────────────────────────────
            _label('Rentang tanggal'),
            Row(
              children: [
                Expanded(
                  child: _DateCard(
                    key: const Key('bookings-filter-from'),
                    label: 'Dari',
                    date: _draft.start,
                    onTap: _pickRange,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: AppColors.grey700,
                  ),
                ),
                Expanded(
                  child: _DateCard(
                    key: const Key('bookings-filter-to'),
                    label: 'Sampai',
                    date: _draft.end,
                    onTap: _pickRange,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _draft.summary,
                key: const Key('bookings-filter-summary'),
                style: const TextStyle(fontSize: 13, color: AppColors.grey700),
              ),
            ),

            // ── Actions ─────────────────────────────────────────────────────
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: OutlinedButton(
                    key: const Key('bookings-filter-reset'),
                    onPressed: () {
                      widget.onApply(BookingRangePreset.defaultRange(now));
                      widget.onClose();
                    },
                    // The app theme gives ElevatedButton a tall minimumSize and
                    // OutlinedButton none: match the two.
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(
                        color: AppColors.primaryDark,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 7,
                  child: ElevatedButton(
                    key: const Key('bookings-filter-apply'),
                    onPressed: () {
                      widget.onApply(_draft);
                      widget.onClose();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One end of the range as a tappable card: "Dari" or "Sampai" over the date.
/// Either one opens the same range picker.
class _DateCard extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateCard({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.peachMist,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.peachHairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateTimeFormatter.toShortDateId(date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
