import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:fix_up_moto/core/tour/field_guide.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';

/// Runs one page's field guide: starts it (by itself the first time, or on
/// request), keeps it from doubling, scrolls each step into view, remembers it
/// was seen, and tidies up when it ends or the page goes. Everything in
/// [buildFieldGuide] that is not about how it looks.
///
/// A page owns one in its [State], builds it with its own [steps], and calls:
/// - [autoPlayOnce] from `initState`, if the guide should play by itself;
/// - [play] for its help button;
/// - [dispose] from its own `dispose`.
///
/// What it needs from the page, and why:
/// - [onRoomChanged]: the page adds **blank scroll room** under its content while
///   the guide plays (`setState(() => room = ...)`, drawn as a `SizedBox` at the
///   end of the scrolling column) and takes it away at the end. The guide scrolls
///   each step up near the top of the screen and puts its card below, which the
///   last steps could not manage near the end of the page without that room.
///   The overlay covers the page, so the blank space is never seen.
/// - [scroll]: the page's scroll controller, so the end of the guide can take the
///   page back to its top (otherwise it is left wherever the last step was).
/// - [active]: set true while the guide is on screen, for a page that hides its
///   help button meanwhile (the guide's "Lewati" sits in the same corner).
///
/// Hand-written for testability: no widget of its own, so a page's tests drive
/// it through the page.
class FieldGuidePlayer {
  /// How long [autoPlayOnce] waits after the page opens: for the page's
  /// slide-in to finish, so the overlay is not drawn over a moving page.
  static const Duration autoDelay = Duration(milliseconds: 800);

  /// How often, after that, an automatic start that is not ready yet looks again,
  /// and how long in all it will wait before starting anyway.
  ///
  /// The cap is longer than the longest thing a page makes the guide wait for
  /// (Create Booking's workshop lookup is limited to 30 s), so the guide never
  /// starts in the middle of it; it only stands in for a page that never says
  /// it is ready. And it counts **foreground time only**: while a system prompt
  /// is on screen the app is not in the foreground, and the member's time reading
  /// it is theirs, not the page's.
  static const Duration retryEvery = Duration(milliseconds: 300);
  static const Duration waitAtMost = Duration(seconds: 35);

  /// Which guide this is, for [FieldGuideSeen].
  final String guideId;

  /// The steps, in the page's own top-to-bottom order.
  final List<FieldGuideStep> steps;

  /// The page's state: its context to draw over, and whether it is still there.
  final State state;

  /// Where "seen" is kept. Null means nothing is remembered and the guide never
  /// plays by itself; [play] still works.
  final SharedPreferences? prefs;

  final void Function(double room) onRoomChanged;
  final ScrollController? scroll;
  final ValueNotifier<bool>? active;

  FieldGuidePlayer({
    required this.guideId,
    required this.steps,
    required this.state,
    required this.onRoomChanged,
    this.prefs,
    this.scroll,
    this.active,
  });

  /// The guide on screen, or null.
  TutorialCoachMark? _guide;

  /// True from asking for the guide until it is up: there can be a short wait
  /// for the keyboard to go down, and a second ask must not start a second one.
  bool _starting = false;

  Timer? _auto;

  /// Plays the guide once the page has settled in, if there are [prefs] and the
  /// phone has not been through it. Skips if something (a dialog, another page)
  /// is on top by then: it will come round the next time the page opens.
  ///
  /// [ready] holds the start back while the page is still busy with something the
  /// guide would talk over (Create Booking, while it looks up the nearest
  /// workshop, which may put the system's location prompt on screen). It is
  /// asked again every [retryEvery], for at most [waitAtMost] of foreground time,
  /// and then the guide starts anyway: a slow answer must not take the guide away.
  /// The start also waits while the app is not in the foreground, which is what a
  /// system prompt does to it, and that waiting does not use up the cap.
  void autoPlayOnce({bool Function()? ready}) {
    final prefs = this.prefs;
    if (prefs == null || FieldGuideSeen.read(prefs, guideId)) return;
    _scheduleAuto(autoDelay, ready, Duration.zero);
  }

  void _scheduleAuto(Duration after, bool Function()? ready, Duration before) {
    _auto = Timer(after, () {
      _auto = null;
      if (!state.mounted) return;
      if (ModalRoute.of(state.context)?.isCurrent == false) return;

      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final foreground =
          lifecycle == null || lifecycle == AppLifecycleState.resumed;
      // Only time spent in the foreground counts towards the cap.
      final waited = foreground ? before + after : before;
      final busy = !foreground || (ready != null && !ready());
      if (busy && waited < waitAtMost) {
        _scheduleAuto(retryEvery, ready, waited);
        return;
      }
      play();
    });
  }

  /// Plays the guide now. False when it cannot: one is already playing or about
  /// to, or a step's widget is not on screen to light up.
  bool play() {
    if (!state.mounted || _guide != null || _starting) return false;
    if (steps.any((s) => s.key.currentContext == null)) return false;

    // The automatic start has nothing left to do: this guide ends by marking it
    // seen, and a second one on top would double up.
    _auto?.cancel();
    _auto = null;
    unawaited(_show());
    return true;
  }

  Future<void> _show() async {
    _starting = true;
    try {
      // A keyboard on screen would drop away once the guide is up and the page
      // would move under the overlay: lower it first and let it finish.
      if (MediaQuery.viewInsetsOf(state.context).bottom > 0) {
        FocusManager.instance.primaryFocus?.unfocus();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!state.mounted) return;
      }

      // Room first, and a frame for it to take effect, so the first scroll to a
      // late step already has somewhere to go.
      onRoomChanged(MediaQuery.sizeOf(state.context).height * 0.8);
      await WidgetsBinding.instance.endOfFrame;
      if (!state.mounted) return;

      final guide = buildFieldGuide(
        steps: steps,
        onEnd: _onEnd,
        reveal: _reveal,
      );
      _guide = guide;
      active?.value = true;
      guide.show(context: state.context);
    } finally {
      _starting = false;
    }
  }

  /// Scrolls [step]'s widget up into the top part of the page, awaited before the
  /// guide measures it: pages are longer than a phone screen, so the later steps
  /// start out below the fold. A step outside the scrolling part (a bar fixed at
  /// the bottom) has nothing to scroll and returns at once.
  Future<void> _reveal(FieldGuideStep step) async {
    final stepContext = step.key.currentContext;
    if (stepContext == null || !stepContext.mounted) return;
    await Scrollable.ensureVisible(
      stepContext,
      alignment: 0.2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onEnd() {
    _guide = null;
    active?.value = false;
    if (state.mounted) {
      onRoomChanged(0);
      // Back to the top, once the blank room has gone and the extent has
      // settled, so the member starts at the first thing on the page.
      final scroll = this.scroll;
      if (scroll != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!state.mounted || !scroll.hasClients) return;
          unawaited(
            scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
          );
        });
      }
    }

    final prefs = this.prefs;
    if (prefs == null) return;
    // Failing to remember only means the guide comes round once more.
    unawaited(FieldGuideSeen.mark(prefs, guideId).catchError((Object _) {}));
  }

  /// Not left on screen over a page that is gone (a back press mid-guide), and no
  /// automatic start left waiting.
  void dispose() {
    _auto?.cancel();
    _auto = null;
    _guide?.removeOverlayEntry();
    _guide = null;
  }
}
