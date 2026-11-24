import 'dart:async';

import 'package:fix_up_moto/core/helpers/haptics.dart';
import 'package:fix_up_moto/core/tour/field_guide_help_button.dart';
import 'package:fix_up_moto/core/widgets/confirm_panel_scope.dart';
import 'package:fix_up_moto/features/bookings/presentation/guided_booking.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/profile/presentation/widgets/bike_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  /// True when the member was sent here to register their first bike (the Home
  /// card, the app tour's hand-off; see [FirstTaskStep.addBike]). Once the bike
  /// is saved, the confirmation then asks "Buat booking sekarang?" and starts
  /// the booking if they say yes. False (the default) is the plain confirmation,
  /// as for every other way of getting here.
  final bool offerBooking;

  /// Switches on the field guide: a help button in the app bar that walks the
  /// member through each text field, remembering on the phone that it has been
  /// seen (see `BikeForm`). Null (the default) leaves the page exactly as it was.
  final SharedPreferences? guidePrefs;

  /// Whether the guide also plays by itself, once, the first time the page
  /// opens on a phone that has not seen it. The router sets it for a member who
  /// has no bike yet; a member adding another bike knows the form and only has
  /// the help button. Ignored without [guidePrefs].
  final bool autoGuide;

  const AddBikePage({
    super.key,
    this.offerBooking = false,
    this.guidePrefs,
    this.autoGuide = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BikesBloc>(),
      child: _AddBikeView(
        offerBooking: offerBooking,
        guidePrefs: guidePrefs,
        autoGuide: autoGuide,
      ),
    );
  }
}

class _AddBikeView extends StatefulWidget {
  final bool offerBooking;
  final SharedPreferences? guidePrefs;
  final bool autoGuide;

  const _AddBikeView({
    required this.offerBooking,
    required this.guidePrefs,
    required this.autoGuide,
  });

  @override
  State<_AddBikeView> createState() => _AddBikeViewState();
}

class _AddBikeViewState extends State<_AddBikeView> {
  /// Reaches the form, so the help button can play its guide.
  final _formKey = GlobalKey<BikeFormState>();

  /// True while the guide plays. The help button steps aside for it: the guide's
  /// "Lewati" sits in the same corner of the screen and would land on top of it.
  final _guideActive = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _guideActive.dispose();
    super.dispose();
  }

  bool get offerBooking => widget.offerBooking;

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
            actions: [
              // Plays the field guide again, any time: the automatic one only
              // happens once.
              if (widget.guidePrefs != null)
                FieldGuideHelpButton(
                  buttonKey: const Key('add-bike-guide-button'),
                  active: _guideActive,
                  color: onSurface,
                  onPressed: () => _formKey.currentState?.playGuide(),
                ),
            ],
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
                  Haptics.success();

                  final messenger = ScaffoldMessenger.of(context);
                  if (offerBooking) {
                    // Taken now, while this context is active: the button below
                    // runs after the pop, when this page is gone.
                    final router = GoRouter.of(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Motor tersimpan. Buat booking sekarang?',
                        ),
                        // A snack bar with a button stays until it is dismissed;
                        // this is an offer, not a notice, so it goes by itself.
                        persist: false,
                        duration: const Duration(seconds: 10),
                        action: SnackBarAction(
                          label: 'Buat Booking',
                          onPressed: () =>
                              unawaited(startGuidedBooking(router: router)),
                        ),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Motor berhasil ditambah!')),
                    );
                  }

                  // A new bike can change the member's stats (Home, Membership
                  // and Profile are alive in the tab stack), so tell them to
                  // reload. Read before the pop, while this context is active.
                  // The bikes signal goes first: Bookings' Riwayat reloads its
                  // plate list on it.
                  context.read<DataRefreshCubit>()
                    ..invalidate(DataKind.bikes)
                    ..invalidate(DataKind.stats);

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
                key: _formKey,
                guidePrefs: widget.guidePrefs,
                autoGuide: widget.autoGuide,
                guideActive: _guideActive,
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
