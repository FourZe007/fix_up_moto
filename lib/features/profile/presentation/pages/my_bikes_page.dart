import 'dart:convert';

import 'package:fix_up_moto/core/theme/app_colors.dart';
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
      create: (_) =>
          sl<BikesBloc>()..add(const BikesLoadRequested(memberId: '')),
      child: const _MyBikesView(),
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
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: SlidingUpPanel(
          controller: _actionsPanelController,
          minHeight: 0,
          // Sized to exactly fit _BikeActionsPanel's content so the panel
          // doesn't leave dead space below the buttons when open: 32
          // (Padding.fromLTRB(20,12,20,20)'s vertical 12+20) + 20 (the drag
          // handle's 4 height + 16 bottom margin) + 88 (two default Material
          // 3 TextButtons at 40 each, +8 Column spacing between them — this
          // theme's textButtonTheme doesn't override minimumSize, so the M3
          // default height applies).
          maxHeight: 160,
          // Defaults to false — without it there's no dim/tap-to-close layer
          // at all, same gotcha as Bookings' filter panel.
          backdropEnabled: true,
          backdropColor: Colors.grey,
          backdropTapClosesPanel: true,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          panel: _selectedBike == null
              ? const SizedBox.shrink()
              : _BikeActionsPanel(
                  bike: _selectedBike!,
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

  @override
  void dispose() {
    _actionsOverlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Motor Saya'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          // Top-only — the bottom already meets the screen edge, so rounding
          // it wouldn't be visible against anything.
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // top: false — the AppBar already accounts for the status bar; this
        // guards the FAB/last card from the gesture nav bar, since this page
        // has no bottomNavigationBar to reserve that space.
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: BlocConsumer<BikesBloc, BikesState>(
              listener: (context, state) {
                if (state is BikesError) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              builder: (context, state) {
                return switch (state) {
                  BikesInitial() || BikesLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  // Loading again after Add pops back in — same spinner, not a
                  // separate case, since a fresh list is already on the way.
                  BikeActionSuccess() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  BikesError() => Center(
                    child: TextButton(
                      onPressed: () => context.read<BikesBloc>().add(
                        const BikesLoadRequested(memberId: ''),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                  BikesLoaded(:final bikes) => _buildList(bikes),
                };
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.addBike),
        tooltip: 'Add a bike',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List<BikeEntity> bikes) {
    if (bikes.isEmpty) {
      return const Center(child: Text('No bikes added yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      itemCount: bikes.length,
      itemBuilder: (context, index) => _BikeCard(
        bike: bikes[index],
        onMorePressed: () => _openActionsFor(bikes[index]),
      ),
    );
  }
}

/// Same flat, bordered card language as the Bookings/History cards —
/// elevation: 0 + a black border instead of a shadow — with a photo
/// thumbnail alongside the unit/plate/color/year header, and the chassis
/// and engine numbers as a labeled spec section beneath it, per the
/// hand-drawn layout this was built from.
class _BikeCard extends StatelessWidget {
  final BikeEntity bike;
  final VoidCallback onMorePressed;
  const _BikeCard({required this.bike, required this.onMorePressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_headerRow(context), ..._specSection],
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              Text(
                '${bike.plateNo} - ${bike.color} - ${bike.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // More Actions — opens _CardActions in the shared SlidingUpPanel
        // (see _MyBikesViewState) rather than showing edit/delete inline.
        _ActionButton(
          icon: Icons.more_vert,
          tooltip: 'More actions',
          onPressed: onMorePressed,
        ),
      ],
    );
  }

  /// Chassis/engine rows, each hidden individually when its own value is
  /// missing; the divider above them is hidden too when both are, so no
  /// empty section (or a bare divider leading nowhere) is ever shown.
  List<Widget> get _specSection {
    final hasChasis = bike.chasisNo.trim().isNotEmpty;
    final hasEngine = bike.engineNo.trim().isNotEmpty;
    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1),
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

/// Edit/delete actions shown in the "more actions" panel — plain text-and-
/// icon rows stacked vertically, no button chrome, just the tap behavior.
class _CardActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CardActions({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            alignment: Alignment.centerLeft,
            minimumSize: Size(MediaQuery.of(context).size.width, 0),
          ),
        ),
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Hapus'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            alignment: Alignment.centerLeft,
            minimumSize: Size(MediaQuery.of(context).size.width, 0),
          ),
        ),
      ],
    );
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
/// _MyBikesViewState) — a drag handle over the same [_CardActions] edit/
/// delete pair the header row used to show inline. `bike` isn't displayed
/// here; it's only needed to name the bike in [_confirmDelete]'s dialog.
class _BikeActionsPanel extends StatelessWidget {
  final BikeEntity bike;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onClosePanel;

  const _BikeActionsPanel({
    required this.bike,
    required this.onEdit,
    required this.onDelete,
    required this.onClosePanel,
  });

  /// The panel and the confirm dialog both ultimately render through the
  /// app's root Overlay (the panel via a manually-managed OverlayEntry, the
  /// dialog via Navigator's own route), and the two don't coordinate z-order
  /// with each other — showing the dialog while the panel is still open can
  /// render it behind the panel instead of above it. Closing the panel first
  /// avoids the question entirely: same confirm-before-destructive shape as
  /// BookingsPage._confirmCancel, but declining now just leaves the user back
  /// on the plain bike list (the panel's already closed by then), rather than
  /// leaving the panel open the way it used to.
  Future<void> _confirmDelete(BuildContext context) async {
    await onClosePanel();
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Bike'),
        content: Text('Are you sure you want to delete "${bike.unitId}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
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
          _CardActions(onEdit: onEdit, onDelete: () => _confirmDelete(context)),
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
          color: AppColors.grey200,
          alignment: Alignment.center,
          child: provider == null
              ? const Icon(Icons.two_wheeler_outlined, color: AppColors.grey600)
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
                    color: AppColors.grey600,
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
        Text(label, style: Theme.of(context).textTheme.bodySmall),
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
