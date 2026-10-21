import 'package:flutter/material.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';

/// A page background: the theme's own page colour with a warm orange wash
/// fading in from the top edge.
///
/// For a page that should feel warmer without changing its background. The wash
/// is the brand's light orange at 30%, gone by halfway down, so below it the
/// page is still the plain page colour (and on the dark theme's black it reads
/// as a rust glow). It is a fixed backdrop: put it *around* a [Scaffold] whose
/// `backgroundColor` and AppBar are transparent, and the wash shows through
/// behind the bar while the page's content scrolls over it.
class WarmWash extends StatelessWidget {
  final Widget child;

  const WarmWash({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Both ends are the same orange (not Colors.transparent, which is
            // transparent black and would grey the fade out).
            colors: [
              AppColors.primaryLight.withValues(alpha: 0.30),
              AppColors.primaryLight.withValues(alpha: 0),
            ],
            stops: const [0, 0.5],
          ),
        ),
        child: child,
      ),
    );
  }
}
