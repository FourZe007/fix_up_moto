import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/router/tab_container.dart';

/// Persistent bottom navigation bar shell shared by the five main tabs.
///
/// Wraps [navigationShell] (the stack of tab pages) so the nav bar stays
/// visible during tab switches. Built by the [StatefulShellRoute] in
/// [AppRouter], which keeps each tab alive while it is hidden — this widget
/// only renders the chrome and tells the shell which tab was picked.
///
/// Five tabs, in [MainTabs] order: Home, Feeds, Membership, Bookings,
/// Profile. There is deliberately no Services tab — past service history is a
/// segment inside Bookings (see [BookingsPage]) instead, alongside current
/// bookings, since both are about the member's visits to FixUp Moto rather
/// than separate concerns.
class MainShell extends StatelessWidget {
  /// The tab pages and which one is showing, supplied by the router.
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex;

    // Switching tabs does not push anything on a back stack, so without this
    // the system back button would close the app from any non-Home tab
    // (including Home's own "Booking"/"Bikes List" quick actions) instead of
    // returning to Home, which is the behaviour every bottom-nav app is
    // expected to have.
    return PopScope(
      canPop: current == MainTabs.home,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // already on Home — let the OS handle it (exit)
        log('Return to Home');
        navigationShell.goBranch(MainTabs.home);
      },
      child: Scaffold(
        // the active tab's page, rendered above the nav bar
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: current,
          // Tapping the tab you are already on goes back to its first page
          // (e.g. out of a service's detail); tapping another switches to it,
          // keeping whatever it was showing.
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == current,
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              selectedIcon: Icon(Icons.play_circle),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.card_membership_outlined),
              selectedIcon: Icon(Icons.card_membership),
              label: 'My Point',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Booking',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Saya',
            ),
          ],
        ),
      ),
    );
  }
}
