import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A confirmation dialog in each platform's own style: the ordinary Material
/// [AlertDialog] on Android, the iOS [CupertinoAlertDialog] on iOS.
///
/// Open it with `showAdaptiveDialog`, which opens a Material dialog on Android
/// (dismissable by tapping outside, exactly as `showDialog` was) and an iOS
/// one on iOS (not dismissable by tapping outside, as on iOS the member must
/// choose a button). Fill [actions] with [AdaptiveDialogAction]s.
///
/// **Why not `AlertDialog.adaptive`:** that is a different widget type, so on
/// Android it would no longer be found as an `AlertDialog`, and the app's tests
/// that check for one would stop seeing it. This builds the real `AlertDialog`
/// on Android, with the same arguments the call sites always passed.
///
/// It reads `Theme.of(context).platform`, so `--dart-define=PREVIEW_PLATFORM=ios`
/// shows the iOS version anywhere.
class AdaptiveAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  const AdaptiveAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => CupertinoAlertDialog(
        title: title,
        content: content,
        actions: actions,
      ),
      _ => AlertDialog(title: title, content: content, actions: actions),
    };
  }
}

/// A button of an [AdaptiveAlertDialog]: a [TextButton] on Android, a
/// [CupertinoDialogAction] on iOS.
///
/// A Material button cannot sit in an iOS dialog (it has no Material ancestor
/// there), which is why the dialog's buttons need this wrapper.
///
/// [isDestructive] (red text on iOS) and [isDefault] (bold on iOS, the
/// suggested choice) are iOS conventions only: on Android the button is left
/// exactly as a plain `TextButton`, as the app always drew these.
class AdaptiveDialogAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isDestructive;
  final bool isDefault;

  const AdaptiveDialogAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
    this.isDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => CupertinoDialogAction(
        onPressed: onPressed,
        isDestructiveAction: isDestructive,
        isDefaultAction: isDefault,
        child: child,
      ),
      _ => TextButton(onPressed: onPressed, child: child),
    };
  }
}
