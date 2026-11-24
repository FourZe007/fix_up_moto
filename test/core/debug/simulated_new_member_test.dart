import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/debug/simulated_new_member.dart';
import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_booking_guide.dart';

DashboardStatsEntity statsOf({
  String memberId = 'M-001',
  int qty = 3,
  String name = 'Test Member',
}) => DashboardStatsEntity(
  status: 'AKTIF',
  memberId: memberId,
  memberName: name,
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
    final remembered = <String, Object>{
      AppTourSeen.key: true,
      FieldGuideSeen.keyFor(FieldGuideId.addBike): true,
      FieldGuideSeen.keyFor(FieldGuideId.createBooking): true,
      FirstBookingGuide.pendingKey: ['M-001'],
      FirstBookingGuide.settledKey: ['M-002'],
      'theme_mode': 'dark',
    };

    test('is off by default', () async {
      final prefs = await prefsWith(remembered);

      expect(await SimulatedNewMember.start(prefs), isNull);
    });

    test('and then leaves what the phone remembers alone', () async {
      final prefs = await prefsWith(remembered);

      await SimulatedNewMember.start(prefs);

      expect(AppTourSeen.read(prefs), isTrue);
      expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isTrue);
      expect(FieldGuideSeen.read(prefs, FieldGuideId.createBooking), isTrue);
      expect(FirstBookingGuide.isPending(prefs, 'M-001'), isTrue);
    });

    test('is off in a release build, even when asked for', () async {
      final prefs = await prefsWith(remembered);

      final simulation = await SimulatedNewMember.start(
        prefs,
        enabled: true,
        release: true,
      );

      expect(simulation, isNull);
      expect(AppTourSeen.read(prefs), isTrue);
      expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isTrue);
      expect(FirstBookingGuide.isPending(prefs, 'M-001'), isTrue);
      expect(prefs.getStringList(FirstBookingGuide.settledKey), ['M-002']);
    });

    test('is on when asked for in a debug build', () async {
      final prefs = await prefsWith(remembered);

      final simulation = await SimulatedNewMember.start(
        prefs,
        enabled: true,
        release: false,
      );

      expect(simulation, isNotNull);
    });

    test(
      'and then makes the launch a first run: the guidance is forgotten',
      () {
        return prefsWith(remembered).then((prefs) async {
          await SimulatedNewMember.start(prefs, enabled: true, release: false);

          expect(AppTourSeen.read(prefs), isFalse);
          // So Add Bike's guide and Create Booking's play at every launch too.
          expect(FieldGuideSeen.read(prefs, FieldGuideId.addBike), isFalse);
          expect(
            FieldGuideSeen.read(prefs, FieldGuideId.createBooking),
            isFalse,
          );
          expect(prefs.containsKey(FirstBookingGuide.pendingKey), isFalse);
          expect(prefs.containsKey(FirstBookingGuide.settledKey), isFalse);
        });
      },
    );

    test('but touches nothing else on the phone', () async {
      final prefs = await prefsWith(remembered);

      await SimulatedNewMember.start(prefs, enabled: true, release: false);

      expect(prefs.getString('theme_mode'), 'dark');
    });
  });

  group('apply', () {
    late SimulatedNewMember simulation;

    setUp(() => simulation = SimulatedNewMember());

    test('hides the bikes the account already had', () {
      expect(simulation.apply(statsOf(qty: 3)).qty, 0);
    });

    test('changes nothing else about the member', () {
      final real = statsOf(qty: 3);

      final shown = simulation.apply(real);

      expect(shown.memberId, real.memberId);
      expect(shown.memberName, real.memberName);
      expect(shown.emailAddress, real.emailAddress);
      expect(shown.phoneNo, real.phoneNo);
      expect(shown.status, real.status);
      expect(shown.active, real.active);
      expect(shown.point, real.point);
      expect(shown.detail, real.detail);
      expect(shown.detail2, real.detail2);
    });

    test('an account with no bike stays at none', () {
      expect(simulation.apply(statsOf(qty: 0)).qty, 0);
    });

    test('a bike added afterwards counts, so the chain can carry on', () {
      simulation.apply(statsOf(qty: 3));

      expect(simulation.apply(statsOf(qty: 4)).qty, 1);
      expect(simulation.apply(statsOf(qty: 5)).qty, 2);
    });

    test('reloading the same stats keeps hiding the same bikes', () {
      simulation.apply(statsOf(qty: 3));

      expect(simulation.apply(statsOf(qty: 3)).qty, 0);
      expect(simulation.apply(statsOf(qty: 3)).qty, 0);
    });

    test('a bike deleted, then one added, still counts the added one', () {
      simulation.apply(statsOf(qty: 3));

      expect(simulation.apply(statsOf(qty: 2)).qty, 0);
      expect(simulation.apply(statsOf(qty: 3)).qty, 1);
    });

    test('a different member starts from their own count', () {
      simulation.apply(statsOf(memberId: 'M-001', qty: 3));

      expect(simulation.apply(statsOf(memberId: 'M-002', qty: 5)).qty, 0);
      expect(simulation.apply(statsOf(memberId: 'M-002', qty: 6)).qty, 1);
    });

    test('after a reset (sign-out) the next stats start from none again', () {
      simulation.apply(statsOf(qty: 3));
      simulation.apply(statsOf(qty: 4));

      simulation.reset();

      expect(simulation.apply(statsOf(qty: 4)).qty, 0);
    });
  });
}
