import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/tour/app_tour_seen.dart';

Future<SharedPreferences> prefsWith(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  return SharedPreferences.getInstance();
}

void main() {
  test('is stored under its own key, apart from the welcome flag', () {
    expect(AppTourSeen.key, 'app_tour_seen');
    expect(AppTourSeen.key, isNot('welcome_seen'));
  });

  test('a fresh install has not seen the tour', () async {
    expect(AppTourSeen.read(await prefsWith({})), isFalse);
  });

  test('marking it seen sticks, and marking twice is fine', () async {
    final prefs = await prefsWith({});

    await AppTourSeen.mark(prefs);
    expect(AppTourSeen.read(prefs), isTrue);

    await AppTourSeen.mark(prefs);
    expect(AppTourSeen.read(prefs), isTrue);
  });

  test('a stored true is read back as seen', () async {
    expect(AppTourSeen.read(await prefsWith({AppTourSeen.key: true})), isTrue);
  });

  test('anything but true counts as not seen, and never throws', () async {
    for (final bad in <Object>[false, 'yes', 1, 'true']) {
      expect(
        AppTourSeen.read(await prefsWith({AppTourSeen.key: bad})),
        isFalse,
        reason: '$bad',
      );
    }
  });
}
