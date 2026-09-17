import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/workshops/data/datasources/workshops_remote_data_source.dart';
import 'package:fix_up_moto/features/workshops/data/models/workshop_model.dart';
import 'package:fix_up_moto/features/workshops/data/repositories/workshops_repository_impl.dart';

/// Mocks of the data source and connectivity check. mocktail builds these at
/// runtime — no code generation, unlike the JSON models.
class MockWorkshopsRemoteDataSource extends Mock
    implements WorkshopsRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockWorkshopsRemoteDataSource mockRemote;
  late MockNetworkInfo mockNetworkInfo;
  late WorkshopsRepositoryImpl repository;

  const tWorkshopModel = WorkshopModel(
    branch: '31',
    shop: '01',
    bsName: 'FixUP MOTO - KUTISARI',
    bsAddress: 'Jl. Kutisari Utara No.16A',
    operationalHours: 'Senin - Sabtu: 09:00 - 17:00',
    phoneNo: '0812-3113-3383',
    active: true,
    lat: -7.3306082,
    lng: 112.7463137,
  );

  setUp(() {
    mockRemote = MockWorkshopsRemoteDataSource();
    mockNetworkInfo = MockNetworkInfo();
    repository = WorkshopsRepositoryImpl(
      remoteDataSource: mockRemote,
      networkInfo: mockNetworkInfo,
    );
  });

  /// Most tests assume the device is online; the offline test overrides this.
  void givenOnline() {
    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
  }

  group('getWorkshops', () {
    test('returns a list of entities when the call succeeds', () async {
      givenOnline();
      when(
        () => mockRemote.getWorkshops(),
      ).thenAnswer((_) async => [tWorkshopModel]);

      final result = await repository.getWorkshops();

      // Unwrapped first, then compared as a plain List — comparing two
      // Lists wrapped inside Right directly would use Right's own == on its
      // value, and plain List.== is identity-based, so two separately-built
      // (but element-wise identical) lists would report as different. A bare
      // List, on the other hand, gets matcher's element-wise comparison.
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('expected Right, got Left'),
        // Right holds the *entity*, not the model — the model never leaves
        // the data layer.
        (workshops) => expect(workshops, [tWorkshopModel.toEntity()]),
      );
    });

    test('returns NotFoundFailure when the endpoint answers 404', () async {
      givenOnline();
      when(
        () => mockRemote.getWorkshops(),
      ).thenThrow(const NotFoundException());

      final result = await repository.getWorkshops();

      expect(result, const Left(NotFoundFailure('Resource not found')));
    });

    test('returns AuthFailure when the endpoint answers 401', () async {
      givenOnline();
      when(
        () => mockRemote.getWorkshops(),
      ).thenThrow(const UnauthorizedException());

      final result = await repository.getWorkshops();

      expect(
        result,
        const Left(AuthFailure('Session expired. Please sign in again.')),
      );
    });

    test('returns PermissionFailure when the endpoint answers 403', () async {
      givenOnline();
      when(
        () => mockRemote.getWorkshops(),
      ).thenThrow(const ForbiddenException());

      final result = await repository.getWorkshops();

      expect(result, const Left(PermissionFailure('Access denied')));
    });

    test('returns ServerFailure for any other server error', () async {
      givenOnline();
      when(() => mockRemote.getWorkshops()).thenThrow(
        const ServerException(
          message: 'Internal Server Error',
          statusCode: 500,
        ),
      );

      final result = await repository.getWorkshops();

      expect(
        result,
        const Left(ServerFailure('Internal Server Error', statusCode: 500)),
      );
    });

    test(
      'returns NetworkFailure without calling the remote source when offline',
      () async {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.getWorkshops();

        expect(result, const Left(NetworkFailure('No internet connection')));
        verifyNever(() => mockRemote.getWorkshops());
      },
    );
  });
}
