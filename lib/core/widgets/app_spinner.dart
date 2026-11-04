import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The app's loading spinner, in each platform's own style.
///
/// Android shows the ordinary Material [CircularProgressIndicator], given
/// exactly the [color] and [strokeWidth] the call site passes (nothing more),
/// so it looks as it always did. iOS shows the system's
/// [CupertinoActivityIndicator], the ticking spoke wheel.
///
/// **Why not `CircularProgressIndicator.adaptive`:** on iOS that drops the
/// colour (it only reads `backgroundColor`), which would turn the white spinners
/// on the orange buttons grey. This keeps the colour on both.
///
/// It reads `Theme.of(context).platform` rather than the device's, so the
/// `--dart-define=PREVIEW_PLATFORM=ios` switch shows the iOS version anywhere.
///
/// Sizing follows the box around it. In a tight box (a `SizedBox` in a button)
/// the iOS indicator is scaled to fill it, as the Material one is; unboxed it
/// is the indicator's natural 20 px. [strokeWidth] has no iOS meaning (the
/// spokes are a fixed shape) and is ignored there.
class AppSpinner extends StatelessWidget {
  /// The spinner's colour; null means the platform's default (the theme's
  /// primary on Android, the system grey on iOS).
  final Color? color;

  /// Android only; null leaves Material's own width.
  final double? strokeWidth;

  const AppSpinner({super.key, this.color, this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => FittedBox(
        // Scales the indicator to the box it is put in, like Material's, and
        // stays its natural size when nothing boxes it. Unlike a LayoutBuilder
        // it also answers intrinsic-size questions.
        child: CupertinoActivityIndicator(color: color),
      ),
      _ => CircularProgressIndicator(color: color, strokeWidth: strokeWidth),
    };
  }
}
