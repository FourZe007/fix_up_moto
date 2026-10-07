import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/services/screen_brightness_booster.dart';

void main() {
  // `flutter test` has no platform plugin behind the brightness channel, so
  // every real call fails — which is exactly the situation the booster must
  // survive (an unsupported platform, or a device that refuses).
  TestWidgetsFlutterBinding.ensureInitialized();

  const booster = ScreenBrightnessBooster();

  test('boost() never throws when brightness cannot be changed', () async {
    await expectLater(booster.boost(), completes);
  });

  test('restore() never throws when brightness cannot be changed', () async {
    await expectLater(booster.restore(), completes);
  });
}
