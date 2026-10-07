import 'package:screen_brightness/screen_brightness.dart';

/// Raises the screen to full brightness for a moment and puts it back.
///
/// Used while the member QR is enlarged: a bright screen is far easier for a
/// scanner to read. Brightness is set at *application* level, so it never
/// touches the user's saved system setting — [restore] hands control back to
/// it.
///
/// Both calls swallow every error. A platform without the plugin (or a device
/// that refuses) must not stop the QR from showing; the worst outcome is the
/// screen simply keeps its brightness.
class ScreenBrightnessBooster {
  const ScreenBrightnessBooster();

  /// Full brightness for this app until [restore] is called.
  Future<void> boost() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (_) {
      // Deliberately swallowed — see the class comment.
    }
  }

  /// Gives brightness back to the system setting.
  Future<void> restore() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {
      // Deliberately swallowed — see the class comment.
    }
  }
}
