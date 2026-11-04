import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';

/// [theme], made to report another platform when one is being previewed.
///
/// The platform-aware widgets (`showAdaptiveDialog`, `RefreshIndicator.adaptive`,
/// the app's own spinner and dialog buttons) read `Theme.platform`, so changing
/// it there is enough to see their iOS versions on an Android emulator or on
/// Windows. It does not bring Apple's own glass or system font: only what
/// Flutter draws itself.
///
/// [preview] is `ios` or `android` in any letter case; anything else, and the
/// empty default, returns [theme] itself, untouched. A [release] build always
/// returns [theme] untouched, so a stray `--dart-define` can never ship an
/// Android app that looks like iOS.
ThemeData applyPreviewPlatform(
  ThemeData theme, {
  String preview = AppConstants.previewPlatform,
  bool release = kReleaseMode,
}) {
  if (release) return theme;

  return switch (preview.trim().toLowerCase()) {
    'ios' => theme.copyWith(platform: TargetPlatform.iOS),
    'android' => theme.copyWith(platform: TargetPlatform.android),
    _ => theme,
  };
}
