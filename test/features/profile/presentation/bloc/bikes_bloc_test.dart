import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/add_bike_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/get_bikes_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/update_bike_usecase.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';

class MockGetBikesUseCase extends Mock implements GetBikesUseCase {}

class MockAddBikeUseCase extends Mock implements AddBikeUseCase {}

class MockUpdateBikeUseCase extends Mock implements UpdateBikeUseCase {}

void main() {
  late MockGetBikesUseCase getBikes;
  late MockAddBikeUseCase addBike;
  late MockUpdateBikeUseCase updateBike;

  const tParams = UpdateBikeParams(
    plateNo: 'L 1234 AB',
    unitId: 'YAMAHA R25',
    chasisNo: 'MH3RG1',
    engineNo: 'G3E1',
    color: 'Hitam',
    year: '2023',
    photo: '',
  );

  const tEvent = BikeUpdateRequested(
    plateNo: 'L 1234 AB',
    unitId: 'YAMAHA R25',
    chasisNo: 'MH3RG1',
    engineNo: 'G3E1',
    color: 'Hitam',
    year: '2023',
    photo: '',
  );

  setUpAll(() {
    registerFallbackValue(tParams);
    registerFallbackValue(const GetBikesParams());
  });

  setUp(() {
    getBikes = MockGetBikesUseCase();
    addBike = MockAddBikeUseCase();
    updateBike = MockUpdateBikeUseCase();
  });

  BikesBloc build() =>
      BikesBloc(getBikes: getBikes, addBike: addBike, updateBike: updateBike);

  group('BikeUpdateRequested', () {
    blocTest<BikesBloc, BikesState>(
      'emits Loading then Updated when the bike was saved',
      build: () {
        when(
          () => updateBike(any()),
        ).thenAnswer((_) async => const Right(null));
        return build();
      },
      act: (bloc) => bloc.add(tEvent),
      expect: () => [
        const BikesLoading(),
        const BikesUpdated('Bike updated successfully'),
      ],
      verify: (_) {
        // Every field of the event reaches the use case, plate included.
        verify(() => updateBike(tParams)).called(1);
      },
    );

    blocTest<BikesBloc, BikesState>(
      'does not reload the list itself — the page that opened it does',
      build: () {
        when(
          () => updateBike(any()),
        ).thenAnswer((_) async => const Right(null));
        return build();
      },
      act: (bloc) => bloc.add(tEvent),
      verify: (_) => verifyNever(() => getBikes(any())),
    );

    blocTest<BikesBloc, BikesState>(
      'emits Loading then Error with the failure\'s message when it fails',
      build: () {
        when(() => updateBike(any())).thenAnswer(
          (_) async => const Left(ServerFailure('Plat nomor tidak ditemukan')),
        );
        return build();
      },
      act: (bloc) => bloc.add(tEvent),
      expect: () => [
        const BikesLoading(),
        const BikesError('Plat nomor tidak ditemukan'),
      ],
    );
  });
}
