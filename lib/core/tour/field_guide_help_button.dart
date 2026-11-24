import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// The app-bar "?" that plays a page's field guide again.
///
/// Steps aside while the guide is on screen ([active] true): the guide's
/// "Lewati" sits in the same top-right corner and would land on top of it. It is
/// hidden, not removed, so the title keeps its place and does not shift.
///
/// [buttonKey] goes on the button itself, for a test to find and press.
/// [color] is the icon's colour; null leaves the bar's own foreground colour,
/// which is right on a coloured bar (Create Booking's white-on-orange).
class FieldGuideHelpButton extends StatelessWidget {
  final ValueListenable<bool> active;
  final VoidCallback onPressed;
  final Key? buttonKey;
  final Color? color;

  const FieldGuideHelpButton({
    super.key,
    required this.active,
    required this.onPressed,
    this.buttonKey,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: active,
      builder: (context, playing, button) => Visibility(
        visible: !playing,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: button!,
      ),
      child: IconButton(
        key: buttonKey,
        icon: const Icon(Icons.help_outline),
        tooltip: 'Panduan pengisian',
        style: color == null
            ? null
            : IconButton.styleFrom(foregroundColor: color),
        onPressed: onPressed,
      ),
    );
  }
}
