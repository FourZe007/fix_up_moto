import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/membership/domain/entities/reward_entity.dart';
import 'package:fix_up_moto/features/membership/domain/usecases/get_rewards_usecase.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_bloc.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_event.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/rewards_state.dart';

class MockGetRewardsUseCase extends Mock implements GetRewardsUseCase {}

void main() {
  late MockGetRewardsUseCase getRewards;

  const tRewards = [
    RewardEntity(
      pointId: 'C01',
      pointName: 'DISKON JASA SERVICE Rp. 20.000,00',
      pointQty: 100,
    ),
  ];

  setUp(() => getRewards = MockGetRewardsUseCase());

  test('starts out with nothing requested', () {
    expect(
      RewardsBloc(getRewards: getRewards).state,
      const RewardsInitial(),
    );
  });

  blocTest<RewardsBloc, RewardsState>(
    'emits Loading then Loaded with the rewards on success',
    build: () {
      when(() => getRewards()).thenAnswer((_) async => const Right(tRewards));
      return RewardsBloc(getRewards: getRewards);
    },
    act: (bloc) => bloc.add(const RewardsRequested()),
    expect: () => [const RewardsLoading(), const RewardsLoaded(tRewards)],
    verify: (_) => verify(() => getRewards()).called(1),
  );

  blocTest<RewardsBloc, RewardsState>(
    'emits Loading then Loaded with an empty list when there are no rewards',
    build: () {
      when(() => getRewards()).thenAnswer((_) async => const Right([]));
      return RewardsBloc(getRewards: getRewards);
    },
    act: (bloc) => bloc.add(const RewardsRequested()),
    expect: () => [const RewardsLoading(), const RewardsLoaded([])],
  );

  blocTest<RewardsBloc, RewardsState>(
    "emits Loading then Error carrying the failure's message",
    build: () {
      when(() => getRewards()).thenAnswer(
        (_) async => const Left(NetworkFailure('No internet connection')),
      );
      return RewardsBloc(getRewards: getRewards);
    },
    act: (bloc) => bloc.add(const RewardsRequested()),
    expect: () => [
      const RewardsLoading(),
      const RewardsError('No internet connection'),
    ],
  );

  blocTest<RewardsBloc, RewardsState>(
    'a second request (Retry / pull-to-refresh) loads again',
    build: () {
      when(() => getRewards()).thenAnswer((_) async => const Right(tRewards));
      return RewardsBloc(getRewards: getRewards);
    },
    act: (bloc) async {
      bloc.add(const RewardsRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const RewardsRequested());
    },
    expect: () => [
      const RewardsLoading(),
      const RewardsLoaded(tRewards),
      const RewardsLoading(),
      const RewardsLoaded(tRewards),
    ],
    verify: (_) => verify(() => getRewards()).called(2),
  );
}
