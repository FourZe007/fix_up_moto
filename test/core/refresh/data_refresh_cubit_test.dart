import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/refresh/refresh_on.dart';

void main() {
  group('DataRefreshCubit', () {
    test('starts with nothing invalidated', () {
      final cubit = DataRefreshCubit();

      expect(cubit.state.kind, isNull);
      expect(cubit.state.version, 0);
    });

    blocTest<DataRefreshCubit, DataRefresh>(
      'invalidate emits the kind that went out of date',
      build: DataRefreshCubit.new,
      act: (cubit) => cubit.invalidate(DataKind.bookings),
      expect: () => [const DataRefresh(DataKind.bookings, 1)],
    );

    blocTest<DataRefreshCubit, DataRefresh>(
      'the same kind twice emits twice — the second must not be swallowed',
      build: DataRefreshCubit.new,
      act: (cubit) => cubit
        ..invalidate(DataKind.stats)
        ..invalidate(DataKind.stats),
      expect: () => [
        const DataRefresh(DataKind.stats, 1),
        const DataRefresh(DataKind.stats, 2),
      ],
    );
  });

  group('RefreshOn', () {
    late DataRefreshCubit cubit;
    late int refreshes;

    setUp(() {
      cubit = DataRefreshCubit();
      refreshes = 0;
    });

    Future<void> pump(WidgetTester tester, DataKind kind) => tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: RefreshOn(
          kind: kind,
          onRefresh: (_) => refreshes++,
          child: const SizedBox(),
        ),
      ),
    );

    testWidgets('runs when its own kind is invalidated', (tester) async {
      await pump(tester, DataKind.bookings);

      cubit.invalidate(DataKind.bookings);
      await tester.pump();

      expect(refreshes, 1);
    });

    testWidgets('ignores a different kind', (tester) async {
      await pump(tester, DataKind.bookings);

      cubit.invalidate(DataKind.stats);
      await tester.pump();

      expect(refreshes, 0);
    });

    testWidgets('runs every time, not just the first', (tester) async {
      await pump(tester, DataKind.stats);

      cubit.invalidate(DataKind.stats);
      await tester.pump();
      cubit.invalidate(DataKind.stats);
      await tester.pump();

      expect(refreshes, 2);
    });

    testWidgets('does nothing before anything is invalidated', (tester) async {
      await pump(tester, DataKind.stats);

      expect(refreshes, 0);
    });
  });
}
