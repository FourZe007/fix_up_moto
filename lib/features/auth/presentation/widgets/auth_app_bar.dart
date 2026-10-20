import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';

/// The top bar of the login and register screens: nothing but a back arrow,
/// set up like the one on the app's other pages (Settings, Edit Profile, …).
///
/// The welcome screen is the root, and these two are pushed on top of it, so
/// back returns there. There is no title: each screen's own headline sits
/// right under the bar.
class AuthAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AuthAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // The colours come from the active Theme rather than AppColors constants,
    // so this bar follows light/dark automatically. The arrow is coloured
    // explicitly because the app's AppBarTheme hard-codes a white foreground.
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      // Same colour as the page behind it, so the bar blends into the body.
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: BlocBuilder<AuthBloc, AuthState>(
        // Only whether a request is running matters, not every state change.
        buildWhen: (previous, current) =>
            (previous is AuthLoading) != (current is AuthLoading),
        builder: (context, state) => IconButton(
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(foregroundColor: onSurface),
          // Not mid-request: leaving would drop the form out from under a
          // login or registration that is still being sent.
          onPressed: state is AuthLoading ? null : () => _back(context),
        ),
      ),
    );
  }

  /// Back to the page underneath — the welcome screen. Opened with nothing
  /// underneath (a restored session, a deep link), there is nothing to pop, so
  /// go to the welcome screen instead of failing.
  static void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.welcome);
    }
  }
}
