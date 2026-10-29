import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:fix_up_moto/features/invoices/data/models/invoice_model.dart';
import 'package:fix_up_moto/features/invoices/data/repositories/invoices_repository_impl.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';

class MockRemote extends Mock implements InvoicesRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockRemote remote;
  late MockNetworkInfo network;
  late MockAuthRepository auth;
  late InvoicesRepositoryImpl repository;

  const tUser = UserEntity(
    id: '0101202400000014',
    name: 'Test Member',
    status: 'AKTIF',
    isActive: true,
  );

  final tBegin = DateTime(2023, 1, 4);
  final tEnd = DateTime(2024, 12, 9);

  const tModel = InvoiceModel(
    workshopName: 'FIXUP MOTO - KUTISARI',
    transNo: 'A',
    transDate: '2024-09-16',
    voucherNo: '',
    voucherName: '',
    priceNett: 65000,
    discNett: 0,
    totalNett: 65000,
    lines: [],
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2024));
  });

  setUp(() {
    remote = MockRemote();
    network = MockNetworkInfo();
    auth = MockAuthRepository();
    repository = InvoicesRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
      authRepository: auth,
    );
  });

  void givenOnlineAndSignedIn() {
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(
      () => auth.getCurrentUser(),
    ).thenAnswer((_) async => const Right(tUser));
  }

  void givenRemote(Future<List<InvoiceModel>> Function() answer) {
    when(
      () => remote.getInvoices(
        memberId: any(named: 'memberId'),
        kode: any(named: 'kode'),
        beginDate: any(named: 'beginDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<Either<Failure, List<InvoiceEntity>>> get({
    InvoiceType type = InvoiceType.service,
  }) => repository.getInvoices(type: type, beginDate: tBegin, endDate: tEnd);

  test('returns the invoices as entities, in the order received', () async {
    givenOnlineAndSignedIn();
    givenRemote(() async => [tModel, tModel]);

    final result = await get();

    final invoices = result.getOrElse(() => []);
    expect(invoices, hasLength(2));
    expect(invoices.first.number, 'A');
    expect(invoices.first.total, 65000);
    expect(invoices.first.date, DateTime(2024, 9, 16));
  });

  test('asks for the signed-in member, the kind and the range', () async {
    givenOnlineAndSignedIn();
    givenRemote(() async => []);

    await get(type: InvoiceType.sparepart);

    verify(
      () => remote.getInvoices(
        memberId: '0101202400000014',
        kode: 'SPAREPART',
        beginDate: tBegin,
        endDate: tEnd,
      ),
    ).called(1);
  });

  test('offline is a NetworkFailure, and nothing is asked', () async {
    when(() => network.isConnected).thenAnswer((_) async => false);

    final result = await get();

    expect(result, const Left(NetworkFailure('No internet connection')));
    verifyNever(
      () => remote.getInvoices(
        memberId: any(named: 'memberId'),
        kode: any(named: 'kode'),
        beginDate: any(named: 'beginDate'),
        endDate: any(named: 'endDate'),
      ),
    );
  });

  test('no signed-in member is an AuthFailure', () async {
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(
      () => auth.getCurrentUser(),
    ).thenAnswer((_) async => const Right(null));

    final result = await get();

    expect(result, const Left(AuthFailure('No signed-in member found')));
  });

  test('a failure reading the session is passed on', () async {
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(
      () => auth.getCurrentUser(),
    ).thenAnswer((_) async => const Left(CacheFailure('broken')));

    final result = await get();

    expect(result, const Left(CacheFailure('broken')));
  });

  group('maps what the data source throws', () {
    test('401 to an AuthFailure', () async {
      givenOnlineAndSignedIn();
      givenRemote(() async => throw const UnauthorizedException());

      expect(
        (await get()).swap().getOrElse(() => throw 'x'),
        isA<AuthFailure>(),
      );
    });

    test('403 to a PermissionFailure', () async {
      givenOnlineAndSignedIn();
      givenRemote(() async => throw ForbiddenException());

      expect(
        (await get()).swap().getOrElse(() => throw 'x'),
        isA<PermissionFailure>(),
      );
    });

    test('404 to a NotFoundFailure', () async {
      givenOnlineAndSignedIn();
      givenRemote(() async => throw NotFoundException());

      expect(
        (await get()).swap().getOrElse(() => throw 'x'),
        isA<NotFoundFailure>(),
      );
    });

    test(
      'a server error to a ServerFailure with its message and code',
      () async {
        givenOnlineAndSignedIn();
        givenRemote(
          () async => throw ServerException(message: 'Gagal', statusCode: 500),
        );

        expect(
          await get(),
          const Left(ServerFailure('Gagal', statusCode: 500)),
        );
      },
    );
  });
}
