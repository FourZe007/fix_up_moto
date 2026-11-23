import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/features/home/presentation/widgets/first_booking_guide.dart';

void main() {
  Future<SharedPreferences> prefsWith([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('nobody is pending on a phone that has seen nobody', () async {
    final prefs = await prefsWith();

    expect(FirstBookingGuide.isPending(prefs, 'M-1'), isFalse);
  });

  test('a member noted as new is pending', () async {
    final prefs = await prefsWith();

    await FirstBookingGuide.notePending(prefs, 'M-1');

    expect(FirstBookingGuide.isPending(prefs, 'M-1'), isTrue);
  });

  test('noting the same member again changes nothing', () async {
    final prefs = await prefsWith();

    await FirstBookingGuide.notePending(prefs, 'M-1');
    await FirstBookingGuide.notePending(prefs, 'M-1');

    expect(prefs.getStringList(FirstBookingGuide.pendingKey), ['M-1']);
  });

  test('members are kept apart on a shared phone', () async {
    final prefs = await prefsWith();

    await FirstBookingGuide.notePending(prefs, 'M-1');
    await FirstBookingGuide.notePending(prefs, 'M-2');
    await FirstBookingGuide.settle(prefs, 'M-1');

    expect(FirstBookingGuide.isPending(prefs, 'M-1'), isFalse);
    expect(FirstBookingGuide.isPending(prefs, 'M-2'), isTrue);
  });

  test('a booking settles the member', () async {
    final prefs = await prefsWith();
    await FirstBookingGuide.notePending(prefs, 'M-1');

    await FirstBookingGuide.settle(prefs, 'M-1');

    expect(FirstBookingGuide.isPending(prefs, 'M-1'), isFalse);
  });

  test(
    'a settled member is not made pending again, whatever is seen',
    () async {
      final prefs = await prefsWith();
      await FirstBookingGuide.notePending(prefs, 'M-1');
      await FirstBookingGuide.settle(prefs, 'M-1');

      // E.g. they delete their last bike and the app sees them with none.
      await FirstBookingGuide.notePending(prefs, 'M-1');

      expect(FirstBookingGuide.isPending(prefs, 'M-1'), isFalse);
    },
  );

  test('a member who booked without ever being noted is settled too', () async {
    final prefs = await prefsWith();

    await FirstBookingGuide.settle(prefs, 'M-1');
    await FirstBookingGuide.notePending(prefs, 'M-1');

    expect(FirstBookingGuide.isPending(prefs, 'M-1'), isFalse);
  });

  test('settling twice is harmless', () async {
    final prefs = await prefsWith();

    await FirstBookingGuide.settle(prefs, 'M-1');
    await FirstBookingGuide.settle(prefs, 'M-1');

    expect(prefs.getStringList(FirstBookingGuide.settledKey), ['M-1']);
  });

  test('is remembered by the stored lists, so it survives a restart', () async {
    final prefs = await prefsWith({
      FirstBookingGuide.pendingKey: ['M-1'],
    });

    expect(FirstBookingGuide.isPending(prefs, 'M-1'), isTrue);
  });

  test('a corrupt entry reads as nobody instead of throwing', () async {
    final prefs = await prefsWith({
      FirstBookingGuide.pendingKey: 'M-1',
      FirstBookingGuide.settledKey: 7,
    });

    expect(FirstBookingGuide.isPending(prefs, 'M-1'), isFalse);
    await FirstBookingGuide.notePending(prefs, 'M-1');
    expect(FirstBookingGuide.isPending(prefs, 'M-1'), isTrue);
  });
}
