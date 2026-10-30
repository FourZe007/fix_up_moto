import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/currency_formatter.dart';
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
  group('the amount badge', () {
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
