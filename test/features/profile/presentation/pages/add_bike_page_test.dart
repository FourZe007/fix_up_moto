import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/add_bike_page.dart';

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

void main() {
  late DataRefreshCubit refreshCubit;
  late StreamController<BikesState> states;

  setUp(() {
    refreshCubit = DataRefreshCubit();
    states = StreamController<BikesState>();
  });

  tearDown(() async {
    await states.close();
    await sl.reset();
  });

  /// Opens the add-bike page on top of a stand-in My Bikes page, returning the
  /// future that completes with whatever the page pops with.
  Future<Future<bool?>> openAddBikePage(WidgetTester tester) async {
    final bloc = MockBikesBloc();
    whenListen(bloc, states.stream, initialState: const BikesInitial());
    sl.registerFactory<BikesBloc>(() => bloc);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('my-bikes')),
        ),
        GoRoute(path: '/add', builder: (_, _) => const AddBikePage()),
      ],
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: refreshCubit,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    final result = router.push<bool>('/add');
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('adding a bike tells Home, Membership and Profile to reload', (
    tester,
  ) async {
    await openAddBikePage(tester);
    expect(refreshCubit.state.kind, isNull);

    states.add(const BikesAdded('Bike added successfully'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, DataKind.stats);
  });

  testWidgets('it still pops with true so My Bikes reloads its own list', (
    tester,
  ) async {
    final result = await openAddBikePage(tester);

    states.add(const BikesAdded('Bike added successfully'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect(find.text('my-bikes'), findsOneWidget);
  });

  testWidgets('a failed add does not signal anything', (tester) async {
    await openAddBikePage(tester);

    states.add(const BikesError('Server down'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, isNull);
    expect(find.text('my-bikes'), findsNothing);
  });
}
