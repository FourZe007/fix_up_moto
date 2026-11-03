import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/router/welcome_seen.dart';

Future<SharedPreferences> prefsWith(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  return SharedPreferences.getInstance();
}

void main() {
  test('is stored under welcome_seen', () {
    expect(WelcomeSeen.key, 'welcome_seen');
  });

  test('has not been seen on a fresh install', () async {
    expect(WelcomeSeen.read(await prefsWith({})), isFalse);
  });

  test('has been seen once marked, and stays so', () async {
    final prefs = await prefsWith({});

    await WelcomeSeen.mark(prefs);
    expect(WelcomeSeen.read(prefs), isTrue);

    await WelcomeSeen.mark(prefs);
    expect(WelcomeSeen.read(prefs), isTrue, reason: 'marking twice is fine');
  });

  test('has been seen when the saved value says so', () async {
    expect(WelcomeSeen.read(await prefsWith({WelcomeSeen.key: true})), isTrue);
  });

  test(
    'counts anything other than true as not seen, without throwing',
    () async {
      expect(
        WelcomeSeen.read(await prefsWith({WelcomeSeen.key: false})),
        isFalse,
      );
      expect(
        WelcomeSeen.read(await prefsWith({WelcomeSeen.key: 'yes'})),
        isFalse,
      );
      expect(WelcomeSeen.read(await prefsWith({WelcomeSeen.key: 1})), isFalse);
    },
  );
}
