import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:share_plus/share_plus.dart';

/// Opens the phone's own share sheet (WhatsApp, Telegram, copy link, ...).
///
/// Kept behind a small class, registered in GetIt, so widgets don't depend on
/// the plugin directly and tests can swap in a fake instead of opening a real
/// share sheet.
class ShareService {
  const ShareService();

  /// Shares [text]. Returns `false` if the share sheet could not be opened
  /// (an unsupported platform, or the system refused) instead of throwing, so
  /// the caller can tell the user rather than crash.
  ///
  /// [sharePositionOrigin] is the on-screen rectangle of the button that was
  /// pressed. iPads and Macs anchor their share popover to it; phones ignore it.
  Future<bool> shareText(String text, {Rect? sharePositionOrigin}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: sharePositionOrigin),
      );
      return true;
    } catch (error) {
      // The caller only needs "it failed"; the reason is for the developer
      // (a missing plugin after a hot restart reads very differently from a
      // system refusal), so it goes to the debug console.
      debugPrint('ShareService.shareText failed: $error');
      return false;
    }
  }
}
