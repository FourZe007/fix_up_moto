import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';

void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('a phone with nothing stored has not seen the guide', () async {
    final prefs = await prefsWith({});

    expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isFalse);
  });

  test('marking it makes it seen', () async {
    final prefs = await prefsWith({});

    await FieldGuideSeen.mark(prefs, FieldGuideId.addBike);

    expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isTrue);
  });

  test('each guide is remembered on its own', () async {
    final prefs = await prefsWith({});

    await FieldGuideSeen.mark(prefs, FieldGuideId.addBike);

    expect(FieldGuideSeen.read(prefs, 'some_other_form'), isFalse);
  });

  test('and apart from the app tour', () async {
    final prefs = await prefsWith({AppTourSeen.key: true});

    expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isFalse);

    await FieldGuideSeen.mark(prefs, FieldGuideId.addBike);
    await prefs.remove(AppTourSeen.key);

    expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isTrue);
  });

  test('a stored value that is not true reads as not seen', () async {
    final prefs = await prefsWith({
      FieldGuideSeen.keyFor(FieldGuideId.addBike): 'yes',
    });

    expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isFalse);
  });

  test('the key is stable, since it is what is stored on the phone', () {
    expect(
      FieldGuideSeen.keyFor(FieldGuideId.addBike),
      'field_guide_seen_add_bike',
    );
    expect(
      FieldGuideSeen.keyFor(FieldGuideId.createBooking),
      'field_guide_seen_create_booking',
    );
  });

  test('Add Bike and Create Booking are remembered apart', () async {
    final prefs = await prefsWith({});

    await FieldGuideSeen.mark(prefs, FieldGuideId.createBooking);

    expect(FieldGuideSeen.read(prefs, FieldGuideId.createBooking), isTrue);
    expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isFalse);
  });
}
