import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/helpers/currency_formatter.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/presentation/pages/service_detail_page.dart';

const tService = ServiceEntity(
  bsName: 'FIXUP MOTO - KUTISARI',
  transNo: '3101SNT26100001',
  transDate: '2026-10-05',
  eName: 'NURUL FAHMI AZIS',
  amountService: 60000,
  amountPart: 5000,
  detail: [
    ServiceLineDetailEntity(
      serviceId: 'S1',
      serviceName: 'GANTI OLI MESIN',
      serviceNote: 'Oli 1 liter',
    ),
    ServiceLineDetailEntity(
      serviceId: 'S2',
      serviceName: 'CEK REM',
      serviceNote: '   ',
    ),
  ],
  detail2: [
    ServicePartDetailEntity(unitId: 'U1', itemName: 'OLI MESIN', qty: 2),
  ],
);

/// A visit with nothing but what the test sets: no lines, no parts, no money.
ServiceEntity visit({
  String bsName = 'FIXUP MOTO - KUTISARI',
  String transNo = 'T-1',
  String transDate = '2026-10-05',
  String eName = 'NURUL FAHMI AZIS',
  double amountService = 0,
  double amountPart = 0,
  List<ServiceLineDetailEntity> detail = const [],
  List<ServicePartDetailEntity> detail2 = const [],
}) => ServiceEntity(
  bsName: bsName,
  transNo: transNo,
  transDate: transDate,
  eName: eName,
  amountService: amountService,
  amountPart: amountPart,
  detail: detail,
  detail2: detail2,
);

/// Opens the page on [service] and nothing else: no bloc, no service locator.
/// The page loads nothing, so there is nothing to register or fake — if it ever
/// reached for either, these tests would throw.
Future<void> pumpDetail(
  WidgetTester tester, {
  ServiceEntity service = tService,
}) async {
  await tester.pumpWidget(
    MaterialApp(home: ServiceDetailPage(service: service)),
  );
}

/// Where the letters of [text] are drawn. A Text's own rect is the whole space
/// it was given, so it cannot tell a right-aligned value from a left-aligned
/// one.
Rect inked(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final origin = paragraph.localToGlobal(Offset.zero);
  return paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      )
      .map((box) => box.toRect().shift(origin))
      .reduce((a, b) => a.expandToInclude(b));
}

/// The visit's card: the nearest Material around its number.
Rect cardRect(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.text('3101SNT26100001'),
        matching: find.byType(Material),
      )
      .first,
);

void main() {
  final rupiah = CurrencyFormatter.rupiah;

  group('what it shows', () {
    testWidgets('the number as it was sent and the date, short, in Bahasa', (
      tester,
    ) async {
      await pumpDetail(tester);

      expect(find.text('3101SNT26100001'), findsOneWidget);
      expect(find.text('5 Okt 2026'), findsOneWidget);
      expect(find.text('2026-10-05'), findsNothing);
    });

    testWidgets('the branch and the mechanic, each capital only on its first '
        'letter', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Fixup Moto - Kutisari'), findsOneWidget);
      expect(find.text('Mekanik: Nurul Fahmi Azis'), findsOneWidget);
      // The server sends them shouted; they are not shown that way.
      expect(find.textContaining('NURUL'), findsNothing);
      expect(find.textContaining('KUTISARI'), findsNothing);
    });

    testWidgets('leaves a mechanic name that is already cased as it is', (
      tester,
    ) async {
      await pumpDetail(tester, service: visit(eName: 'Budi McDonald'));

      expect(find.text('Mekanik: Budi McDonald'), findsOneWidget);
    });

    testWidgets('the service lines, with a note only when there is one', (
      tester,
    ) async {
      await pumpDetail(tester);

      expect(find.text('Ganti Oli Mesin'), findsOneWidget);
      expect(find.text('Oli 1 liter'), findsOneWidget);
      expect(find.text('Cek Rem'), findsOneWidget);
      // The second line's note is only blanks, so nothing is drawn for it.
      expect(find.text('   '), findsNothing);
    });

    testWidgets('the parts, with their quantity in front', (tester) async {
      await pumpDetail(tester);

      expect(find.text('2 x Oli Mesin'), findsOneWidget);
    });

    testWidgets('a service line has no count in front of it', (tester) async {
      await pumpDetail(tester);

      expect(find.textContaining(' x Ganti'), findsNothing);
      expect(find.textContaining(' x Cek'), findsNothing);
    });

    testWidgets('is there on the very first frame: nothing is loaded', (
      tester,
    ) async {
      // pumpWidget builds exactly one frame; had the page waited on a load it
      // would show a spinner here instead of the record.
      await pumpDetail(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Fixup Moto - Kutisari'), findsOneWidget);
    });

    testWidgets('says so when the visit has no lines and no parts', (
      tester,
    ) async {
      await pumpDetail(tester, service: visit());

      expect(find.text('Tidak ada rincian'), findsOneWidget);
    });

    testWidgets('does not say so when it has lines', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Tidak ada rincian'), findsNothing);
    });

    testWidgets('shows the record it was given, not another', (tester) async {
      await pumpDetail(
        tester,
        service: visit(
          bsName: 'FIXUP MOTO - KEDUNG TARUKAN',
          transNo: 'T-OTHER',
          transDate: '2026-03-10',
          eName: 'BUDI SANTOSO',
          amountService: 1000,
        ),
      );

      expect(find.text('Fixup Moto - Kedung Tarukan'), findsOneWidget);
      expect(find.text('T-OTHER'), findsOneWidget);
      expect(find.text('10 Mar 2026'), findsOneWidget);
      expect(find.text('Fixup Moto - Kutisari'), findsNothing);
    });
  });

  group('the header', () {
    testWidgets('has the number on the left and the date on the right', (
      tester,
    ) async {
      await pumpDetail(tester);
      final card = cardRect(tester);

      final number = inked(tester, '3101SNT26100001');
      final date = inked(tester, '5 Okt 2026');

      expect(number.left, closeTo(card.left + 14, 1));
      expect(date.right, closeTo(card.right - 14, 0.5));
      expect(number.right, lessThan(date.left));
      // Same line.
      expect(number.center.dy, closeTo(date.center.dy, 2));
    });

    testWidgets('shows a date that cannot be read as it came', (tester) async {
      await pumpDetail(tester, service: visit(transDate: 'kemarin'));

      expect(find.text('kemarin'), findsOneWidget);
    });

    testWidgets('is a card, with no chips', (tester) async {
      await pumpDetail(tester);

      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('keeps a long number from pushing the date out of the card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(300, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDetail(
        tester,
        service: visit(
          transNo: '3101SNT26100001-3101SNT26100001-3101SNT26100001',
        ),
      );

      expect(tester.takeException(), isNull);
      final card = tester.getRect(
        find
            .ancestor(
              of: find.text('5 Okt 2026'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(inked(tester, '5 Okt 2026').right, lessThanOrEqualTo(card.right));
    });
  });

  group('the money', () {
    /// The row of the sum named [label], whatever the amount beside it.
    Finder sumRow(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(Row)).first;

    testWidgets('the total is the service plus the parts, in Rupiah, in the '
        'header and again as the last sum', (tester) async {
      await pumpDetail(tester);

      expect(find.text(rupiah(65000)), findsNWidgets(2));
    });

    testWidgets('the sums are the service and the parts', (tester) async {
      await pumpDetail(tester);

      expect(
        find.descendant(of: sumRow('Jasa'), matching: find.text(rupiah(60000))),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sumRow('Suku cadang'),
          matching: find.text(rupiah(5000)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('puts each amount at the far end of its row', (tester) async {
      await pumpDetail(tester);
      final card = cardRect(tester);

      final label = inked(tester, 'Jasa');
      final amount = inked(tester, rupiah(60000));

      expect(label.left, closeTo(card.left + 14, 1));
      expect(amount.right, closeTo(card.right - 14, 1));
    });

    testWidgets('leaves out the parts sum when no parts were charged', (
      tester,
    ) async {
      await pumpDetail(tester, service: visit(amountService: 40000));

      expect(find.text('Jasa'), findsOneWidget);
      expect(find.text('Suku cadang'), findsNothing);
      expect(find.text(rupiah(40000)), findsNWidgets(3));
    });

    testWidgets('leaves out the service sum when no service was charged', (
      tester,
    ) async {
      await pumpDetail(tester, service: visit(amountPart: 15000));

      expect(find.text('Jasa'), findsNothing);
      expect(find.text('Suku cadang'), findsOneWidget);
    });

    testWidgets('has no peso sign', (tester) async {
      await pumpDetail(tester);

      expect(find.textContaining('₱'), findsNothing);
    });
  });

  group('Book Again', () {
    testWidgets('opens the booking form', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const ServiceDetailPage(service: tService),
          ),
          GoRoute(
            path: RouteNames.createBooking,
            builder: (_, _) => const Scaffold(body: Text('booking-form')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(find.text('Book Again'));
      await tester.pumpAndSettle();

      expect(find.text('booking-form'), findsOneWidget);
    });
  });
}
