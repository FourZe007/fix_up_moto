import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/domain/usecases/get_invoices_usecase.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_event.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_state.dart';

class MockGetInvoicesUseCase extends Mock implements GetInvoicesUseCase {}

InvoiceEntity invoice(String number, DateTime? date) => InvoiceEntity(
  number: number,
  workshopName: 'FIXUP MOTO',
  date: date,
  voucherNo: '',
  voucherName: '',
  subtotal: 1000,
  discount: 0,
  total: 1000,
  lines: const [],
);

void main() {
  late MockGetInvoicesUseCase getInvoices;

  final tBegin = DateTime(2023, 10, 29);
  final tEnd = DateTime(2024, 10, 29);

  InvoicesRequested request([InvoiceType type = InvoiceType.service]) =>
      InvoicesRequested(type: type, beginDate: tBegin, endDate: tEnd);

  setUp(() {
    getInvoices = MockGetInvoicesUseCase();
    registerFallbackValue(
      GetInvoicesParams(
        type: InvoiceType.service,
        beginDate: tBegin,
        endDate: tEnd,
      ),
    );
  });

  test('starts out with nothing requested', () {
    expect(
      InvoicesBloc(getInvoices: getInvoices).state,
      const InvoicesInitial(),
    );
  });

  blocTest<InvoicesBloc, InvoicesState>(
    'asks for the kind and range of the event, and emits Loading then Loaded',
    build: () {
      when(
        () => getInvoices(any()),
      ).thenAnswer((_) async => Right([invoice('A', DateTime(2024, 9, 16))]));
      return InvoicesBloc(getInvoices: getInvoices);
    },
    act: (bloc) => bloc.add(request(InvoiceType.sparepart)),
    expect: () => [
      const InvoicesLoading(),
      InvoicesLoaded([invoice('A', DateTime(2024, 9, 16))]),
    ],
    verify: (_) => verify(
      () => getInvoices(
        GetInvoicesParams(
          type: InvoiceType.sparepart,
          beginDate: tBegin,
          endDate: tEnd,
        ),
      ),
    ).called(1),
  );

  blocTest<InvoicesBloc, InvoicesState>(
    'puts the newest invoice first and one with no date last',
    build: () {
      when(() => getInvoices(any())).thenAnswer(
        (_) async => Right([
          invoice('old', DateTime(2024, 1, 1)),
          invoice('none', null),
          invoice('new', DateTime(2024, 9, 16)),
          invoice('old-too', DateTime(2024, 1, 1)),
        ]),
      );
      return InvoicesBloc(getInvoices: getInvoices);
    },
    act: (bloc) => bloc.add(request()),
    expect: () => [
      const InvoicesLoading(),
      isA<InvoicesLoaded>().having(
        (s) => s.invoices.map((i) => i.number).toList(),
        'numbers',
        ['new', 'old', 'old-too', 'none'],
      ),
    ],
  );

  blocTest<InvoicesBloc, InvoicesState>(
    'no invoices is an empty Loaded, not an error',
    build: () {
      when(() => getInvoices(any())).thenAnswer((_) async => const Right([]));
      return InvoicesBloc(getInvoices: getInvoices);
    },
    act: (bloc) => bloc.add(request()),
    expect: () => [const InvoicesLoading(), const InvoicesLoaded([])],
  );

  blocTest<InvoicesBloc, InvoicesState>(
    'emits Loading then Error with the failure message',
    build: () {
      when(() => getInvoices(any())).thenAnswer(
        (_) async => const Left(NetworkFailure('No internet connection')),
      );
      return InvoicesBloc(getInvoices: getInvoices);
    },
    act: (bloc) => bloc.add(request()),
    expect: () => [
      const InvoicesLoading(),
      const InvoicesError('No internet connection'),
    ],
  );
}
