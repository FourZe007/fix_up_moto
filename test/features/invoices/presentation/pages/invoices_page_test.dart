import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_event.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/invoices_state.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/receipt_download_bloc.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/receipt_download_event.dart';
import 'package:fix_up_moto/features/invoices/presentation/bloc/receipt_download_state.dart';
import 'package:fix_up_moto/features/invoices/presentation/pages/invoices_page.dart';
import 'package:fix_up_moto/features/invoices/presentation/widgets/invoice_card.dart';

class MockInvoicesBloc extends MockBloc<InvoicesEvent, InvoicesState>
    implements InvoicesBloc {}

class MockReceiptDownloadBloc
    extends MockBloc<ReceiptDownloadEvent, ReceiptDownloadState>
    implements ReceiptDownloadBloc {}

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

/// The one bloc that downloads receipts for both tabs, and the stream a test
/// pushes its states through.
late MockReceiptDownloadBloc receipts;
late StreamController<ReceiptDownloadState> receiptStates;

/// Pumps the page with a mock bloc per tab: [servis] for the first, [sparepart]
/// for the second. [receipt] is the state the download bloc starts in.
Future<void> pumpPage(
  WidgetTester tester, {
  InvoicesState servis = const InvoicesLoaded([]),
  InvoicesState sparepart = const InvoicesLoaded([]),
  ReceiptDownloadState receipt = const ReceiptDownloadInitial(),
}) async {
  receipts = MockReceiptDownloadBloc();
  receiptStates = StreamController<ReceiptDownloadState>.broadcast();
  addTearDown(receiptStates.close);
  whenListen(receipts, receiptStates.stream, initialState: receipt);
  sl.registerFactory<ReceiptDownloadBloc>(() => receipts);

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
  });

  group('Unduh Struk', () {
    final button = find.byKey(InvoiceCard.downloadKeyFor(tServiceDated));

    testWidgets('is on every card, and can be pressed', (tester) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated, tPart]));

      for (final invoice in [tServiceDated, tPart]) {
        final button = find.byKey(InvoiceCard.downloadKeyFor(invoice));
        expect(button, findsOneWidget);
        expect(
          find.descendant(of: button, matching: find.text('Unduh Struk')),
          findsOneWidget,
        );
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('asks to download that invoice as a service receipt', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      await tester.tap(button);
      await tester.pump();

      verify(
        () => receipts.add(
          const ReceiptDownloadRequested(
            type: InvoiceType.service,
            number: '3101SNT24090303',
          ),
        ),
      ).called(1);
    });

    testWidgets('asks for a sparepart receipt from the Sparepart tab', (
      tester,
    ) async {
      await pumpPage(tester, sparepart: InvoicesLoaded([tPart]));

      await tester.tap(find.text('Sparepart'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(InvoiceCard.downloadKeyFor(tPart)));
      await tester.pump();

      verify(
        () => receipts.add(
          const ReceiptDownloadRequested(
            type: InvoiceType.sparepart,
            number: 'SPR-0001',
          ),
        ),
      ).called(1);
    });

    testWidgets('spins on the card being downloaded and holds the others', (
      tester,
    ) async {
      await pumpPage(
        tester,
        servis: InvoicesLoaded([tServiceDated, tPart]),
        receipt: const ReceiptDownloading('3101SNT24090303'),
      );

      expect(
        find.descendant(of: button, matching: find.text('Mengunduh...')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

      // The other card keeps its label but cannot start a second download.
      final other = find.byKey(InvoiceCard.downloadKeyFor(tPart));
      expect(
        find.descendant(of: other, matching: find.text('Unduh Struk')),
        findsOneWidget,
      );
      expect(tester.widget<OutlinedButton>(other).onPressed, isNull);
    });

    testWidgets('goes back to a pressable button when the download ends', (
      tester,
    ) async {
      await pumpPage(
        tester,
        servis: InvoicesLoaded([tServiceDated]),
        receipt: const ReceiptDownloading('3101SNT24090303'),
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

      receiptStates.add(const ReceiptDownloaded('3101SNT24090303'));
      await tester.pump();

      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(find.text('Unduh Struk'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a saved receipt says so in a snackbar', (tester) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));
      expect(find.byType(SnackBar), findsNothing);

      receiptStates.add(const ReceiptDownloaded('3101SNT24090303'));
      await tester.pump();

      expect(
        find.text('Struk 3101SNT24090303 tersimpan di folder Download.'),
        findsOneWidget,
      );
    });

    testWidgets('a receipt that can be opened offers Buka beside the message', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      receiptStates.add(
        const ReceiptDownloaded(
          '3101SNT24090303',
          location: 'content://media/external/downloads/42',
        ),
      );
      await tester.pump();

      expect(
        find.text('Struk 3101SNT24090303 tersimpan di folder Download.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.widgetWithText(SnackBarAction, 'Buka'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pressing Buka asks to open the receipt where it was saved', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));
      receiptStates.add(
        const ReceiptDownloaded(
          '3101SNT24090303',
          location: 'content://media/external/downloads/42',
        ),
      );
      // Settled, so the snackbar has slid up into view to be tapped.
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buka'));
      await tester.pump();

      verify(
        () => receipts.add(
          const ReceiptOpenRequested('content://media/external/downloads/42'),
        ),
      ).called(1);
    });

    testWidgets('a receipt that cannot be opened offers no Buka', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      receiptStates.add(const ReceiptDownloaded('3101SNT24090303'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
      expect(find.text('Buka'), findsNothing);
    });

    testWidgets('no app to open the receipt says so in Indonesian', (
      tester,
    ) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      receiptStates.add(
        const ReceiptOpenFailed('No app was found to open the receipt'),
      );
      await tester.pump();

      expect(
        find.text(
          'Tidak ada aplikasi untuk membuka PDF. Struk ada di folder Download',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a new download takes the last snackbar down', (tester) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));
      receiptStates.add(
        const ReceiptDownloaded(
          '3101SNT24090303',
          location: 'content://media/external/downloads/42',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      receiptStates.add(const ReceiptDownloading('3101SNT24090303'));
      // Not pumpAndSettle: the card's spinner never stops.
      await tester.pump();
      // The first timed frame starts the slide down, the second finishes it.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failure shows its message in Indonesian', (tester) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      receiptStates.add(
        const ReceiptDownloadFailed('The receipt could not be downloaded'),
      );
      await tester.pump();

      expect(find.text('Struk tidak dapat diunduh'), findsOneWidget);
    });

    testWidgets('a failure nobody translated shows as it came', (tester) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      receiptStates.add(const ReceiptDownloadFailed('Something odd'));
      await tester.pump();

      expect(find.text('Something odd'), findsOneWidget);
    });

    testWidgets('starting a download shows no snackbar', (tester) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      receiptStates.add(const ReceiptDownloading('3101SNT24090303'));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('closes its bloc when the page goes', (tester) async {
      await pumpPage(tester, servis: InvoicesLoaded([tServiceDated]));

      await tester.pumpWidget(const SizedBox());

      verify(() => receipts.close()).called(1);
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
