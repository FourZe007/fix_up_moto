import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/membership/domain/usecases/redeem_reward_usecase.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_bloc.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_event.dart';
import 'package:fix_up_moto/features/membership/presentation/bloc/redeem_state.dart';

class MockRedeemRewardUseCase extends Mock implements RedeemRewardUseCase {}

void main() {
  late MockRedeemRewardUseCase redeemReward;

  const tEvent = RedeemRequested(pointId: 'B01', voucherName: 'GRATIS OLI');
  const tParams = RedeemRewardParams(pointId: 'B01');

  setUp(() {
    redeemReward = MockRedeemRewardUseCase();
    registerFallbackValue(tParams);
  });

  test('starts out idle', () {
    expect(
      RedeemBloc(redeemReward: redeemReward).state,
      const RedeemInitial(),
    );
  });

  blocTest<RedeemBloc, RedeemState>(
    'goes InProgress for that voucher, then Success naming it',
    build: () {
      when(() => redeemReward(tParams)).thenAnswer(
        (_) async => const Right('Berhasil'),
      );
      return RedeemBloc(redeemReward: redeemReward);
    },
    act: (bloc) => bloc.add(tEvent),
    expect: () => [
      const RedeemInProgress('B01'),
      const RedeemSuccess(voucherName: 'GRATIS OLI', message: 'Berhasil'),
    ],
    verify: (_) => verify(() => redeemReward(tParams)).called(1),
  );

  blocTest<RedeemBloc, RedeemState>(
    "goes InProgress, then Failure carrying the failure's message",
    build: () {
      when(() => redeemReward(tParams)).thenAnswer(
        (_) async => const Left(ServerFailure('Point tidak cukup')),
      );
      return RedeemBloc(redeemReward: redeemReward);
    },
    act: (bloc) => bloc.add(tEvent),
    expect: () => [
      const RedeemInProgress('B01'),
      const RedeemFailure('Point tidak cukup'),
    ],
  );

  blocTest<RedeemBloc, RedeemState>(
    'a second request while one is in flight is dropped, not sent twice',
    build: () {
      final answer = Completer<Either<Failure, String>>();
      when(() => redeemReward(tParams)).thenAnswer((_) => answer.future);
      // Completes a moment later, after the second request has been refused.
      Future<void>.delayed(
        const Duration(milliseconds: 50),
        () => answer.complete(const Right('Berhasil')),
      );
      return RedeemBloc(redeemReward: redeemReward);
    },
    act: (bloc) async {
      bloc.add(tEvent);
      await Future<void>.delayed(Duration.zero);
      bloc.add(tEvent);
    },
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const RedeemInProgress('B01'),
      const RedeemSuccess(voucherName: 'GRATIS OLI', message: 'Berhasil'),
    ],
    verify: (_) => verify(() => redeemReward(tParams)).called(1),
  );

  blocTest<RedeemBloc, RedeemState>(
    'after a claim finishes the member can claim again',
    build: () {
      when(() => redeemReward(any())).thenAnswer(
        (_) async => const Right('Berhasil'),
      );
      return RedeemBloc(redeemReward: redeemReward);
    },
    act: (bloc) async {
      bloc.add(tEvent);
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const RedeemRequested(pointId: 'B02', voucherName: 'DISKON'),
      );
    },
    expect: () => [
      const RedeemInProgress('B01'),
      const RedeemSuccess(voucherName: 'GRATIS OLI', message: 'Berhasil'),
      const RedeemInProgress('B02'),
      const RedeemSuccess(voucherName: 'DISKON', message: 'Berhasil'),
    ],
  );
}
