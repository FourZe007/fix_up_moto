import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/debug/simulated_first_booking.dart';
import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_booking_guide.dart';

DashboardStatsEntity statsOf({String memberId = 'M-001', int qty = 3}) =>
    DashboardStatsEntity(
      status: 'AKTIF',
      memberId: memberId,
      memberName: 'Test Member',
      emailAddress: 'a@example.com',
      phoneNo: '81234567890',
      active: true,
      qty: qty,
      point: 80,
      detail: const [],
      detail2: const [],
    );

void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('start', () {
    test('is off by default', () async {
      final prefs = await prefsWith({});

      expect(await SimulatedFirstBooking.start(prefs), isNull);
    });

    test('is off in a release build, even when asked for', () async {
      final prefs = await prefsWith({});

      final simulation = await SimulatedFirstBooking.start(
        prefs,
        enabled: true,
        release: true,
      );

      expect(simulation, isNull);
    });

    test('is on when asked for in a debug build', () async {
      final prefs = await prefsWith({});

      final simulation = await SimulatedFirstBooking.start(
        prefs,
        enabled: true,
        release: false,
      );

      expect(simulation, isNotNull);
    });

    test('and then makes the launch a first run for the app tour', () async {
      final prefs = await prefsWith({AppTourSeen.key: true});

      await SimulatedFirstBooking.start(prefs, enabled: true, release: false);

      expect(AppTourSeen.read(prefs), isFalse);
    });

    test(
      'but leaves the booking memory alone until a member is seen',
      () async {
        final prefs = await prefsWith({
          FirstBookingGuide.pendingKey: ['M-009'],
          FirstBookingGuide.settledKey: ['M-001'],
          'theme_mode': 'dark',
        });

        await SimulatedFirstBooking.start(prefs, enabled: true, release: false);

        expect(prefs.getStringList(FirstBookingGuide.pendingKey), ['M-009']);
        expect(prefs.getStringList(FirstBookingGuide.settledKey), ['M-001']);
        expect(prefs.getString('theme_mode'), 'dark');
      },
    );

    test('and the Create Booking guide, so it plays at every launch', () async {
      final prefs = await prefsWith({
        FieldGuideSeen.keyFor(FieldGuideId.createBooking): true,
        FieldGuideSeen.keyFor(FieldGuideId.addBike): true,
      });

      await SimulatedFirstBooking.start(prefs, enabled: true, release: false);

      expect(FieldGuideSeen.read(prefs, FieldGuideId.createBooking), isFalse);
      // Add Bike is not part of this launch: the member already has bikes.
      expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isTrue);
    });

    test(
      'and in a release build forgets nothing, even when asked for',
      () async {
        final prefs = await prefsWith({
          AppTourSeen.key: true,
          FieldGuideSeen.keyFor(FieldGuideId.createBooking): true,
        });

        await SimulatedFirstBooking.start(prefs, enabled: true, release: true);

        expect(AppTourSeen.read(prefs), isTrue);
        expect(FieldGuideSeen.read(prefs, FieldGuideId.createBooking), isTrue);
      },
    );

    test('and when it is off forgets nothing either', () async {
      final prefs = await prefsWith({AppTourSeen.key: true});

      await SimulatedFirstBooking.start(prefs);

      expect(AppTourSeen.read(prefs), isTrue);
    });
  });

  group('prepare', () {
    late SharedPreferences prefs;
    late SimulatedFirstBooking simulation;

    Future<void> startWith(Map<String, Object> values) async {
      prefs = await prefsWith(values);
      simulation = SimulatedFirstBooking(prefs);
    }

    test('notes a member who has bikes as not booked yet', () async {
      await startWith({});

      await simulation.prepare(statsOf(qty: 3));

      expect(FirstBookingGuide.isPending(prefs, 'M-001'), isTrue);
    });

    test('even one the phone had settled, so every launch starts at '
        '"never booked"', () async {
      await startWith({
        FirstBookingGuide.settledKey: ['M-001'],
      });

      await simulation.prepare(statsOf());

      expect(FirstBookingGuide.isPending(prefs, 'M-001'), isTrue);
      expect(prefs.containsKey(FirstBookingGuide.settledKey), isFalse);
    });

    test('and forgets the first-booking memory of anyone else', () async {
      await startWith({
        FirstBookingGuide.pendingKey: ['M-009'],
        FirstBookingGuide.settledKey: ['M-008'],
      });

      await simulation.prepare(statsOf());

      expect(prefs.getStringList(FirstBookingGuide.pendingKey), ['M-001']);
      expect(prefs.containsKey(FirstBookingGuide.settledKey), isFalse);
    });

    test('but touches nothing else on the phone', () async {
      await startWith({'theme_mode': 'dark', 'app_tour_seen': true});

      await simulation.prepare(statsOf());

      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getBool('app_tour_seen'), isTrue);
    });

    test('does not change the bike count: the point is a member who has '
        'bikes', () async {
      await startWith({});
      final real = statsOf(qty: 3);

      await simulation.prepare(real);

      expect(real.qty, 3);
    });

    test('a booking made afterwards settles them, and a reload does not note '
        'them again', () async {
      await startWith({});
      await simulation.prepare(statsOf());

      await FirstBookingGuide.settle(prefs, 'M-001');
      await simulation.prepare(statsOf());
      await simulation.prepare(statsOf(qty: 4));

      expect(FirstBookingGuide.isPending(prefs, 'M-001'), isFalse);
    });

    test('a different member is noted on their own', () async {
      await startWith({});
      await simulation.prepare(statsOf(memberId: 'M-001'));

      await simulation.prepare(statsOf(memberId: 'M-002'));

      expect(FirstBookingGuide.isPending(prefs, 'M-002'), isTrue);
    });

    test('after a reset (sign-out) the same member is noted again', () async {
      await startWith({});
      await simulation.prepare(statsOf());
      await FirstBookingGuide.settle(prefs, 'M-001');

      simulation.reset();
      await simulation.prepare(statsOf());

      expect(FirstBookingGuide.isPending(prefs, 'M-001'), isTrue);
    });

    test('overlapping loads of the same member note them once', () async {
      await startWith({});

      await Future.wait([
        simulation.prepare(statsOf()),
        simulation.prepare(statsOf()),
      ]);

      expect(prefs.getStringList(FirstBookingGuide.pendingKey), ['M-001']);
    });
  });
}
