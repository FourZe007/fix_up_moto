import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/theme/preview_platform.dart';

void main() {
  final android = ThemeData(platform: TargetPlatform.android);

  TargetPlatform platformFor(String preview, {bool release = false}) =>
      applyPreviewPlatform(
        android,
        preview: preview,
        release: release,
      ).platform;

  test('leaves the theme alone when no preview is asked for', () {
    final themed = applyPreviewPlatform(android, preview: '', release: false);

    expect(themed, same(android));
    expect(themed.platform, TargetPlatform.android);
  });

  test('"ios" makes the theme report iOS', () {
    expect(platformFor('ios'), TargetPlatform.iOS);
  });

  test('accepts any letter case and stray spaces', () {
    expect(platformFor('iOS'), TargetPlatform.iOS);
    expect(platformFor(' IOS '), TargetPlatform.iOS);
  });

  test('"android" asks for the Android look explicitly', () {
    final ios = ThemeData(platform: TargetPlatform.iOS);

    expect(
      applyPreviewPlatform(ios, preview: 'android', release: false).platform,
      TargetPlatform.android,
    );
  });

  test('an unknown value leaves the theme alone', () {
    expect(platformFor('windows'), TargetPlatform.android);
    expect(platformFor('yes'), TargetPlatform.android);
  });

  test('a release build ignores it, so a stray define can never ship', () {
    final themed = applyPreviewPlatform(android, preview: 'ios', release: true);

    expect(themed, same(android));
    expect(themed.platform, TargetPlatform.android);
  });

  test('keeps every other setting of the theme', () {
    final themed = applyPreviewPlatform(
      ThemeData(
        platform: TargetPlatform.android,
        scaffoldBackgroundColor: const Color(0xFF123456),
      ),
      preview: 'ios',
      release: false,
    );

    expect(themed.scaffoldBackgroundColor, const Color(0xFF123456));
  });
}
