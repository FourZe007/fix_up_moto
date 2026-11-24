import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/bookings/presentation/guided_booking.dart';

void main() {
  late GoRouter router;
  Object? formExtra;
  var formOpened = 0;
  var workshopListOpened = 0;

  setUp(() {
    formExtra = null;
    formOpened = 0;
    workshopListOpened = 0;
  });

  /// A stand-in Home with the booking form (recording its extra) beside it. The
  /// workshop list is there too, only to count how often anything opens it.
  Future<void> pumpApp(WidgetTester tester) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: RouteNames.workshops,
          builder: (_, _) {
            workshopListOpened++;
            return const Scaffold(body: Text('workshop-list'));
          },
        ),
        GoRoute(
          path: RouteNames.createBooking,
          builder: (_, state) {
            formExtra = state.extra;
            formOpened++;
            return const Scaffold(body: Text('booking-form'));
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  Future<void> start(WidgetTester tester) async {
    unawaited(startGuidedBooking(router: router));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the booking form straight away', (tester) async {
    await pumpApp(tester);

    await start(tester);

    expect(find.text('booking-form'), findsOneWidget);
    expect(formOpened, 1);
  });

  testWidgets('with no workshop list in front of it', (tester) async {
    await pumpApp(tester);

    await start(tester);

    // The form chooses a workshop itself (the first open one).
    expect(find.text('workshop-list'), findsNothing);
    expect(workshopListOpened, 0);
  });

  testWidgets("opens the form as the guidance's booking step", (tester) async {
    await pumpApp(tester);

    await start(tester);

    // So that once the booking is made it points to the Booking tab.
    expect(formExtra, FirstTaskStep.createBooking);
  });

  testWidgets('back from the form returns to where the member was', (
    tester,
  ) async {
    await pumpApp(tester);
    await start(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('booking-form'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('can be started again after coming back', (tester) async {
    await pumpApp(tester);
    await start(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await start(tester);

    expect(formOpened, 2);
    expect(find.text('booking-form'), findsOneWidget);
  });
}
