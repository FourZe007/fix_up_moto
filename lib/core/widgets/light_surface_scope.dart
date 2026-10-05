import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';

/// Wraps content that sits on a light-grey surface (a card, panel, rounded
/// page body or filled input) so it stays readable in dark mode.
///
/// In light mode this returns [child] untouched. In dark mode it re-themes the
/// subtree with [AppTheme.darkSurface] — the light theme on light-grey
/// surfaces — so text, icons, inputs and buttons inside use their light-mode
/// colours instead of the dark theme's white-on-black ones.
///
/// Anything that reads `Theme.of(context)` *inside* [child] sees the new
/// theme, but a `Theme.of(context)` taken in the build method that creates
/// this widget does not — put the scope above a [Builder] when the content
/// needs to read the theme itself.
class LightSurfaceScope extends StatelessWidget {
  final Widget child;

  const LightSurfaceScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) return child;
    return Theme(data: AppTheme.darkSurface, child: child);
  }
}
