import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/domain/usecases/get_dashboard_stats_usecase.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';

class MockGetDashboardStats extends Mock implements GetDashboardStatsUseCase {}

const tStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'First Answer',
  emailAddress: 'a@example.com',
  phoneNo: '81234567890',
  active: true,
  qty: 1,
  point: 10,
  detail: [],
  detail2: [],
);

const tNewerStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Newer Answer',
  emailAddress: 'a@example.com',
  phoneNo: '81234567890',
  active: true,
  qty: 2,
  point: 20,
  detail: [],
  detail2: [],
);

const tFailure = ServerFailure('Server down');

void main() {
  late MockGetDashboardStats getStats;

  setUp(() => getStats = MockGetDashboardStats());

  HomeBloc build() => HomeBloc(getDashboardStats: getStats);

  group('the first load', () {
    blocTest<HomeBloc, HomeState>(
      'shows a spinner, then the stats',
      build: () {
        when(() => getStats()).thenAnswer((_) async => const Right(tStats));
        return build();
      },
      act: (bloc) => bloc.add(const HomeStatsRequested()),
      expect: () => [const HomeLoading(), const HomeLoaded(tStats)],
    );

    blocTest<HomeBloc, HomeState>(
      'a failure is shown as an error: there is nothing to fall back on',
      build: () {
        when(() => getStats()).thenAnswer((_) async => const Left(tFailure));
        return build();
      },
      act: (bloc) => bloc.add(const HomeStatsRequested()),
      expect: () => [const HomeLoading(), const HomeError('Server down')],
    );

    blocTest<HomeBloc, HomeState>(
      'a Retry after an error shows the spinner again',
      build: () {
        when(() => getStats()).thenAnswer((_) async => const Right(tStats));
        return build();
      },
      seed: () => const HomeError('Server down'),
      act: (bloc) => bloc.add(const HomeStatsRequested()),
      expect: () => [const HomeLoading(), const HomeLoaded(tStats)],
    );
  });

  group('a reload while stats are on screen', () {
    blocTest<HomeBloc, HomeState>(
      'keeps them up as refreshing — never a spinner — then swaps in the answer',
      build: () {
        when(
          () => getStats(),
        ).thenAnswer((_) async => const Right(tNewerStats));
        return build();
      },
      seed: () => const HomeLoaded(tStats),
      act: (bloc) => bloc.add(const HomeStatsRequested()),
      expect: () => [
        const HomeLoaded(tStats, refreshing: true),
        const HomeLoaded(tNewerStats),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'still emits when the answer is the same stats, so a pull can end',
      build: () {
        when(() => getStats()).thenAnswer((_) async => const Right(tStats));
        return build();
      },
      seed: () => const HomeLoaded(tStats),
      act: (bloc) => bloc.add(const HomeStatsRequested()),
      expect: () => [
        const HomeLoaded(tStats, refreshing: true),
        const HomeLoaded(tStats),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'a failed reload keeps the old stats instead of an error page',
      build: () {
        when(() => getStats()).thenAnswer((_) async => const Left(tFailure));
        return build();
      },
      seed: () => const HomeLoaded(tStats),
      act: (bloc) => bloc.add(const HomeStatsRequested()),
      expect: () => [
        const HomeLoaded(tStats, refreshing: true),
        const HomeLoaded(tStats),
      ],
    );
  });

  group('signing out', () {
    blocTest<HomeBloc, HomeState>(
      'forgets the stats',
      build: build,
      seed: () => const HomeLoaded(tStats),
      act: (bloc) => bloc.add(const HomeResetRequested()),
      expect: () => [const HomeInitial()],
    );

    test('drops an answer that arrives after the reset', () async {
      final answer = Completer<Either<Failure, DashboardStatsEntity>>();
      when(() => getStats()).thenAnswer((_) => answer.future);
      final bloc = build();
      final states = <HomeState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const HomeStatsRequested());
      await pumpEventQueue();
      // The member signs out while the request is still on its way...
      bloc.add(const HomeResetRequested());
      await pumpEventQueue();
      // ...and the answer for that member arrives afterwards.
      answer.complete(const Right(tStats));
      await pumpEventQueue();

      expect(states, [const HomeLoading(), const HomeInitial()]);
      expect(bloc.state, const HomeInitial());

      await sub.cancel();
      await bloc.close();
    });
  });

  group('overlapping requests', () {
    test('the latest wins, even when an older answer arrives last', () async {
      final first = Completer<Either<Failure, DashboardStatsEntity>>();
      final second = Completer<Either<Failure, DashboardStatsEntity>>();
      final answers = [first, second];
      when(() => getStats()).thenAnswer((_) => answers.removeAt(0).future);
      final bloc = build();

      bloc.add(const HomeStatsRequested());
      await pumpEventQueue();
      bloc.add(const HomeStatsRequested());
      await pumpEventQueue();

      // The newer request answers first, then the older one limps in.
      second.complete(const Right(tNewerStats));
      await pumpEventQueue();
      first.complete(const Right(tStats));
      await pumpEventQueue();

      expect(bloc.state, const HomeLoaded(tNewerStats));
      verify(() => getStats()).called(2);

      await bloc.close();
    });
  });
}
