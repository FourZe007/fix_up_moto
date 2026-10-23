import 'dart:convert';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/confirm_panel_scope.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/core/widgets/warm_section.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';

/// Lists the member's registered bikes — reached from Home's "Motor Saya"
/// button. A dedicated top-level page (not the Profile tab's own placeholder
/// section) with its own [BikesBloc], the same page-scoped pattern every
/// other tab/page uses.
class MyBikesPage extends StatelessWidget {
  const MyBikesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BikesBloc>()..add(const BikesLoadRequested()),
      // Hosts the delete confirmation: it slides up in the root Overlay, like
      // Profile's sign-out and delete panels.
      child: const ConfirmPanelScope(child: _MyBikesView()),
    );
  }
}

class _MyBikesView extends StatefulWidget {
  const _MyBikesView();

  @override
  State<_MyBikesView> createState() => _MyBikesViewState();
}

class _MyBikesViewState extends State<_MyBikesView> {
  final _actionsPanelController = PanelController();
  BikeEntity? _selectedBike;

  // Mounted into the app's root Overlay, same reasoning as Bookings'
  // advanced-filter panel (see BookingsPage._insertFilterOverlay): MainShell's
  // bottom NavigationBar always paints above this page's own body in z-order,
  // so a panel living inside this Scaffold could only ever slide up
  // underneath it, never cover it.
  OverlayEntry? _actionsOverlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _insertActionsOverlay(),
    );
  }

  void _insertActionsOverlay() {
    if (!mounted) return;
    // Looked up here, from the page's own context: the entry below lives in
    // the root Overlay, outside this subtree, so it could not find the scope
    // itself.
    final confirmPanel = ConfirmPanelScope.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: SlidingUpPanel(
          controller: _actionsPanelController,
          minHeight: 0,
          // Sized to exactly fit _BikeActionsPanel's content so the panel
          // doesn't leave dead space below the rows when open: 32
          // (Padding.fromLTRB(20,12,20,20)'s vertical 12+20) + 20 (the drag
          // handle's 4 height + 16 bottom margin) + 105 (two 52 px ActionRows
          // and the 1 px hairline between them).
          maxHeight: 160,
          // Defaults to false — without it there's no dim/tap-to-close layer
          // at all, same gotcha as Bookings' filter panel.
          backdropEnabled: true,
          backdropColor: Colors.grey,
          backdropTapClosesPanel: true,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          // The package default is Colors.white (== surfaceLight, so light
          // mode is unchanged); read from the theme so it is light grey in
          // dark mode.
          color: Theme.of(context).colorScheme.surface,
          panel: _selectedBike == null
              ? const SizedBox.shrink()
              : LightSurfaceScope(
                  child: _BikeActionsPanel(
                    bike: _selectedBike!,
                    confirmPanel: confirmPanel,
                    onEdit: () {
                      debugPrint(
                        'Edit button pressed for ${_selectedBike!.unitId}',
                      );
                      _actionsPanelController.close();
                    },
                    onClosePanel: _actionsPanelController.close,
                    onDelete: () {
                      debugPrint(
                        'Delete button pressed for ${_selectedBike!.unitId}',
                      );
                    },
                  ),
                ),
        ),
      ),
    );
    _actionsOverlayEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  // The panel is a single shared instance (see _insertActionsOverlay) whose
  // content depends on which card's "more" button was pressed — the overlay
  // entry lives outside this widget's own subtree, so setState alone won't
  // rebuild it; markNeedsBuild() does that explicitly before opening.
  void _openActionsFor(BikeEntity bike) {
    _selectedBike = bike;
    _actionsOverlayEntry?.markNeedsBuild();
    _actionsPanelController.open();
  }

  // AddBikePage owns its own (separate, page-scoped) BikesBloc instance, so
  // popping back here doesn't itself refresh this page's list — awaiting
  // the push and checking its result (AddBikePage pops with `true` only on
  // a real successful add) tells us when to actually re-fetch.
  Future<void> _openAddBike(BuildContext context) async {
    final added = await context.push<bool>(RouteNames.addBike);
    if (added == true && context.mounted) {
      context.read<BikesBloc>().add(const BikesLoadRequested());
    }
  }

  @override
  void dispose() {
    _actionsOverlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The colour comes from the active Theme rather than an AppColors
    // constant, so this bar follows light/dark automatically. The title and
    // arrow are coloured explicitly because the app's AppBarTheme hard-codes a
    // white title style.
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // The same warm wash as Profile: a fixed backdrop *around* the Scaffold,
    // whose own background and AppBar are transparent, so it shows behind the
    // bar and the cards scroll over it.
    return WarmWash(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Motor Saya',
            style: TextStyle(color: onSurface, fontSize: 20),
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(foregroundColor: onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        // top: false — the AppBar already accounts for the status bar; this
        // guards the FAB/last card from the gesture nav bar, since this page
        // has no bottomNavigationBar to reserve that space.
        body: SafeArea(
          top: false,
          child: BlocConsumer<BikesBloc, BikesState>(
            listener: (context, state) {
              if (state is BikesError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            builder: (context, state) {
              return switch (state) {
                BikesInitial() || BikesLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                // Loading again after Add pops back in — same spinner, not a
                // separate case, since a fresh list is already on the way.
                BikesAdded() => const Center(
                  child: CircularProgressIndicator(),
                ),
                BikesError(:final message) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 12,
                      children: [
                        Text(message, textAlign: TextAlign.center),
                        ElevatedButton(
                          onPressed: () => context.read<BikesBloc>().add(
                            const BikesLoadRequested(),
                          ),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
                BikesLoaded(:final bikes) => _buildList(bikes),
              };
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddBike(context),
          tooltip: 'Tambah motor',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildList(List<BikeEntity> bikes) {
    if (bikes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              const Icon(
                Icons.two_wheeler_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              Text(
                'Belum ada motor',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              ElevatedButton(
                onPressed: () => _openAddBike(context),
                child: const Text('Tambah Motor'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      // Room at the foot for the FAB, so it never covers the last card's
      // more-actions button.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: bikes.length,
      itemBuilder: (context, index) => _BikeCard(
        bike: bikes[index],
        onMorePressed: () => _openActionsFor(bikes[index]),
      ),
    );
  }
}

/// One bike: a photo thumbnail alongside the unit/plate/color/year header, and
/// the chassis and engine numbers as a labeled spec section beneath it.
///
/// Drawn like Profile's [SectionCard]: a flat, rounded surface with a warm
/// hairline instead of a shadow, white (light grey in dark mode, via
/// [LightSurfaceScope]).
class _BikeCard extends StatelessWidget {
  final BikeEntity bike;
  final VoidCallback onMorePressed;
  const _BikeCard({required this.bike, required this.onMorePressed});

  @override
  Widget build(BuildContext context) {
    // The scope wraps the card, not the page: the empty and error messages sit
    // on the wash in the page's own theme, and only what is drawn on a pale
    // surface needs the light theme's dark text in dark mode. The Builder is
    // what lets the content read the theme the scope sets up.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LightSurfaceScope(
        child: Builder(
          builder: (context) => Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.peachHairline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_headerRow(context), ..._specSection],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Photo thumbnail alongside the unit id and plate/color/year subtitle.
  Widget _headerRow(BuildContext context) {
    return Row(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bike Photo
        // _BikePhoto(
        //   // NOTE: temporary test URL — a Pexels *page* link
        //   // (pexels.com/photo/...) returns an HTML document, not
        //   // image bytes, so Image.network can't decode it and falls
        //   // through to errorBuilder. This is a direct file URL
        //   // (already confirmed to decode correctly) so tap/viewer/
        //   // resolution behavior can be checked before real Photo
        //   // data exists. Swap back to `bike.photo` when done.
        //   photo: 'https://picsum.photos/id/1071/800/600',
        // ),
        _BikePhoto(photo: bike.photo),

        // Bike name, license plate, color, and year of production
        Expanded(
          child: Column(
            spacing: 4,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bike.unitId,
                // The same weight and size as an ActionRow's label on Profile.
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              Text(
                _plateSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.grey700),
              ),
            ],
          ),
        ),

        // More Actions — opens _CardActions in the shared SlidingUpPanel
        // (see _MyBikesViewState) rather than showing edit/delete inline.
        _ActionButton(
          icon: Icons.more_vert,
          tooltip: 'Aksi lainnya',
          onPressed: onMorePressed,
        ),
      ],
    );
  }

  /// Plate number is the only mandatory field in this line; color and year
  /// are appended only when the data actually has them, same
  /// hide-when-missing approach as [_specSection] below.
  String get _plateSummary {
    final hasColor = bike.color.trim().isNotEmpty;
    final hasYear = bike.year.trim().isNotEmpty;

    return switch ((hasColor, hasYear)) {
      (false, false) => bike.plateNo,
      (true, false) => '${bike.plateNo} - ${bike.color}',
      (false, true) => '${bike.plateNo} - ${bike.year}',
      (true, true) => '${bike.plateNo} - ${bike.color} - ${bike.year}',
    };
  }

  /// Chassis/engine rows, each hidden individually when its own value is
  /// missing; the divider above them is hidden too when both are, so no
  /// empty section (or a bare divider leading nowhere) is ever shown.
  List<Widget> get _specSection {
    final hasChasis = bike.chasisNo.trim().isNotEmpty;
    final hasEngine = bike.engineNo.trim().isNotEmpty;

    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: AppColors.peachHairline),
    );

    return switch ((hasChasis, hasEngine)) {
      (false, false) => const [],
      (true, false) => [
        divider,
        _SpecRow(label: 'No Chasis', value: bike.chasisNo),
      ],
      (false, true) => [
        divider,
        _SpecRow(label: 'No Mesin', value: bike.engineNo),
      ],
      (true, true) => [
        divider,
        _SpecRow(label: 'No Chasis', value: bike.chasisNo),
        const SizedBox(height: 6),
        _SpecRow(label: 'No Mesin', value: bike.engineNo),
      ],
    };
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      iconSize: 20,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }
}

/// Content of the shared "more actions" SlidingUpPanel (see
/// _MyBikesViewState) — a drag handle over an Edit and a Hapus row, drawn like
/// Profile's rows. `bike` isn't displayed here; it's only needed to name the
/// bike in [_confirmDelete]'s panel.
class _BikeActionsPanel extends StatelessWidget {
  final BikeEntity bike;

  /// Asks before deleting. Passed in, not looked up: this widget is built in
  /// the root Overlay, where [ConfirmPanelScope.of] cannot find the page's
  /// scope.
  final ConfirmPanel confirmPanel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onClosePanel;

  const _BikeActionsPanel({
    required this.bike,
    required this.confirmPanel,
    required this.onEdit,
    required this.onDelete,
    required this.onClosePanel,
  });

  /// This panel and the confirmation panel both render through the app's root
  /// Overlay, and the two don't coordinate z-order with each other — opening
  /// the confirmation while this panel is still open can leave it behind this
  /// one. Closing this panel first avoids the question entirely, and declining
  /// then just leaves the user back on the plain bike list (this panel's
  /// already closed by then).
  Future<void> _confirmDelete(BuildContext context) async {
    await onClosePanel();
    if (!context.mounted) return;
    final confirmed = await confirmPanel.confirm(
      icon: Icons.delete,
      title: 'Hapus Motor',
      message:
          'Yakin ingin menghapus "${bike.unitId}"? Tindakan ini tidak dapat '
          'dibatalkan.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (confirmed) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
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
          // A SectionCard, not bare rows: it is the Material the rows' ripples
          // need, which this root-Overlay panel does not otherwise have.
          SectionCard(
            children: [
              ActionRow(
                key: const Key('bike-edit'),
                name: 'Edit',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: onEdit,
              ),
              ActionRow(
                key: const Key('bike-delete'),
                name: 'Hapus',
                destructive: true,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Square rounded thumbnail, tappable either way. `BikeModel.photo` has only
/// ever come back empty in the one real response sample seen so far, so
/// which format a real value would use — a URL vs. base64 — isn't confirmed
/// yet; [_imageProvider] supports both rather than guessing wrong. Tapping
/// with no photo just says so — tapping a real one opens it at full
/// resolution. The thumbnail itself decodes at a reduced resolution
/// (via [ResizeImage]) rather than the full image, since a list of many
/// cards doesn't need full-size bitmaps in memory just to show a 64x64
/// preview.
class _BikePhoto extends StatelessWidget {
  final String photo;
  const _BikePhoto({required this.photo});

  bool get _isUrl =>
      photo.startsWith('http://') || photo.startsWith('https://');

  /// Null means either there's no photo, or the string wasn't a URL and
  /// wasn't valid base64 either — both are treated as "no photo" by callers.
  /// A base64 value may arrive bare or as a `data:image/...;base64,` data
  /// URI, so the scheme prefix (if any) is stripped before decoding.
  ImageProvider? get _imageProvider {
    final trimmed = photo.trim();
    if (trimmed.isEmpty) return null;
    if (_isUrl) return NetworkImage(trimmed);
    final raw = trimmed.contains(',')
        ? trimmed.substring(trimmed.indexOf(',') + 1)
        : trimmed;
    try {
      return MemoryImage(base64Decode(raw));
    } on FormatException {
      return null;
    }
  }

  void _onTap(BuildContext context) {
    final provider = _imageProvider;
    if (provider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto tidak tersedia untuk motor ini.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // provider as-is, no ResizeImage wrapper — this is the one place
            // the original resolution is deliberately shown in full.
            InteractiveViewer(
              child: Image(
                image: provider,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Gagal memuat foto.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              // child: Image(
              //   image: provider,
              //   errorBuilder: (_, _, _) => const Padding(
              //     padding: EdgeInsets.all(32),
              //     child: Text(
              //       'Gagal memuat foto.',
              //       style: TextStyle(color: Colors.white),
              //     ),
              //   ),
              // ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onTap(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 64,
          height: 64,
          color: AppColors.peachMist,
          alignment: Alignment.center,
          child: provider == null
              ? const Icon(Icons.two_wheeler_outlined, color: AppColors.primary)
              : Image(
                  // 2x the display size for device pixel ratio headroom,
                  // still far below whatever the original resolution is —
                  // works the same whether provider is network- or
                  // memory-backed.
                  image: ResizeImage(provider, width: 128, height: 128),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.two_wheeler_outlined,
                    color: AppColors.primary,
                  ),
                ),
        ),
      ),
    );
  }
}

/// One row of the chassis/engine spec section — label on the left, value
/// right-aligned, matching the hand-drawn layout exactly.
class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.grey700),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
