import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/profile/presentation/widgets/bike_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Form for changing a registered bike's details, with its plate locked.
///
/// Reached via `context.push(RouteNames.editBike, extra: bike)` from My Bikes'
/// more-actions sheet — a top-level route, so like [AddBikePage] it needs its
/// own [BikesBloc] rather than assuming an ancestor provides one.
///
/// A bike's plate is its only identifier (the backend has no id), so it is
/// shown but cannot be edited, and goes back unchanged as the record's key.
///
/// The fields themselves are [BikeForm], shared with Add Bike.
class EditBikePage extends StatelessWidget {
  final BikeEntity bike;

  const EditBikePage({super.key, required this.bike});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BikesBloc>(),
      child: _EditBikeView(bike: bike),
    );
  }
}

class _EditBikeView extends StatelessWidget {
  final BikeEntity bike;

  const _EditBikeView({required this.bike});

  @override
  Widget build(BuildContext context) {
    // The colour comes from the active Theme rather than an AppColors
    // constant, so this bar follows light/dark automatically. The title and
    // arrow are coloured explicitly because the app's AppBarTheme hard-codes a
    // white title style.
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // The same warm wash as Add Bike and Profile.
    return WarmWash(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Ubah Motor',
            style: TextStyle(color: onSurface, fontSize: 20),
          ),
          // Plain pop, for the same reason as Add Bike's: go() would wipe the
          // navigation stack that My Bikes sits on.
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(foregroundColor: onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        // top: false — the AppBar above already accounts for the status bar.
        body: SafeArea(
          top: false,
          child: BlocConsumer<BikesBloc, BikesState>(
            listener: (context, state) {
              if (state is BikesUpdated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Motor berhasil diperbarui!')),
                );

                // Popping with `true` tells My Bikes a bike really changed, so
                // it reloads its own (separate) BikesBloc — this page's Bloc
                // and that one are different page-scoped instances. No
                // DataRefreshCubit signal: an edit leaves the bike count that
                // Home, Membership and Profile show unchanged.
                context.pop(true);
              } else if (state is BikesError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            builder: (context, state) => BikeForm(
              initial: bike,
              lockPlate: true,
              submitLabel: 'Simpan',
              isLoading: state is BikesLoading,
              onSubmit: (values) => context.read<BikesBloc>().add(
                BikeUpdateRequested(
                  plateNo: values.plateNo,
                  unitId: values.unitId,
                  chasisNo: values.chasisNo,
                  engineNo: values.engineNo,
                  color: values.color,
                  year: values.year,
                  photo: values.photo,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
