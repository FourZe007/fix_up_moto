import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Small physical taps for the member's fingers: a light click when a choice
/// is made, a firmer tap when something has been done.
///
/// **iPhone only.** iOS apps give this feedback for tab switches, checkboxes
/// and completed actions; Android's convention is quieter, so on Android (and
/// every other platform) these do nothing and the app behaves exactly as before.
///
/// It asks the *device* which platform it is, not the theme, so the
/// `PREVIEW_PLATFORM=ios` look preview on an Android emulator does not buzz an
/// Android phone.
///
/// Fire and forget: callers never wait for a tap, and a phone that cannot
/// vibrate is ignored rather than allowed to throw into the screen.
abstract final class Haptics {
  /// A light click for a choice: a tab switched, a checkbox ticked.
  static void selection() => _tap(HapticFeedback.selectionClick);

  /// A firmer tap for something that worked: a booking created, a bike saved or
  /// deleted, a code verified.
  static void success() => _tap(HapticFeedback.mediumImpact);

  static void _tap(Future<void> Function() feedback) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    unawaited(feedback().catchError((Object _) {}));
  }
}
