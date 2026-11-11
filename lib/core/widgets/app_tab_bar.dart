import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/ios_floating_tab_bar.dart';

/// The bottom bar of the five main tabs, in each platform's own style: the
/// Material [NavigationBar] on Android, a rounded [IosFloatingTabBar] pill on iOS.
///
/// It only draws the bar. What a tap does (the haptic click, switching branch)
/// stays in `MainShell`, which passes it in as [onSelected], so both bars
/// behave the same and the Android/iOS choice is made in exactly one place:
/// the two-arm `switch` in [isFloating].
///
/// The five tabs, in `MainTabs` order: Beranda, Feed, MyPoint, Booking, Saya.
/// Each bar lists them itself (Android with Material icons, iOS with iOS-style
/// icons), so **a change to a tab's label has to be made in both lists**; a test
/// checks that they match.
///
/// It reads `Theme.of(context).platform`, so `--dart-define=PREVIEW_PLATFORM=ios`
/// shows the iOS bar on an Android emulator. The pill is Flutter's own drawing,
/// not Apple's, so it will not pick up iOS's Liquid Glass.
class AppTabBar extends StatelessWidget {
  /// Index of the tab showing, in `MainTabs` order.
  final int selectedIndex;

  /// Called with the index of the tab that was tapped, including the one that
  /// is already showing.
  final ValueChanged<int> onSelected;

  /// iOS only: the colour of the strip the pill floats on, which should be the
  /// colour the showing tab's page paints at its bottom edge. Null leaves it to
  /// the page behind. Android's bar has its own surface and ignores this.
  final Color? backdropColor;

  const AppTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.backdropColor,
  });

  /// Whether the bar is the floating iOS pill (true) or Android's Material bar
  /// (false). **The one place that choice is made:** [build] draws the matching
  /// bar, and `MainShell` reads this to lay the Feed out under the pill.
  static bool isFloating(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => true,
        // TEMPORARY, set by hand to preview the pill on an Android emulator:
        // change this to `false` to give Android its own Material bar back.
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    return isFloating(context)
        ? IosFloatingTabBar(
            selectedIndex: selectedIndex,
            onSelected: onSelected,
            items: _iosTabs,
            backdropColor: backdropColor,
          )
        : _AndroidTabBar(selectedIndex: selectedIndex, onSelected: onSelected);
  }
}

/// The Android bar: the Material [NavigationBar] the app has always had.
class _AndroidTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _AndroidTabBar({required this.selectedIndex, required this.onSelected});

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
    return NavigationBarTheme(
      data: _barTheme(context),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
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
            label: 'MyPoint',
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
    );
  }
}

/// The iOS bar's five tabs, in `MainTabs` order, with iOS-style icons.
const _iosTabs = [
  IosFloatingTabItem(
    icon: CupertinoIcons.house,
    activeIcon: CupertinoIcons.house_fill,
    label: 'Beranda',
  ),
  IosFloatingTabItem(
    icon: CupertinoIcons.play_circle,
    activeIcon: CupertinoIcons.play_circle_fill,
    label: 'Feed',
  ),
  IosFloatingTabItem(
    icon: CupertinoIcons.creditcard,
    activeIcon: CupertinoIcons.creditcard_fill,
    label: 'MyPoint',
  ),
  IosFloatingTabItem(
    icon: CupertinoIcons.calendar,
    // iOS has no filled calendar; this one has a solid day.
    activeIcon: CupertinoIcons.calendar_today,
    label: 'Booking',
  ),
  IosFloatingTabItem(
    icon: CupertinoIcons.person,
    activeIcon: CupertinoIcons.person_fill,
    label: 'Saya',
  ),
];
