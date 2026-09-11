import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/router/route_names.dart';

/// Persistent bottom navigation bar shell shared by the five main tabs.
///
/// Wraps [child] (the active tab page) so the nav bar stays visible during
/// tab switches. Placed inside a [ShellRoute] in [AppRouter] so GoRouter
/// handles the actual routing — this widget only renders the chrome.
///
/// Five tabs: Home, Feeds, Membership, Bookings, Profile. There is
/// deliberately no Services tab — browsing services is a segment inside
/// Bookings (see [BookingsPage]), since browsing a service and booking it are
/// one user journey, not two.
class MainShell extends StatelessWidget {
  /// The active page widget supplied by [ShellRoute].
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // child is the active tab content — rendered above the nav bar
      body: child,
      bottomNavigationBar: NavigationBar(
        // Determine which tab is active by matching the current route location
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_membership_outlined),
            selectedIcon: Icon(Icons.card_membership),
            label: 'Member',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Maps the current GoRouter location to a tab index (0–4).
  /// Defaults to 0 (Home) for any unrecognised path.
  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    // Service browsing/detail now lives under /bookings, so it highlights
    // the Bookings tab too — there is no separate Services destination to
    // highlight instead.
    if (location.startsWith(RouteNames.feeds)) return 1;
    if (location.startsWith(RouteNames.membership)) return 2;
    if (location.startsWith(RouteNames.bookings)) return 3;
    if (location.startsWith(RouteNames.profile)) return 4;
    return 0; // home is the default tab
  }

  /// Navigates to the route corresponding to the tapped [index].
  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RouteNames.home);
      case 1:
        context.go(RouteNames.feeds);
      case 2:
        context.go(RouteNames.membership);
      case 3:
        context.go(RouteNames.bookings);
      case 4:
        context.go(RouteNames.profile);
    }
  }
}
