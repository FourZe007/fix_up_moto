import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/tour/app_tour_handoff.dart';

void main() {
  group('addFirstBike', () {
    const handoff = AppTourHandoff.addFirstBike;

    test('goes to Add Bike', () {
      expect(handoff.route, RouteNames.addBike);
    });

    test("opens it as the guidance's bike step, to offer a booking after", () {
      expect(handoff.extra, FirstTaskStep.addBike);
    });

    test('says why in a sentence, and what the button does', () {
      expect(handoff.message, contains('motor'));
      expect(handoff.message, contains('booking'));
      expect(handoff.acceptLabel, 'Tambah motor sekarang');
    });
  });

  group('addFirstBike is a task of its own kind', () {
    test('opens a page: Add Bike, with the bike icon', () {
      expect(AppTourHandoff.addFirstBike.task, AppTourHandoffTask.addBike);
      expect(AppTourHandoff.addFirstBike.icon, Icons.two_wheeler_outlined);
    });
  });

  group('bookFirstService', () {
    const handoff = AppTourHandoff.bookFirstService;

    test('starts a booking, not a plain page', () {
      expect(handoff.task, AppTourHandoffTask.bookService);
      // The workshop step makes it more than one route.
      expect(handoff.route, isNull);
      expect(handoff.extra, isNull);
    });

    test('says why in a sentence, and what the button does', () {
      expect(handoff.message, contains('booking'));
      expect(handoff.acceptLabel, 'Buat booking sekarang');
    });

    test("has the first-booking card's icon", () {
      expect(handoff.icon, Icons.event_available_outlined);
    });
  });

  group('forBikeCount with a first booking still to make', () {
    test('a member with a bike who has not booked is offered booking', () {
      expect(
        AppTourHandoff.forBikeCount(1, bookingPending: true),
        AppTourHandoff.bookFirstService,
      );
      expect(
        AppTourHandoff.forBikeCount(4, bookingPending: true),
        AppTourHandoff.bookFirstService,
      );
    });

    test('a member with no bike is offered the bike first, pending or not', () {
      expect(
        AppTourHandoff.forBikeCount(0, bookingPending: true),
        AppTourHandoff.addFirstBike,
      );
    });

    test('a member with a bike who is not pending is offered nothing', () {
      expect(AppTourHandoff.forBikeCount(2, bookingPending: false), isNull);
    });

    test('an unknown count is offered nothing, pending or not', () {
      expect(AppTourHandoff.forBikeCount(null, bookingPending: true), isNull);
    });
  });

  group('forBikeCount', () {
    test('a member with no bike is offered adding one', () {
      expect(AppTourHandoff.forBikeCount(0), AppTourHandoff.addFirstBike);
    });

    test('a negative count is treated as none', () {
      expect(AppTourHandoff.forBikeCount(-1), AppTourHandoff.addFirstBike);
    });

    test('a member with a bike is offered nothing', () {
      expect(AppTourHandoff.forBikeCount(1), isNull);
      expect(AppTourHandoff.forBikeCount(4), isNull);
    });

    test('an unknown count (stats not loaded) is offered nothing', () {
      expect(AppTourHandoff.forBikeCount(null), isNull);
    });
  });
}
