import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/home/presentation/pages/home_page.dart';

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

late DataRefreshCubit refreshCubit;

/// Pumped in the loading state, which is just a spinner: the reload wiring
/// doesn't depend on what the loaded page contains, and the loaded page pulls
/// in the promo carousel and workshop picker.
Future<MockHomeBloc> pumpHome(WidgetTester tester) async {
  final home = MockHomeBloc();
  whenListen(
    home,
    const Stream<HomeState>.empty(),
    initialState: const HomeLoading(),
  );
  sl.registerFactory<HomeBloc>(() => home);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(value: refreshCubit, child: const HomePage()),
    ),
  );
  return home;
}

void main() {
  setUp(() => refreshCubit = DataRefreshCubit());
  tearDown(() => sl.reset());

  testWidgets('asks for the stats when the page opens', (tester) async {
    final home = await pumpHome(tester);

    verify(() => home.add(const HomeStatsRequested())).called(1);
  });

  testWidgets('reloads when the stats go out of date elsewhere', (
    tester,
  ) async {
    final home = await pumpHome(tester);

    refreshCubit.invalidate(DataKind.stats);
    await tester.pump();

    // Once on open, once for the signal.
    verify(() => home.add(const HomeStatsRequested())).called(2);
  });

  testWidgets('ignores bookings going out of date', (tester) async {
    final home = await pumpHome(tester);

    refreshCubit.invalidate(DataKind.bookings);
    await tester.pump();

    verify(() => home.add(const HomeStatsRequested())).called(1);
  });
}
