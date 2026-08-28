import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] to the [Listenable] that [GoRouter.refreshListenable]
/// expects, so route guards re-evaluate when app state changes.
///
/// **Why this is needed:** GoRouter's `redirect` is not reactive. It runs when a
/// route is resolved, when a navigation happens, or when a `refreshListenable`
/// notifies — and nothing else. Without one, an `AuthBloc` that resolves its
/// session *after* the first route has been painted never gets to move the user,
/// because the guard is never asked a second time. That is exactly how an
/// unauthenticated launch ended up sitting on the dashboard.
///
/// Usage:
/// ```dart
/// GoRouter(
///   refreshListenable: GoRouterRefreshStream(sl<AuthBloc>().stream),
///   redirect: (context, state) { ... },
/// )
/// ```
///
/// Adapted from the pattern in go_router's own examples.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    // Notify once up front so the router evaluates against the current state
    // rather than waiting for the next emission.
    notifyListeners();

    _subscription = stream
        // asBroadcastStream() so more than one listener may attach to the same
        // bloc stream without the second one throwing.
        .asBroadcastStream()
        .listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
