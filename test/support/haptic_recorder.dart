import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a light "selection" click is called on the platform channel.
const String selectionTap = 'HapticFeedbackType.selectionClick';

/// What the firmer "something was done" tap is called on the platform channel.
const String successTap = 'HapticFeedbackType.mediumImpact';

/// Records the haptic taps the app asks the phone for, so a test can say
/// "this gave a click" or "this gave none".
///
/// Call [start] before the code under test; the recording stops by itself when
/// the test ends. Each entry is the tap's name, e.g. [selectionTap].
class HapticRecorder {
  final List<String> taps = [];

  HapticRecorder._();

  static HapticRecorder start() {
    final recorder = HapticRecorder._();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        recorder.taps.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return recorder;
  }
}

/// Runs [body] as if on a [platform] phone. Haptics ask the device, not the
/// theme, which platform it is, so this overrides the device's.
Future<void> onDevice(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    // The test framework fails a test that leaves this set.
    debugDefaultTargetPlatformOverride = null;
  }
}
