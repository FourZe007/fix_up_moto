import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/domain/usecases/get_services_usecase.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';

class MockGetServices extends Mock implements GetServicesUseCase {}

const tService = ServiceEntity(
  bsName: 'FIXUP MOTO - KUTISARI',
  transNo: '3101SNT26100001',
  transDate: '2026-10-05',
  eName: 'NURUL FAHMI AZIS',
  amountService: 60000,
  amountPart: 5000,
  detail: [],
  detail2: [],
);

void main() {
  late MockGetServices getServices;

  setUpAll(() => registerFallbackValue(const GetServicesParams(plateNo: 'X')));

  setUp(() => getServices = MockGetServices());

  ServicesBloc build() => ServicesBloc(getServices: getServices);

  group('ServicesListRequested', () {
    blocTest<ServicesBloc, ServicesState>(
      "asks for the event's plate, and loads what comes back",
      setUp: () => when(
        () => getServices(any()),
      ).thenAnswer((_) async => const Right([tService])),
      build: build,
      act: (bloc) =>
          bloc.add(const ServicesListRequested(plateNo: 'B 1234 XY')),
      expect: () => [
        const ServicesLoading(),
        const ServicesLoaded([tService]),
      ],
      verify: (_) {
        verify(
          () => getServices(const GetServicesParams(plateNo: 'B 1234 XY')),
        ).called(1);
      },
    );

    blocTest<ServicesBloc, ServicesState>(
      'asking again with another plate asks about that plate',
      setUp: () => when(
        () => getServices(any()),
      ).thenAnswer((_) async => const Right(<ServiceEntity>[])),
      build: build,
      act: (bloc) async {
        bloc.add(const ServicesListRequested(plateNo: 'B 1234 XY'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ServicesListRequested(plateNo: 'D 5678 CD'));
      },
      verify: (_) {
        verify(
          () => getServices(const GetServicesParams(plateNo: 'B 1234 XY')),
        ).called(1);
        verify(
          () => getServices(const GetServicesParams(plateNo: 'D 5678 CD')),
        ).called(1);
      },
    );

    blocTest<ServicesBloc, ServicesState>(
      'a failure becomes an error with its message',
      setUp: () => when(
        () => getServices(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('Gagal memuat'))),
      build: build,
      act: (bloc) =>
          bloc.add(const ServicesListRequested(plateNo: 'B 1234 XY')),
      expect: () => [
        const ServicesLoading(),
        const ServicesError('Gagal memuat'),
      ],
    );
  });

  group('ServicesRefreshRequested', () {
    const other = ServiceEntity(
      bsName: 'FIXUP MOTO - KEDUNG TARUKAN',
      transNo: 'T-NEW',
      transDate: '2026-11-01',
      eName: 'BUDI SANTOSO',
      amountService: 1000,
      amountPart: 0,
      detail: [],
      detail2: [],
    );

    blocTest<ServicesBloc, ServicesState>(
      'keeps the list on screen while it fetches, then swaps in the new one',
      setUp: () => when(
        () => getServices(any()),
      ).thenAnswer((_) async => const Right([tService, other])),
      build: build,
      seed: () => const ServicesLoaded([tService]),
      act: (bloc) =>
          bloc.add(const ServicesRefreshRequested(plateNo: 'B 1234 XY')),
      expect: () => [
        // No ServicesLoading: that would blank the list being pulled.
        const ServicesLoaded([tService], refreshing: true),
        const ServicesLoaded([tService, other]),
      ],
      verify: (_) {
        verify(
          () => getServices(const GetServicesParams(plateNo: 'B 1234 XY')),
        ).called(1);
      },
    );

    blocTest<ServicesBloc, ServicesState>(
      'still answers when nothing changed, which a pull indicator waits for',
      setUp: () => when(
        () => getServices(any()),
      ).thenAnswer((_) async => const Right([tService])),
      build: build,
      seed: () => const ServicesLoaded([tService]),
      act: (bloc) =>
          bloc.add(const ServicesRefreshRequested(plateNo: 'B 1234 XY')),
      expect: () => [
        const ServicesLoaded([tService], refreshing: true),
        // Equal list, yet a state of its own: without the refreshing flag this
        // would equal the one before the pull and the bloc would drop it.
        const ServicesLoaded([tService]),
      ],
    );

    blocTest<ServicesBloc, ServicesState>(
      'a failure becomes an error with its message',
      setUp: () => when(
        () => getServices(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('Gagal memuat'))),
      build: build,
      seed: () => const ServicesLoaded([tService]),
      act: (bloc) =>
          bloc.add(const ServicesRefreshRequested(plateNo: 'B 1234 XY')),
      expect: () => [
        const ServicesLoaded([tService], refreshing: true),
        const ServicesError('Gagal memuat'),
      ],
    );

    blocTest<ServicesBloc, ServicesState>(
      'with nothing on screen to keep, loads like an ordinary request',
      setUp: () => when(
        () => getServices(any()),
      ).thenAnswer((_) async => const Right([tService])),
      build: build,
      act: (bloc) =>
          bloc.add(const ServicesRefreshRequested(plateNo: 'B 1234 XY')),
      expect: () => [
        const ServicesLoading(),
        const ServicesLoaded([tService]),
      ],
    );

    blocTest<ServicesBloc, ServicesState>(
      "drops its answer when another bike's history took over meanwhile",
      setUp: () {
        final slow = Completer<Either<Failure, List<ServiceEntity>>>();
        when(
          () => getServices(const GetServicesParams(plateNo: 'B 1234 XY')),
        ).thenAnswer((_) => slow.future);
        when(
          () => getServices(const GetServicesParams(plateNo: 'D 5678 CD')),
        ).thenAnswer((_) async => const Right([other]));
        // The slow answer for the first bike lands after the second bike's.
        Future<void>.delayed(
          const Duration(milliseconds: 20),
          () => slow.complete(const Right([tService])),
        );
      },
      build: build,
      seed: () => const ServicesLoaded([tService]),
      act: (bloc) async {
        bloc.add(const ServicesRefreshRequested(plateNo: 'B 1234 XY'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ServicesListRequested(plateNo: 'D 5678 CD'));
      },
      wait: const Duration(milliseconds: 60),
      expect: () => [
        const ServicesLoaded([tService], refreshing: true),
        const ServicesLoading(),
        const ServicesLoaded([other]),
        // The first bike's late answer is not shown over the second's.
      ],
    );

    test('the same plate makes equal events, another plate does not', () {
      expect(
        const ServicesRefreshRequested(plateNo: 'B 1'),
        const ServicesRefreshRequested(plateNo: 'B 1'),
      );
      expect(
        const ServicesRefreshRequested(plateNo: 'B 1'),
        isNot(const ServicesRefreshRequested(plateNo: 'B 2')),
      );
    });

    test('is not the same event as a plain request', () {
      expect(
        const ServicesRefreshRequested(plateNo: 'B 1'),
        isNot(const ServicesListRequested(plateNo: 'B 1')),
      );
    });
  });

  test('the same plate makes equal events, another plate does not', () {
    expect(
      const ServicesListRequested(plateNo: 'B 1'),
      const ServicesListRequested(plateNo: 'B 1'),
    );
    expect(
      const ServicesListRequested(plateNo: 'B 1'),
      isNot(const ServicesListRequested(plateNo: 'B 2')),
    );
  });
}
