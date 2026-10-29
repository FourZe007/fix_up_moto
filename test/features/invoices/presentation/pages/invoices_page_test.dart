import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_event.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_state.dart';
import 'package:fix_up_moto/features/invoices/presentation/pages/invoices_page.dart';
import 'package:fix_up_moto/features/invoices/presentation/widgets/invoice_card.dart';

class MockInvoicesBloc extends MockBloc<InvoicesEvent, InvoicesState>
    implements InvoicesBloc {}

const tService = InvoiceEntity(
  number: '3101SNT24090303',
  workshopName: 'FIXUP MOTO - KUTISARI',
  date: null,
  voucherNo: '',
  voucherName: '',
  subtotal: 65000,
  discount: 0,
  total: 65000,
  lines: [
    InvoiceLineEntity(
      code: 'S-REG-OTH',
      name: 'SERVICE LAIN-LAIN',
      note: 'CHEMICAL CLEANING',
      quantity: 0,
      price: 5000,
      discount: 0,
    ),
    InvoiceLineEntity(
      code: 'SRV-061',
      name: 'TUNE UP PAKET',
      note: 'PERAWATAN BERKALA (PAKET SERVICE)',
      quantity: 0,
      price: 60000,
      discount: 0,
    ),
  ],
);

final tServiceDated = InvoiceEntity(
  number: tService.number,
  workshopName: tService.workshopName,
  date: DateTime(2024, 9, 16),
  voucherNo: '',
  voucherName: '',
  subtotal: tService.subtotal,
  discount: 0,
  total: tService.total,
  lines: tService.lines,
);

const tPart = InvoiceEntity(
  number: 'SPR-0001',
  workshopName: 'FIXUP MOTO - KUTISARI',
  date: null,
  voucherNo: 'V-001',
  voucherName: 'DISKON OLI',
  subtotal: 70000,
  discount: 10000,
  total: 60000,
  lines: [
    InvoiceLineEntity(
      code: 'P-1',
      name: 'BUSI',
      note: '',
      quantity: 2,
      price: 70000,
      discount: 10000,
    ),
  ],
);

/// The blocs the page asked the container for, in the order it did: the
/// Servis tab first, the Sparepart tab when it is first shown.
late List<MockInvoicesBloc> blocs;

/// Pumps the page with a mock bloc per tab: [servis] for the first, [sparepart]
/// for the second.
Future<void> pumpPage(
  WidgetTester tester, {
  InvoicesState servis = const InvoicesLoaded([]),
  InvoicesState sparepart = const InvoicesLoaded([]),
}) async {
  blocs = [];
  sl.registerFactory<InvoicesBloc>(() {
    final bloc = MockInvoicesBloc();
    whenListen(
      bloc,
      const Stream<InvoicesState>.empty(),
      initialState: blocs.isEmpty ? servis : sparepart,
    );
    blocs.add(bloc);
    return bloc;
  });

  await tester.pumpWidget(const MaterialApp(home: InvoicesPage()));
}

/// Today and the same day a year ago, as the page opens on them.
({DateTime begin, DateTime end}) lastTwelveMonths() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return (begin: DateTime(today.year - 1, today.month, today.day), end: today);
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      InvoicesRequested(
        type: InvoiceType.service,
        beginDate: DateTime(2024),
        endDate: DateTime(2024),
      ),
    );
  });
  tearDown(() => sl.reset());

  final spinner = find.byType(CircularProgressIndicator);

  testWidgets('shows the title and the two tabs', (tester) async {
    await pumpPage(tester);

    expect(find.text('Riwayat Invoice'), findsOneWidget);
    expect(find.text('Servis'), findsOneWidget);
    expect(find.text('Sparepart'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('asks for the service invoices of the last twelve months', (
    tester,
  ) async {
    await pumpPage(tester);

    final range = lastTwelveMonths();
    expect(blocs, hasLength(1), reason: 'the Sparepart tab is not built yet');
    verify(
      () => blocs.single.add(
        InvoicesRequested(
          type: InvoiceType.service,
          beginDate: range.begin,
          endDate: range.end,
        ),
      ),
    ).called(1);
  });

  testWidgets('the Sparepart tab asks for its own kind when first shown', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Sparepart'));
    await tester.pumpAndSettle();

    final range = lastTwelveMonths();
    expect(blocs, hasLength(2));
    verify(
      () => blocs.last.add(
        InvoicesRequested(
          type: InvoiceType.sparepart,
          beginDate: range.begin,
          endDate: range.end,
        ),
      ),
    ).called(1);
  });

  testWidgets('switching back does not ask the Servis tab again', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Sparepart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Servis'));
    await tester.pumpAndSettle();

    expect(blocs, hasLength(2), reason: 'no third bloc');
    verify(() => blocs.first.add(any())).called(1);
  });

  testWidgets('the date range under the tabs reads as the last twelve months', (
    tester,
  ) async {
    await pumpPage(tester);

    final chip = tester.widget<ActionChip>(
      find.byKey(const Key('invoices-range-chip')),
    );
    final label = (chip.label as Text).data!;
    expect(
      label,
      matches(RegExp(r'^\d{1,2} \w{3} \d{4} - \d{1,2} \w{3} \d{4}$')),
    );
  });

  testWidgets('tapping the range opens the picker in Bahasa Indonesia', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('invoices-range-chip')));
    await tester.pumpAndSettle();

    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    expect(find.text('Pilih rentang tanggal'), findsOneWidget);

    // Closing it without choosing changes nothing and reloads nothing.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsNothing);
    verify(() => blocs.single.add(any())).called(1);
  });

  group('loading and failing', () {
    for (final state in [const InvoicesInitial(), const InvoicesLoading()]) {
      testWidgets('${state.runtimeType} shows a spinner and no invoices', (
        tester,
      ) async {
        await pumpPage(tester, servis: state);

        expect(spinner, findsOneWidget);
        expect(find.byType(InvoiceCard), findsNothing);
        expect(find.text('Belum ada invoice servis'), findsNothing);
      });
    }

    testWidgets('an error shows its message and Coba lagi asks again', (
      tester,
    ) async {
      await pumpPage(tester, servis: const InvoicesError('Server error'));

      expect(find.text('Server error'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('invoices-retry-SERVICE')));
      await tester.pump();

      final range = lastTwelveMonths();
      verify(
        () => blocs.single.add(
          InvoicesRequested(
            type: InvoiceType.service,
            beginDate: range.begin,
            endDate: range.end,
          ),
        ),
      ).called(2);
    });

    testWidgets('no invoices says so, for each kind', (tester) async {
      await pumpPage(tester);

      expect(find.text('Belum ada invoice servis'), findsOneWidget);

      await tester.tap(find.text('Sparepart'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada invoice sparepart'), findsOneWidget);
    });

    testWidgets('each tab fails on its own', (tester) async {
      await pumpPage(
        tester,
        servis: const InvoicesError('Server error'),
        sparepart: InvoicesLoaded([tPart]),
      );
      expect(find.text('Server error'), findsOneWidget);

      await tester.tap(find.text('Sparepart'));
      await tester.pumpAndSettle();

      expect(find.text('SPR-0001'), findsOneWidget);
      expect(find.text('Server error'), findsNothing);
    });
  });

  group('an invoice card', () {
    testWidgets('shows its number, date, workshop and total', (tester) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      expect(find.text('3101SNT24090303'), findsOneWidget);
      expect(find.text('16 Sep 2024'), findsOneWidget);
      // Shouted capitals re-cased for reading.
      expect(find.text('Fixup Moto - Kutisari'), findsOneWidget);
      expect(find.text('Rp 65.000'), findsOneWidget);
    });

    testWidgets('lists the newest first, as the bloc handed them over', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated, tPart]));

      expect(find.byType(InvoiceCard), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('3101SNT24090303')).dy,
        lessThan(tester.getTopLeft(find.text('SPR-0001')).dy),
      );
    });

    testWidgets('keeps its lines closed until tapped, then opens and closes', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      expect(find.text('Tune Up Paket'), findsNothing);

      await tester.tap(find.text('3101SNT24090303'));
      await tester.pumpAndSettle();

      expect(find.text('Tune Up Paket'), findsOneWidget);
      expect(find.text('Perawatan Berkala (Paket Service)'), findsOneWidget);
      expect(find.text('Service Lain-Lain'), findsOneWidget);
      expect(find.text('Rp 60.000'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      // No discount, no voucher: neither is mentioned.
      expect(find.text('Diskon'), findsNothing);
      expect(find.textContaining('Voucher'), findsNothing);

      await tester.tap(find.text('3101SNT24090303'));
      await tester.pumpAndSettle();

      expect(find.text('Tune Up Paket'), findsNothing);
    });

    testWidgets('shows a part\'s count, its discount and the voucher', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tPart]));

      await tester.tap(find.text('SPR-0001'));
      await tester.pumpAndSettle();

      expect(find.text('2 x Busi'), findsOneWidget);
      expect(find.text('Diskon'), findsOneWidget);
      expect(find.text('Voucher: Diskon Oli'), findsOneWidget);
      expect(find.text('Rp 60.000'), findsWidgets);
    });

    testWidgets('has an Unduh Struk button that is shown but not pressable', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated, tPart]));

      for (final invoice in [tServiceDated, tPart]) {
        final button = find.byKey(InvoiceCard.downloadKeyFor(invoice));
        expect(button, findsOneWidget);
        expect(
          find.descendant(of: button, matching: find.text('Unduh Struk')),
          findsOneWidget,
        );
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      }
    });

    testWidgets('does nothing when the disabled button is tapped', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      await tester.tap(
        find.byKey(InvoiceCard.downloadKeyFor(tServiceDated)),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(InvoiceCard), findsOneWidget);
    });
  });

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    // A test that overflows fails on its own: Flutter reports it as an error.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPage(tester, servis: InvoicesLoaded([tServiceDated, tPart]));
    await tester.tap(find.text('3101SNT24090303'));
    await tester.pumpAndSettle();

    expect(find.byType(InvoiceCard), findsWidgets);
  });
}
