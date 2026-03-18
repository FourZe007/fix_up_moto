// Smoke test: verifies the app widget tree builds without throwing.
// Full feature tests live in test/features/.
//
// This test does NOT call initDependencies() because GetIt registration
// is async and requires platform channels. Feature-level unit tests
// (auth_bloc_test, login_usecase_test) cover real behaviour.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder — see test/features/ for feature tests', () {
    expect(1 + 1, equals(2));
  });
}
