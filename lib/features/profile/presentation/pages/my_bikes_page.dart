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
      create: (_) => sl<BikesBloc>()..add(const BikesLoadRequested(memberId: '')),
      child: const _MyBikesView(),
    );
  }
}

class _MyBikesView extends StatelessWidget {
  const _MyBikesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Motor Saya')),
      // top: false — the AppBar already accounts for the status bar; this
      // guards the FAB/last card from the gesture nav bar, since this page
      // has no bottomNavigationBar to reserve that space.
      body: SafeArea(
        top: false,
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
      padding: const EdgeInsets.all(16),
      itemCount: bikes.length,
      itemBuilder: (context, index) => _BikeCard(bike: bikes[index]),
    );
  }
}

/// Same flat, bordered card language as the Bookings/History cards —
/// elevation: 0 + a black border instead of a shadow, the unit as the bold
/// title, plate number and year as a subtitle line beneath it.
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bike.unitId,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${bike.plateNo} · ${bike.color} · ${bike.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
