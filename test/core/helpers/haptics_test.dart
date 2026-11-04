import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/haptics.dart';
import '../../support/haptic_recorder.dart';

void main() {
  testWidgets('on iOS a selection is a light click', (tester) async {
    final haptics = HapticRecorder.start();

    await onDevice(TargetPlatform.iOS, () async {
      Haptics.selection();
      await tester.pump();
    });

    expect(haptics.taps, [selectionTap]);
  });

  testWidgets('on iOS a success is a firmer tap', (tester) async {
    final haptics = HapticRecorder.start();

    await onDevice(TargetPlatform.iOS, () async {
      Haptics.success();
      await tester.pump();
    });

    expect(haptics.taps, [successTap]);
  });

  testWidgets('they come out in the order they were asked for', (tester) async {
    final haptics = HapticRecorder.start();

    await onDevice(TargetPlatform.iOS, () async {
      Haptics.selection();
      Haptics.success();
      Haptics.selection();
      await tester.pump();
    });

    expect(haptics.taps, [selectionTap, successTap, selectionTap]);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.fuchsia,
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.macOS,
  ]) {
    testWidgets('on $platform there is nothing at all', (tester) async {
      final haptics = HapticRecorder.start();

      await onDevice(platform, () async {
        Haptics.selection();
        Haptics.success();
        await tester.pump();
      });

      expect(haptics.taps, isEmpty);
    });
  }

  testWidgets('a phone that cannot vibrate does not break the app', (
    tester,
  ) async {
    // No handler is installed here, so the platform call fails the way it does
    // on a device without the hardware; asking must not throw.
    await onDevice(TargetPlatform.iOS, () async {
      Haptics.selection();
      Haptics.success();
      await tester.pump();
    });

    expect(tester.takeException(), isNull);
  });
}
