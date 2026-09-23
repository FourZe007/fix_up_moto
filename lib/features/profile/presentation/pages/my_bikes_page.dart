import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

class _MyBikesView extends StatelessWidget {
  const _MyBikesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(title: const Text('Motor Saya')),
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
      itemBuilder: (context, index) => _BikeCard(bike: bikes[index]),
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
  const _BikeCard({required this.bike});

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
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BikePhoto(
                  // NOTE: temporary test URL — a Pexels *page* link
                  // (pexels.com/photo/...) returns an HTML document, not
                  // image bytes, so Image.network can't decode it and falls
                  // through to errorBuilder. This is a direct file URL
                  // (already confirmed to decode correctly) so tap/viewer/
                  // resolution behavior can be checked before real Photo
                  // data exists. Swap back to `bike.photo` when done.
                  photo: 'https://picsum.photos/id/1071/800/600',
                ),
                // _BikePhoto(photo: bike.photo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bike.unitId,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bike.plateNo} - ${bike.color} - ${bike.year}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _SpecRow(label: 'No Chasis', value: bike.chasisNo),
            const SizedBox(height: 6),
            _SpecRow(label: 'No Mesin', value: bike.engineNo),
          ],
        ),
      ),
    );
  }
}

/// Square rounded thumbnail, tappable either way. `BikeModel.photo` has only
/// ever come back empty in the one real response sample seen so far, so
/// tapping with no photo just says so — tapping a real one opens it at full
/// resolution. The thumbnail itself decodes at a reduced resolution
/// (`cacheWidth`/`cacheHeight`) rather than the full image, since a list of
/// many cards doesn't need full-size bitmaps in memory just to show a 64x64
/// preview.
class _BikePhoto extends StatelessWidget {
  final String photo;
  const _BikePhoto({required this.photo});

  bool get _hasPhoto => photo.trim().isNotEmpty;

  void _onTap(BuildContext context) {
    if (!_hasPhoto) {
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
            // No cacheWidth/cacheHeight here — this is the one place the
            // original resolution is deliberately shown in full.
            InteractiveViewer(
              child: Image.network(
                photo,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Gagal memuat foto.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
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
          child: _hasPhoto
              ? Image.network(
                  photo,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  // 2x the display size for device pixel ratio headroom,
                  // still far below whatever the original upload resolution is.
                  cacheWidth: 128,
                  cacheHeight: 128,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.two_wheeler_outlined,
                    color: AppColors.grey600,
                  ),
                )
              : const Icon(
                  Icons.two_wheeler_outlined,
                  color: AppColors.grey600,
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
