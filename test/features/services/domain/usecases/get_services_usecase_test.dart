import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/domain/repositories/services_repository.dart';
import 'package:fix_up_moto/features/services/domain/usecases/get_services_usecase.dart';

class MockServicesRepository extends Mock implements ServicesRepository {}

void main() {
  late MockServicesRepository repository;
  late GetServicesUseCase useCase;

  setUp(() {
    repository = MockServicesRepository();
    useCase = GetServicesUseCase(repository);
    when(
      () => repository.getServices(
        serviceType: any(named: 'serviceType'),
        plateNo: any(named: 'plateNo'),
      ),
    ).thenAnswer((_) async => const Right(<ServiceEntity>[]));
  });

  test('forwards the plate to the repository', () async {
    // It used to be dropped here, so the repository never heard which bike.
    await useCase(const GetServicesParams(plateNo: 'B 1234 XY'));

    verify(
      () => repository.getServices(
        serviceType: 'SERVICEHISTORY',
        plateNo: 'B 1234 XY',
      ),
    ).called(1);
  });

  test('forwards another plate, not a remembered one', () async {
    await useCase(const GetServicesParams(plateNo: 'D 5678 CD'));

    verify(
      () => repository.getServices(
        serviceType: 'SERVICEHISTORY',
        plateNo: 'D 5678 CD',
      ),
    ).called(1);
  });

  test('params with the same plate are equal, different plates are not', () {
    expect(
      const GetServicesParams(plateNo: 'B 1'),
      const GetServicesParams(plateNo: 'B 1'),
    );
    expect(
      const GetServicesParams(plateNo: 'B 1'),
      isNot(const GetServicesParams(plateNo: 'B 2')),
    );
  });
}
