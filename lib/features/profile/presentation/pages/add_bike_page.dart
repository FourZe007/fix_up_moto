import 'package:fix_up_moto/core/widgets/confirm_panel_scope.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/profile/presentation/widgets/bike_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';

/// Form for registering a new bike to the user's profile.
///
/// Reached via `context.push(RouteNames.addBike)` — a top-level route, so
/// (like CreateBookingPage before it) this needs its own [BikesBloc] rather
/// than assuming an ancestor provides one, which a pushed page can never see.
///
/// The fields themselves are [BikeForm], shared with Edit Bike.
class AddBikePage extends StatelessWidget {
  const AddBikePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BikesBloc>(),
      child: const _AddBikeView(),
    );
  }
}

class _AddBikeView extends StatelessWidget {
  const _AddBikeView();

  @override
  Widget build(BuildContext context) {
    // The colour comes from the active Theme rather than an AppColors
    // constant, so this bar follows light/dark automatically. The title and
    // arrow are coloured explicitly because the app's AppBarTheme hard-codes a
    // white title style.
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // The same warm wash as Profile: a fixed backdrop *around* the Scaffold,
    // whose own background and AppBar are transparent, so it shows behind the
    // bar and the form scrolls over it.
    //
    // The scope hosts the panel that asks before the photo is removed; it
    // slides up in the root Overlay, above this Scaffold.
    return ConfirmPanelScope(
      child: WarmWash(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'Tambah Motor',
              style: TextStyle(color: onSurface, fontSize: 20),
            ),
            // Plain pop, not go(RouteNames.myBikes) — this route is pushed from
            // two different places (MyBikesPage's FAB and ProfilePage's own "+"
            // shortcut), and go() unconditionally to one of them would both
            // land the wrong caller on the wrong page and wipe out the rest of
            // the navigation stack (go() replaces the whole stack with just the
            // target route, since these are top-level routes outside any
            // ShellRoute — that's what was making the AppBar's own back button
            // disappear from MyBikesPage afterwards).
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(foregroundColor: onSurface),
              onPressed: () => context.pop(),
            ),
          ),
          // top: false — the AppBar above already accounts for the status bar;
          // this guards "Tambah Motor" at the form's end from the gesture nav
          // bar, since this page has no bottomNavigationBar to reserve that
          // space.
          body: SafeArea(
            top: false,
            child: BlocListener<BikesBloc, BikesState>(
              listener: (context, state) {
                if (state is BikesAdded) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Motor berhasil ditambah!')),
                  );

                  // A new bike can change the member's stats (Home, Membership
                  // and Profile are alive in the tab stack), so tell them to
                  // reload. Read before the pop, while this context is active.
                  context.read<DataRefreshCubit>().invalidate(DataKind.stats);

                  // Popping with `true` lets whichever caller pushed this
                  // route (MyBikesPage's FAB) know a bike was actually added,
                  // so it can refresh its own (separate) BikesBloc instance —
                  // this page's Bloc and the caller's are different
                  // page-scoped instances, so a plain pop alone wouldn't
                  // surface the new bike there.
                  context.pop(true);
                } else if (state is BikesError) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              child: BikeForm(
                submitLabel: 'Tambah Motor',
                onSubmit: (values) => context.read<BikesBloc>().add(
                  BikeAddRequested(
                    plateNumber: values.plateNo,
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
      ),
    );
  }
}
