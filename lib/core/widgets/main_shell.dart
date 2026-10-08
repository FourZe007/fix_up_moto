import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/router/tab_container.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';

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

  /// The bar's own theme with only the selected tab restyled: no highlight
  /// pill behind it, and its filled icon and its label in the brand colour.
  ///
  /// The unselected state returns `null` for both the icon and the label,
  /// which [NavigationBar] reads as "use your default" — so idle tabs look
  /// exactly as they always did. The label's base style comes from the active
  /// theme's `labelMedium` (what the bar itself uses), not from
  /// `AppTextStyles.labelMedium`, whose letter spacing and line height differ
  /// and would nudge the text each time a tab was selected.
  ///
  /// [AppColors.primary] in light and dark mode alike, as the app's
  /// `bottomNavigationBarTheme` does: the bar is light grey in both.
  static NavigationBarThemeData _barTheme(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return NavigationBarTheme.of(context).copyWith(
      // Material 3's tonal pill behind the selected icon — the red circle.
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const IconThemeData(color: AppColors.primary)
            : null,
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? labelStyle?.copyWith(color: AppColors.primary)
            : null,
      ),
    );
  }

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
        bottomNavigationBar: NavigationBarTheme(
          data: _barTheme(context),
          child: NavigationBar(
            selectedIndex: current,
            // Tapping the tab you are already on goes back to its first page
            // (e.g. out of a service's detail); tapping another switches to
            // it, keeping whatever it was showing.
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
                icon: Icon(Icons.credit_card_rounded),
                selectedIcon: Icon(Icons.credit_card_rounded),
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
      ),
    );
  }
}
