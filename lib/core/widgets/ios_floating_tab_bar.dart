import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';

/// One tab of a [IosFloatingTabBar].
class IosFloatingTabItem {
  /// Shown while the tab is idle (an outlined icon).
  final IconData icon;

  /// Shown while the tab is selected (the filled version).
  final IconData activeIcon;

  final String label;

  const IosFloatingTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// The iOS bottom tab bar: a rounded pill that floats above the bottom of the
/// screen, with a margin on every side, instead of a bar glued to the edge.
/// Android uses the Material `NavigationBar` instead; `AppTabBar` picks between
/// the two.
///
/// The selected tab gets a soft brand-coloured pill behind its filled icon and
/// label; idle tabs are grey. There is no ripple: a tap is a plain press, as on
/// iOS.
///
/// It sits in a `Scaffold`'s `bottomNavigationBar` slot like any bar, so the
/// page above it ends where the bar's strip begins and nothing is covered. The
/// strip is the page's own colour, which is what makes the pill look like it is
/// floating. The pill and its icons take their colours from the app theme's
/// `bottomNavigationBarTheme` (white in light mode, light grey in dark mode,
/// the same two the Android bar uses), so a theme change reaches it too.
///
/// Labels stop growing at 1.15x the phone's text size, so a large system font
/// cannot push them out of the pill.
class IosFloatingTabBar extends StatelessWidget {
  /// Index into [items] of the tab showing.
  final int selectedIndex;

  /// Called with the index of the tapped tab, including the one already
  /// showing.
  final ValueChanged<int> onSelected;

  final List<IosFloatingTabItem> items;

  /// The colour of the strip the pill floats on, edge to edge, down to the
  /// bottom of the screen. Give it the colour the page above paints at its
  /// bottom edge, so page and strip read as one surface.
  ///
  /// Null leaves the strip unpainted, which shows the colour of whatever is
  /// behind the bar: the `Scaffold`'s own, for a page that uses the plain theme
  /// background.
  final Color? backdropColor;

  const IosFloatingTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    this.backdropColor,
  });

  /// Gap between the pill and the sides of the screen.
  static const double _sideMargin = 16;

  /// Gap above the pill, and the least gap below it on a phone with no
  /// home-indicator inset.
  static const double _verticalMargin = 8;

  /// Room around the tabs inside the pill.
  static const double _padding = 4;

  /// Height of one tab, so the pill is this plus twice [_padding].
  static const double _tabHeight = 56;

  @override
  Widget build(BuildContext context) {
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final surface = navTheme.backgroundColor ?? AppColors.surfaceLight;
    final idle = navTheme.unselectedItemColor ?? AppColors.grey600;

    final bar = SafeArea(
      top: false,
      // Keeps the pill off the bottom edge on a phone with no inset too.
      minimum: const EdgeInsets.only(bottom: _verticalMargin),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _sideMargin,
          _verticalMargin,
          _sideMargin,
          0,
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(_padding),
              child: SizedBox(
                height: _tabHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _IosFloatingTab(
                          item: items[i],
                          selected: i == selectedIndex,
                          idleColor: idle,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Outside the SafeArea, so the strip is painted under the home-indicator
    // inset as well.
    final backdrop = backdropColor;
    return backdrop == null ? bar : ColoredBox(color: backdrop, child: bar);
  }
}

class _IosFloatingTab extends StatelessWidget {
  final IosFloatingTabItem item;
  final bool selected;
  final Color idleColor;
  final VoidCallback onTap;

  const _IosFloatingTab({
    required this.item,
    required this.selected,
    required this.idleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : idleColor;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 10,
      height: 1.2,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: color,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      // The tab answers a screen reader's double-tap too. It has to be said
      // here: excludeSemantics hides the GestureDetector's own tap action.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        // The whole tab answers, not just the icon and the text.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          // Margin (not padding) so the highlight is a little smaller than the
          // tab and the pills of neighbours never touch.
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: ShapeDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 24,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
