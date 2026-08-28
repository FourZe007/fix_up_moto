import 'package:flutter/material.dart';

/// Shown while the app decides whether there is a cached session.
///
/// Lives here rather than under `features/auth/` because it is a **routing**
/// concern: it occupies the window between the app starting and the router
/// knowing where to send the user. It reads no BLoC and holds no state.
///
/// Reached only at cold start — [AuthInitial] is never re-entered once the
/// session check resolves, so this page cannot reappear later in the session.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          height: 32,
          width: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
