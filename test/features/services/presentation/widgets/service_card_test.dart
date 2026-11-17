import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/currency_formatter.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/presentation/widgets/service_card.dart';

ServiceEntity service({
  double amountService = 60000,
  double amountPart = 5000,
}) {
  return ServiceEntity(
    bsName: 'FIXUP MOTO - KUTISARI',
    transNo: '3101SNT26100001',
    transDate: '2026-10-05',
    eName: 'NURUL FAHMI AZIS',
    amountService: amountService,
    amountPart: amountPart,
    detail: const [],
    detail2: const [],
  );
}

Future<void> pumpCard(WidgetTester tester, ServiceEntity entity) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ServiceCard(service: entity)),
    ),
  );
}

void main() {
  group('the colours', () {
    Color? colorOf(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    testWidgets('a white surface with a warm hairline, not a black outline', (
      tester,
    ) async {
      await pumpCard(tester, service());

      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.peachHairline);
      expect(shape.side.color, isNot(Colors.black));
      expect(card.elevation, 0);
      expect(
        card.color,
        Theme.of(tester.element(find.byType(Card))).colorScheme.surface,
      );
    });

    testWidgets('the amount is plain brand-red text, not a tinted badge', (
      tester,
    ) async {
      await pumpCard(tester, service());

      final amount = find.text(CurrencyFormatter.rupiah(65000));
      expect(
        colorOf(tester, CurrencyFormatter.rupiah(65000)),
        AppColors.primaryDark,
      );
      // Nothing around it draws a fill or a border of its own.
      final boxes = find.ancestor(
        of: amount,
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration != null,
        ),
      );
      expect(boxes, findsNothing);
    });

    testWidgets('the date, the number and the mechanic are one soft grey', (
      tester,
    ) async {
      await pumpCard(tester, service());

      expect(colorOf(tester, '5 Oct 2026'), AppColors.grey700);
      expect(
        // The mechanic's name comes shouted from the server and is shown
        // title-cased; the transaction number is shown as sent.
        colorOf(tester, '3101SNT26100001 · Nurul Fahmi Azis'),
        AppColors.grey700,
      );
    });

    testWidgets('the title keeps the normal text colour', (tester) async {
      await pumpCard(tester, service());

      // Only the supporting detail is softened; the title is not.
      expect(colorOf(tester, 'KUTISARI'), isNot(AppColors.grey700));
      expect(colorOf(tester, 'KUTISARI'), isNot(AppColors.primaryDark));
    });

    testWidgets('the divider is the same warm hairline', (tester) async {
      await pumpCard(tester, service());

      expect(
        tester.widget<Divider>(find.byType(Divider)).color,
        AppColors.peachHairline,
      );
    });

    testWidgets('still opens when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceCard(service: service(), onTap: () => taps++),
          ),
        ),
      );

      await tester.tap(find.byType(ServiceCard));

      expect(taps, 1);
    });
  });

  group('the amount', () {
    testWidgets('shows what the service and the parts cost, in Rupiah', (
      tester,
    ) async {
      await pumpCard(tester, service());

      expect(find.text(CurrencyFormatter.rupiah(65000)), findsOneWidget);
    });

    testWidgets('never shows a peso sign or a bare number', (tester) async {
      await pumpCard(tester, service());

      expect(find.textContaining('₱'), findsNothing);
      expect(find.text('65000'), findsNothing);
    });

    testWidgets('rounds a fraction away, like the invoices do', (tester) async {
      await pumpCard(
        tester,
        service(amountService: 60000.4, amountPart: 4999.2),
      );

      expect(find.text(CurrencyFormatter.rupiah(65000)), findsOneWidget);
    });
  });
}
