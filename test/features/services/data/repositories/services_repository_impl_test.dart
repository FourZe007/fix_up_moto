import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/services/data/datasources/services_remote_data_source.dart';
import 'package:fix_up_moto/features/services/data/models/service_model.dart';
import 'package:fix_up_moto/features/services/data/repositories/services_repository_impl.dart';

class MockRemote extends Mock implements ServicesRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

const tModel = ServiceModel(
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
  late MockRemote remote;
  late MockNetworkInfo networkInfo;
  late ServicesRepositoryImpl repository;

  setUp(() {
    remote = MockRemote();
    networkInfo = MockNetworkInfo();
    repository = ServicesRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: networkInfo,
    );
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
  });

  void stubServices(Future<List<ServiceModel>> Function() answer) {
    when(
      () => remote.getServices(
        serviceType: any(named: 'serviceType'),
        plateNo: any(named: 'plateNo'),
      ),
    ).thenAnswer((_) => answer());
  }

  group('getServices', () {
    test('hands the plate on to the data source, untouched', () async {
      stubServices(() async => [tModel]);

      final result = await repository.getServices(plateNo: 'B 1234 XY');

      verify(
        () => remote.getServices(
          serviceType: 'SERVICEHISTORY',
          plateNo: 'B 1234 XY',
        ),
      ).called(1);
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected a list'),
        (list) => expect(list.single.transNo, '3101SNT26100001'),
      );
    });

    test('with no connection it fails without asking the backend', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.getServices(plateNo: 'B 1234 XY');

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(
        () => remote.getServices(
          serviceType: any(named: 'serviceType'),
          plateNo: any(named: 'plateNo'),
        ),
      );
    });

    test("a refused request becomes the server's own failure", () async {
      stubServices(
        () async => throw ServerException(message: 'Gagal', statusCode: 500),
      );

      final result = await repository.getServices(plateNo: 'B 1234 XY');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected a failure'),
      );
    });
  });
}
