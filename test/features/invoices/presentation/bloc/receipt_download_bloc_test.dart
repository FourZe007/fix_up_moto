import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/domain/usecases/download_receipt_usecase.dart';
import 'package:fix_up_moto/features/invoices/domain/usecases/open_receipt_usecase.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/receipt_download_bloc.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/receipt_download_event.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/receipt_download_state.dart';

class MockDownloadReceiptUseCase extends Mock
    implements DownloadReceiptUseCase {}

class MockOpenReceiptUseCase extends Mock implements OpenReceiptUseCase {}

void main() {
  late MockDownloadReceiptUseCase downloadReceipt;
  late MockOpenReceiptUseCase openReceipt;

  const tRequest = ReceiptDownloadRequested(
    type: InvoiceType.service,
    number: '3101SNT26100001',
  );
  const tLocation = 'content://media/external/downloads/42';

  ReceiptDownloadBloc buildBloc() => ReceiptDownloadBloc(
    downloadReceipt: downloadReceipt,
    openReceipt: openReceipt,
  );

  setUp(() {
    downloadReceipt = MockDownloadReceiptUseCase();
    openReceipt = MockOpenReceiptUseCase();
    registerFallbackValue(
      const DownloadReceiptParams(type: InvoiceType.service, number: 'A'),
    );
    registerFallbackValue(const OpenReceiptParams(location: 'A'));
  });

  test('starts out with nothing downloaded', () {
    expect(buildBloc().state, const ReceiptDownloadInitial());
  });

  group('downloading', () {
    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'asks for the kind and number of the event, and emits Downloading then '
      'Downloaded with where it was saved',
      build: () {
        when(
          () => downloadReceipt(any()),
        ).thenAnswer((_) async => const Right(tLocation));
        return buildBloc();
      },
      act: (bloc) => bloc.add(tRequest),
      expect: () => const [
        ReceiptDownloading('3101SNT26100001'),
        ReceiptDownloaded('3101SNT26100001', location: tLocation),
      ],
      verify: (_) {
        verify(
          () => downloadReceipt(
            const DownloadReceiptParams(
              type: InvoiceType.service,
              number: '3101SNT26100001',
            ),
          ),
        ).called(1);
      },
    );

    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'a receipt saved where it cannot be opened again has no location',
      build: () {
        when(
          () => downloadReceipt(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(tRequest),
      expect: () => const [
        ReceiptDownloading('3101SNT26100001'),
        ReceiptDownloaded('3101SNT26100001'),
      ],
    );

    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'a sparepart invoice is asked for as a sparepart',
      build: () {
        when(
          () => downloadReceipt(any()),
        ).thenAnswer((_) async => const Right(tLocation));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const ReceiptDownloadRequested(
          type: InvoiceType.sparepart,
          number: '3101PNT26100002',
        ),
      ),
      verify: (_) {
        verify(
          () => downloadReceipt(
            const DownloadReceiptParams(
              type: InvoiceType.sparepart,
              number: '3101PNT26100002',
            ),
          ),
        ).called(1);
      },
    );

    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'emits Downloading then Failed with the failure\'s message',
      build: () {
        when(() => downloadReceipt(any())).thenAnswer(
          (_) async =>
              const Left(CacheFailure('The receipt could not be saved')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(tRequest),
      expect: () => const [
        ReceiptDownloading('3101SNT26100001'),
        ReceiptDownloadFailed('The receipt could not be saved'),
      ],
    );

    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'ignores a second request while one is on its way',
      build: () {
        final completer = Completer<Either<Failure, String?>>();
        when(() => downloadReceipt(any())).thenAnswer((_) => completer.future);
        return buildBloc();
      },
      act: (bloc) {
        bloc
          ..add(tRequest)
          ..add(
            const ReceiptDownloadRequested(
              type: InvoiceType.service,
              number: '3101SNT26100099',
            ),
          );
      },
      expect: () => const [ReceiptDownloading('3101SNT26100001')],
      verify: (_) {
        verify(() => downloadReceipt(any())).called(1);
      },
    );

    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'the same receipt can be downloaded again once it has finished',
      build: () {
        when(
          () => downloadReceipt(any()),
        ).thenAnswer((_) async => const Right(tLocation));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(tRequest);
        await Future<void>.delayed(Duration.zero);
        bloc.add(tRequest);
      },
      expect: () => const [
        ReceiptDownloading('3101SNT26100001'),
        ReceiptDownloaded('3101SNT26100001', location: tLocation),
        ReceiptDownloading('3101SNT26100001'),
        ReceiptDownloaded('3101SNT26100001', location: tLocation),
      ],
    );
  });

  group('opening', () {
    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'opens the receipt where it was saved, and says nothing when it opens',
      build: () {
        when(
          () => openReceipt(any()),
        ).thenAnswer((_) async => const Right(unit));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ReceiptOpenRequested(tLocation)),
      expect: () => const <ReceiptDownloadState>[],
      verify: (_) {
        verify(
          () => openReceipt(const OpenReceiptParams(location: tLocation)),
        ).called(1);
      },
    );

    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'emits OpenFailed with the failure\'s message when nothing can open it',
      build: () {
        when(() => openReceipt(any())).thenAnswer(
          (_) async =>
              const Left(CacheFailure('No app was found to open the receipt')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ReceiptOpenRequested(tLocation)),
      expect: () => const [
        ReceiptOpenFailed('No app was found to open the receipt'),
      ],
    );

    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'a receipt that will not open does not end a download still on its way',
      build: () {
        final completer = Completer<Either<Failure, String?>>();
        when(() => downloadReceipt(any())).thenAnswer((_) => completer.future);
        when(() => openReceipt(any())).thenAnswer(
          (_) async =>
              const Left(CacheFailure('No app was found to open the receipt')),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(tRequest);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ReceiptOpenRequested(tLocation));
      },
      expect: () => const [ReceiptDownloading('3101SNT26100001')],
      verify: (_) {
        verify(() => openReceipt(any())).called(1);
      },
    );

    blocTest<ReceiptDownloadBloc, ReceiptDownloadState>(
      'a new download can start after a receipt would not open',
      build: () {
        when(() => openReceipt(any())).thenAnswer(
          (_) async =>
              const Left(CacheFailure('No app was found to open the receipt')),
        );
        when(
          () => downloadReceipt(any()),
        ).thenAnswer((_) async => const Right(tLocation));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const ReceiptOpenRequested(tLocation));
        await Future<void>.delayed(Duration.zero);
        bloc.add(tRequest);
      },
      expect: () => const [
        ReceiptOpenFailed('No app was found to open the receipt'),
        ReceiptDownloading('3101SNT26100001'),
        ReceiptDownloaded('3101SNT26100001', location: tLocation),
      ],
    );
  });
}
