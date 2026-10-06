import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Position of each main tab: the order of the branches in `AppRouter`'s
/// [StatefulShellRoute] and of the destinations in `MainShell`'s bar.
abstract final class MainTabs {
  static const int home = 0;
  static const int feeds = 1;
  static const int membership = 2;
  static const int bookings = 3;
  static const int profile = 4;
}

/// Lays out the tab pages so each one is built on its first visit and then
/// kept alive while hidden — switching back is instant and doesn't refetch.
/// This is go_router's own indexed-stack container, plus [disposeWhenHidden].
///
/// Tabs listed in [disposeWhenHidden] are dropped while hidden and rebuilt
/// when selected again. Use it for a tab that must not keep running in the
/// background: the Feeds reels only pause when you swipe to another reel, so a
/// kept-alive Feeds tab would keep playing its video's audio under every other
/// tab.
Widget buildTabContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> branches, {
  Set<int> disposeWhenHidden = const {},
}) {
  final current = navigationShell.currentIndex;

  return IndexedStack(
    index: current,
    children: [
      for (var i = 0; i < branches.length; i++)
        if (i != current && disposeWhenHidden.contains(i))
          const SizedBox.shrink()
        else
          Offstage(
            offstage: i != current,
            child: TickerMode(enabled: i == current, child: branches[i]),
          ),
    ],
  );
}
