import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:fix_up_moto/core/tour/app_tour.dart';
import 'package:fix_up_moto/core/tour/app_tour_audience.dart';
import 'package:fix_up_moto/core/tour/app_tour_handoff.dart';
import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/tour/app_tour_steps.dart';
import 'package:fix_up_moto/features/bookings/presentation/guided_booking.dart';

/// What a page below an [AppTourHost] can ask of it: play the tour now.
///
/// Profile's "Panduan Aplikasi" row uses it. A page built without a host above
/// it (a test, a preview) gets null from [maybeOf] and simply leaves its button
/// out, so nothing needs the tour to exist.
class AppTourScope extends InheritedWidget {
  /// Plays the tour; false if it could not (one is already playing, or the bar
  /// is not on screen).
  final bool Function() start;

  const AppTourScope({super.key, required this.start, required super.child});

  /// Looks the scope up without subscribing: [start] never changes, so a page
  /// has no reason to rebuild for it.
  static AppTourScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppTourScope>();

  @override
  bool updateShouldNotify(AppTourScope oldWidget) => false;
}

/// Owns the tour for the main shell: hands the bottom bar the keys the tour
/// lights up, plays the tour once by itself for a member who has not seen it,
/// and plays it again on request (through [AppTourScope]).
///
/// [builder] draws the shell and receives the tab keys, which go to
/// `AppTabBar.tabKeys`. Everything else about the shell is untouched.
///
/// **Playing by itself** happens only when [prefs] is given and does not say the
/// tour was seen (see [AppTourSeen]); with no [prefs] it never starts on its own.
/// It does not start the moment the shell appears. Something else may be asking
/// the member a question first (the notification explainer is a dialog on this
/// same navigator), and the tour's overlay would cover it. So it waits until the
/// shell has been the screen on top, with the app in the foreground and the bar
/// laid out, for [calmChecksNeeded] checks in a row, [checkEvery] apart. A dialog
/// or a pushed page, or the phone's own permission prompt, restarts that count.
///
/// **Only for new members:** given [bikeCount], the host will not start on its
/// own until it knows the member's bike count, and then only for a new member
/// (see [AppTourAudience]): one with no bike, or one with a bike who is still to
/// make their first booking ([bookingPending]). Anyone else is not new: the tour
/// is marked seen for them, so it never plays by itself, not even if they later
/// delete their last bike. Until the count is known (the stats are still
/// loading, or failed) it simply waits, and never guesses. Without [bikeCount]
/// the audience is not checked at all.
///
/// In a debug build it prints one line to the console each time the reason it is
/// not starting yet changes (`[app tour] ...`), so a tour that never appears can
/// be explained.
///
/// The tour is marked seen when it ends, by finishing or by "Lewati". Closing
/// the app halfway therefore shows it again next time.
///
/// **Handing the member on:** [handoff] is asked each time the tour starts, and
/// may answer with something to offer on the last step (see [AppTourHandoff]).
/// If the member accepts, the tour closes and the host pushes its route, so back
/// returns to where they were. Asking at the start, not earlier, lets it use
/// whatever is known by then (whether the member has a bike yet).
class AppTourHost extends StatefulWidget {
  /// Where "seen" is kept; null turns the automatic start off.
  final SharedPreferences? prefs;

  /// What the last step offers, if anything; null (the default) means the plain
  /// "Selesai" ending, as does a closure that answers null.
  final AppTourHandoff? Function()? handoff;

  /// How many bikes the member has right now, or null while that is not known
  /// yet. Asked at every check, so it can start out unknown and settle. Null
  /// (the default) turns the audience check off: the tour then plays by itself
  /// for any member who has not seen it.
  final int? Function()? bikeCount;

  /// Whether the phone remembers the member as still to make their first
  /// booking, asked at every check along with [bikeCount]. It is what lets a
  /// member who already has a bike be new to the tour. Null (the default) means
  /// "no", so only the bike count decides.
  final bool Function()? bookingPending;

  /// Builds the shell, given one key per tab in `MainTabs` order.
  final Widget Function(BuildContext context, List<GlobalKey> tabKeys) builder;

  const AppTourHost({
    super.key,
    this.prefs,
    this.handoff,
    this.bikeCount,
    this.bookingPending,
    required this.builder,
  });

  /// How often the shell is checked for being free for the tour.
  static const Duration checkEvery = Duration(milliseconds: 500);

  /// How many checks in a row must find it free: 1.5 s of quiet.
  static const int calmChecksNeeded = 3;

  @override
  State<AppTourHost> createState() => _AppTourHostState();
}

class _AppTourHostState extends State<AppTourHost> {
  /// One per tab, handed to the bar. Owned here so they live as long as the
  /// shell does, whichever tab is showing.
  final List<GlobalKey> _tabKeys = List.generate(
    AppTourSteps.all.length,
    (_) => GlobalKey(),
  );

  TutorialCoachMark? _tour;
  Timer? _autoStart;
  int _calmChecks = 0;

  /// Set when the member accepts the hand-off, read when the tour ends: the page
  /// to open once the overlay is gone.
  AppTourHandoff? _acceptedHandoff;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    final prefs = widget.prefs;
    if (prefs != null && !AppTourSeen.read(prefs)) {
      _autoStart = Timer.periodic(AppTourHost.checkEvery, (_) => _check());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _autoStart?.cancel();
    // Not left on screen over a shell that is gone.
    _tour?.removeOverlayEntry();
    super.dispose();
  }

  /// Why the tour cannot play right now, or null when nothing else is on top, the
  /// app is in the foreground, and the bar is drawn, so the overlay will not hide
  /// a dialog and has something to light up.
  String? get _busyReason {
    if (!mounted) return 'the shell is not on screen';
    if (_route != null && !_route!.isCurrent) {
      return 'another page or a dialog is on top of the shell';
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return 'the app is not in the foreground ($lifecycle)';
    }
    if (!_tabKeys.every((key) => key.currentContext != null)) {
      return 'the bottom bar is not drawn yet';
    }
    return null;
  }

  /// The last reason printed, so a reason that stays the same prints once.
  String? _lastExplained;

  /// Prints why the tour is not starting (debug builds only), once per change of
  /// reason, so a tour that never appears can be explained from the console.
  void _explain(String reason) {
    if (kReleaseMode || reason == _lastExplained) return;
    _lastExplained = reason;
    debugPrint('[app tour] $reason');
  }

  void _check() {
    // A replay is on screen: nothing to start, and the count begins again after.
    if (_tour != null) {
      _calmChecks = 0;
      return;
    }

    // Only a new member gets it unasked, and only once that is known.
    final countBikes = widget.bikeCount;
    if (countBikes != null) {
      final bikes = countBikes();
      if (bikes == null) {
        _calmChecks = 0;
        _explain(
          'waiting: the stats have not loaded, so the bike count is unknown',
        );
        return;
      }
      final pending = widget.bookingPending?.call() ?? false;
      if (!AppTourAudience.isNew(bikes, bookingPending: pending)) {
        _explain(
          'not for this member: $bikes bike(s) and no first booking pending, '
          'so it is marked seen',
        );
        _retire();
        return;
      }
    }

    final busy = _busyReason;
    _calmChecks = busy == null ? _calmChecks + 1 : 0;
    if (busy != null) {
      _explain('waiting: $busy');
      return;
    }
    if (_calmChecks < AppTourHost.calmChecksNeeded) {
      _explain('waiting: the shell is free, counting quiet checks');
      return;
    }
    _explain('starting');
    start();
  }

  /// The member is not new: stops waiting, and marks the tour seen so a later
  /// change (their last bike deleted) cannot bring it back by itself.
  void _retire() {
    _autoStart?.cancel();
    _autoStart = null;
    _markSeen();
  }

  void _markSeen() {
    final prefs = widget.prefs;
    if (prefs == null) return;
    // Failing to remember only means the tour comes round once more.
    unawaited(AppTourSeen.mark(prefs).catchError((Object _) {}));
  }

  /// Plays the tour. False when it cannot: one is already playing, or the bar's
  /// tabs are not on screen to light up.
  bool start() {
    if (!mounted || _tour != null) return false;
    if (_tabKeys.any((key) => key.currentContext == null)) return false;

    // Whoever asked, the automatic start has nothing left to do: this tour ends
    // by marking it seen.
    _autoStart?.cancel();
    _autoStart = null;

    final handoff = widget.handoff?.call();
    _acceptedHandoff = null;
    final tour = buildAppTour(
      tabKeys: _tabKeys,
      onEnd: _onEnd,
      handoff: handoff,
      onHandoff: handoff == null ? null : () => _acceptedHandoff = handoff,
    );
    _tour = tour;
    tour.show(context: context);
    return true;
  }

  void _onEnd() {
    _tour = null;
    _markSeen();

    // The member took the hand-off: on to their next task. Opened on top, so back
    // returns to the page they were on; whatever the task changes (a saved bike,
    // a booking) it announces itself.
    final accepted = _acceptedHandoff;
    _acceptedHandoff = null;
    if (accepted != null && mounted) {
      switch (accepted.task) {
        case AppTourHandoffTask.addBike:
          final route = accepted.route;
          if (route != null) {
            unawaited(context.push<Object?>(route, extra: accepted.extra));
          }
        case AppTourHandoffTask.bookService:
          // The same start as Home's "Buat booking pertama Anda" card: the booking
          // form, which points to the Booking tab once the booking is made.
          unawaited(startGuidedBooking(router: GoRouter.of(context)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTourScope(start: start, child: widget.builder(context, _tabKeys));
  }
}
