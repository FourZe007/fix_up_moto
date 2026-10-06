import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/bookings_page.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';

class MockBookingsBloc extends MockBloc<BookingsEvent, BookingsState>
    implements BookingsBloc {}

class MockServicesBloc extends MockBloc<ServicesEvent, ServicesState>
    implements ServicesBloc {}

late DataRefreshCubit refreshCubit;

Future<MockBookingsBloc> pumpBookings(WidgetTester tester) async {
  final bookings = MockBookingsBloc();
  whenListen(
    bookings,
    const Stream<BookingsState>.empty(),
    initialState: const BookingsLoaded([]),
  );
  sl.registerFactory<BookingsBloc>(() => bookings);

  final services = MockServicesBloc();
  whenListen(
    services,
    const Stream<ServicesState>.empty(),
    initialState: const ServicesInitial(),
  );
  sl.registerFactory<ServicesBloc>(() => services);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: refreshCubit,
        child: const BookingsPage(),
      ),
    ),
  );
  return bookings;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      BookingsListRequested(
        range: DateTimeRange(start: DateTime(2026), end: DateTime(2026)),
      ),
    );
  });
  setUp(() => refreshCubit = DataRefreshCubit());
  tearDown(() => sl.reset());

  testWidgets('loads the bookings for its date range when the page opens', (
    tester,
  ) async {
    final bloc = await pumpBookings(tester);

    verify(() => bloc.add(any(that: isA<BookingsListRequested>()))).called(1);
  });

  testWidgets('reloads straight away when a booking is created elsewhere', (
    tester,
  ) async {
    final bloc = await pumpBookings(tester);

    // The create page signals this after a booking succeeds; this tab is alive
    // underneath, so it reloads without anyone opening it.
    refreshCubit.invalidate(DataKind.bookings);
    await tester.pump();

    // Once on open, once for the signal.
    verify(() => bloc.add(any(that: isA<BookingsListRequested>()))).called(2);
  });

  testWidgets('reloads with the same date range it was showing', (
    tester,
  ) async {
    final bloc = await pumpBookings(tester);

    refreshCubit.invalidate(DataKind.bookings);
    await tester.pump();

    final requests = verify(
      () => bloc.add(captureAny(that: isA<BookingsListRequested>())),
    ).captured.cast<BookingsListRequested>();
    expect(requests, hasLength(2));
    expect(requests[1].range, requests[0].range);
  });

  testWidgets('ignores stats going out of date', (tester) async {
    final bloc = await pumpBookings(tester);

    refreshCubit.invalidate(DataKind.stats);
    await tester.pump();

    verify(() => bloc.add(any(that: isA<BookingsListRequested>()))).called(1);
  });
}
