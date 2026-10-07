import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/services/share_service.dart';

void main() {
  // `flutter test` has no platform share sheet behind the plugin, so the real
  // call fails — which is exactly what the service must turn into `false`
  // instead of an exception (an unsupported platform, or the system refusing).
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shareText() returns false instead of throwing when sharing fails', () {
    expect(const ShareService().shareText('hello'), completion(isFalse));
  });
}
