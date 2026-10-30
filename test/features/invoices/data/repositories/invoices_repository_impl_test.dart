import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:fix_up_moto/features/invoices/data/datasources/receipt_storage_data_source.dart';
import 'package:fix_up_moto/features/invoices/data/models/invoice_model.dart';
import 'package:fix_up_moto/features/invoices/data/repositories/invoices_repository_impl.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';

class MockRemote extends Mock implements InvoicesRemoteDataSource {}

class MockReceiptStorage extends Mock implements ReceiptStorageDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockRemote remote;
  late MockReceiptStorage storage;
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
    storage = MockReceiptStorage();
    network = MockNetworkInfo();
    auth = MockAuthRepository();
    repository = InvoicesRepositoryImpl(
      remoteDataSource: remote,
      receiptStorage: storage,
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

  group('downloadReceipt', () {
    final tPdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]);
    const tLocation = 'content://media/external/downloads/42';

    void givenReceiptFetched({String? savedAt = tLocation}) {
      when(
        () => remote.downloadReceipt(
          transId: any(named: 'transId'),
          transNo: any(named: 'transNo'),
        ),
      ).thenAnswer((_) async => tPdf);
      when(
        () => storage.savePdf(
          name: any(named: 'name'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((_) async => savedAt);
    }

    void givenRemoteThrows(Object error) {
      when(
        () => remote.downloadReceipt(
          transId: any(named: 'transId'),
          transNo: any(named: 'transNo'),
        ),
      ).thenThrow(error);
    }

    Future<Either<Failure, String?>> download({
      InvoiceType type = InvoiceType.service,
      String number = '3101SNT26100001',
    }) => repository.downloadReceipt(type: type, number: number);

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
    });

    test('fetches the receipt and saves it under the invoice number', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      givenReceiptFetched();

      expect(await download(), const Right(tLocation));

      verify(
        () =>
            remote.downloadReceipt(transId: 'SNT', transNo: '3101SNT26100001'),
      ).called(1);
      verify(
        () => storage.savePdf(name: '3101SNT26100001', bytes: tPdf),
      ).called(1);
    });

    test('a receipt saved where it cannot be opened has no location', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      givenReceiptFetched(savedAt: null);

      expect(await download(), const Right<Failure, String?>(null));
    });

    test('asks for PNT for a sparepart invoice', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      givenReceiptFetched();

      await download(type: InvoiceType.sparepart, number: '3101PNT26100002');

      verify(
        () =>
            remote.downloadReceipt(transId: 'PNT', transNo: '3101PNT26100002'),
      ).called(1);
    });

    test('needs no signed-in member', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      givenReceiptFetched();

      await download();

      verifyNever(() => auth.getCurrentUser());
    });

    test(
      'offline is a NetworkFailure, and nothing is asked or saved',
      () async {
        when(() => network.isConnected).thenAnswer((_) async => false);

        expect(
          await download(),
          const Left(NetworkFailure('No internet connection')),
        );

        verifyNever(
          () => remote.downloadReceipt(
            transId: any(named: 'transId'),
            transNo: any(named: 'transNo'),
          ),
        );
        verifyNever(
          () => storage.savePdf(
            name: any(named: 'name'),
            bytes: any(named: 'bytes'),
          ),
        );
      },
    );

    group('maps what the data sources throw', () {
      setUp(() {
        when(() => network.isConnected).thenAnswer((_) async => true);
      });

      test('a server error to a ServerFailure, and nothing is saved', () async {
        givenRemoteThrows(
          const ServerException(
            message: 'The receipt could not be downloaded',
            statusCode: 200,
          ),
        );

        expect(
          await download(),
          const Left(
            ServerFailure(
              'The receipt could not be downloaded',
              statusCode: 200,
            ),
          ),
        );
        verifyNever(
          () => storage.savePdf(
            name: any(named: 'name'),
            bytes: any(named: 'bytes'),
          ),
        );
      });

      test('404 to a NotFoundFailure', () async {
        givenRemoteThrows(NotFoundException());

        expect(
          (await download()).swap().getOrElse(() => throw 'x'),
          isA<NotFoundFailure>(),
        );
      });

      test('a save that fails to a CacheFailure', () async {
        when(
          () => remote.downloadReceipt(
            transId: any(named: 'transId'),
            transNo: any(named: 'transNo'),
          ),
        ).thenAnswer((_) async => tPdf);
        when(
          () => storage.savePdf(
            name: any(named: 'name'),
            bytes: any(named: 'bytes'),
          ),
        ).thenThrow(
          const CacheException(message: 'The receipt could not be saved'),
        );

        expect(
          await download(),
          const Left(CacheFailure('The receipt could not be saved')),
        );
      });
    });
  });

  group('openReceipt', () {
    const tLocation = 'content://media/external/downloads/42';

    test('shows the receipt where it was saved', () async {
      when(() => storage.openPdf(any())).thenAnswer((_) async {});

      expect(await repository.openReceipt(location: tLocation), isRight());

      verify(() => storage.openPdf(tLocation)).called(1);
    });

    test('needs no internet and no signed-in member', () async {
      when(() => storage.openPdf(any())).thenAnswer((_) async {});

      await repository.openReceipt(location: tLocation);

      verifyNever(() => network.isConnected);
      verifyNever(() => auth.getCurrentUser());
    });

    test('an app that cannot be found is a CacheFailure', () async {
      when(() => storage.openPdf(any())).thenThrow(
        const CacheException(message: 'No app was found to open the receipt'),
      );

      expect(
        await repository.openReceipt(location: tLocation),
        const Left(CacheFailure('No app was found to open the receipt')),
      );
    });
  });
}

Matcher isRight() => equals(const Right<Failure, Unit>(unit));
