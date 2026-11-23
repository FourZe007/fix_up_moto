import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/bookings/presentation/guided_booking.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';

const kedungTarukan = WorkshopEntity(
  branch: '31',
  shop: '01',
  bsName: 'FIXUP MOTO - KEDUNG TARUKAN',
  bsAddress: 'JL. KUTISARI UTARA NO. 16A',
  operationalHours: 'Senin - Jumat 08.00 - 16.00',
  phoneNo: '0312345678',
  active: true,
  lat: -7.3,
  lng: 112.7,
);

void main() {
  late SelectedWorkshopCubit workshop;
  late GoRouter router;
  Object? formExtra;
  var formOpened = 0;

  setUp(() {
    workshop = SelectedWorkshopCubit();
    formExtra = null;
    formOpened = 0;
  });

  tearDown(() => workshop.close());

  /// A stand-in Home with the workshop list (answering with
  /// [kedungTarukan]) and the booking form (recording its extra) beside it.
  Future<void> pumpApp(WidgetTester tester) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: RouteNames.workshops,
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('workshop-list'),
                TextButton(
                  onPressed: () => context.pop(kedungTarukan),
                  child: const Text('Pilih bengkel'),
                ),
              ],
            ),
          ),
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
    unawaited(startGuidedBooking(router: router, workshop: workshop));
    await tester.pumpAndSettle();
  }

  testWidgets('with no workshop chosen it asks for one before the form', (
    tester,
  ) async {
    await pumpApp(tester);

    await start(tester);

    expect(find.text('workshop-list'), findsOneWidget);
    expect(find.text('booking-form'), findsNothing);
  });

  testWidgets(
    'the pick is kept as the app-wide workshop, then the form opens',
    (tester) async {
      await pumpApp(tester);
      await start(tester);

      await tester.tap(find.text('Pilih bengkel'));
      await tester.pumpAndSettle();

      expect(workshop.state, kedungTarukan);
      expect(find.text('booking-form'), findsOneWidget);
    },
  );

  testWidgets("the form is opened as the guidance's booking step", (
    tester,
  ) async {
    await pumpApp(tester);
    await start(tester);
    await tester.tap(find.text('Pilih bengkel'));
    await tester.pumpAndSettle();

    expect(formExtra, FirstTaskStep.createBooking);
  });

  testWidgets('with a workshop already chosen it goes straight to the form', (
    tester,
  ) async {
    workshop.select(kedungTarukan);
    await pumpApp(tester);

    await start(tester);

    expect(find.text('workshop-list'), findsNothing);
    expect(find.text('booking-form'), findsOneWidget);
    expect(formExtra, FirstTaskStep.createBooking);
  });

  testWidgets('backing out of the workshops stops there, and chooses nothing', (
    tester,
  ) async {
    await pumpApp(tester);
    await start(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(formOpened, 0);
    expect(workshop.state, isNull);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('back from the form returns to where the member was', (
    tester,
  ) async {
    workshop.select(kedungTarukan);
    await pumpApp(tester);
    await start(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('booking-form'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
