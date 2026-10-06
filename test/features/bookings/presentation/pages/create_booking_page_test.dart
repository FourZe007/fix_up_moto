import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/create_booking_page.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';

class MockBookingsBloc extends MockBloc<BookingsEvent, BookingsState>
    implements BookingsBloc {}

void main() {
  late DataRefreshCubit refreshCubit;
  late StreamController<BookingsState> states;

  setUp(() {
    refreshCubit = DataRefreshCubit();
    states = StreamController<BookingsState>();
  });

  tearDown(() async {
    await states.close();
    await sl.reset();
  });

  /// Opens the create page on top of a stand-in Bookings page, so a successful
  /// create can pop back to something.
  Future<void> openCreatePage(WidgetTester tester) async {
    final bloc = MockBookingsBloc();
    whenListen(bloc, states.stream, initialState: const BookingsInitial());
    sl.registerFactory<BookingsBloc>(() => bloc);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('bookings-tab')),
        ),
        GoRoute(path: '/create', builder: (_, _) => const CreateBookingPage()),
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: refreshCubit),
          BlocProvider(create: (_) => SelectedWorkshopCubit()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    unawaited(router.push('/create'));
    await tester.pumpAndSettle();
  }

  testWidgets('a successful booking tells the Bookings tab to reload', (
    tester,
  ) async {
    await openCreatePage(tester);
    expect(refreshCubit.state.kind, isNull);

    states.add(const BookingActionSuccess('Booking confirmed!'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, DataKind.bookings);
    // ...and goes back to the tab that is now reloading.
    expect(find.text('bookings-tab'), findsOneWidget);
  });

  testWidgets('a failed booking does not signal anything', (tester) async {
    await openCreatePage(tester);

    states.add(const BookingsError('Server down'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, isNull);
    // Still on the create page, with the error shown.
    expect(find.text('bookings-tab'), findsNothing);
    expect(find.text('Server down'), findsOneWidget);
  });
}
