import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/helpers/haptics.dart';
import 'package:fix_up_moto/core/router/tab_container.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/app_tab_bar.dart';

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

  /// The colour the page of [tab] paints at its bottom edge, for the iOS bar to
  /// float on (see [AppTabBar.backdropColor]); null for a page on the plain
  /// theme background, which is already what shows behind the bar.
  ///
  /// **These repeat the pages' own backgrounds** (each is noted beside the
  /// page's colour): recolour a page and its line here has to change too.
  /// Home and Profile are on the theme background (Profile's warm wash only
  /// fades in from the top). Feeds is null too, for another reason: its video
  /// runs under the pill (see [build]), so a painted strip would cover it.
  static Color? backdropOf(BuildContext context, int tab) => switch (tab) {
    MainTabs.membership => AppColors.primary,
    MainTabs.bookings => Colors.white,
    _ => null,
  };

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
        // On the iOS pill, the Feed's video runs to the bottom edge, behind
        // it, like a full-screen reel. The Feed then gets the bar's height as
        // bottom padding, so its caption and buttons stay just above the pill
        // where they were. Every other tab, and Android's bar, end where the
        // bar begins.
        extendBody: AppTabBar.isFloating(context) && current == MainTabs.feeds,
        // the active tab's page, rendered above the nav bar
        body: navigationShell,
        // Android's Material bar or iOS's Cupertino bar; the choice is made
        // inside AppTabBar, so a tap does the same thing on both.
        bottomNavigationBar: AppTabBar(
          selectedIndex: current,
          backdropColor: backdropOf(context, current),
          // Tapping the tab you are already on goes back to its first page
          // (e.g. out of a service's detail); tapping another switches to
          // it, keeping whatever it was showing.
          onSelected: (index) {
            // A light click on iPhone, nothing on Android.
            Haptics.selection();
            navigationShell.goBranch(index, initialLocation: index == current);
          },
        ),
      ),
    );
  }
}
