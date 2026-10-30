import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/currency_formatter.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';
import 'package:fix_up_moto/features/services/presentation/pages/service_detail_page.dart';

class MockServicesBloc extends MockBloc<ServicesEvent, ServicesState>
    implements ServicesBloc {}

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
      serviceNote: '',
    ),
  ],
  detail2: [
    ServicePartDetailEntity(unitId: 'U1', itemName: 'OLI MESIN', qty: 1),
  ],
);

Future<void> pumpDetail(WidgetTester tester) async {
  final bloc = MockServicesBloc();
  whenListen(
    bloc,
    const Stream<ServicesState>.empty(),
    initialState: const ServiceDetailLoaded(tService),
  );
  sl.registerFactory<ServicesBloc>(() => bloc);

  await tester.pumpWidget(
    const MaterialApp(home: ServiceDetailPage(serviceId: '3101SNT26100001')),
  );
}

void main() {
  tearDown(() => sl.reset());

  testWidgets('the total is the service plus the parts, in Rupiah', (
    tester,
  ) async {
    await pumpDetail(tester);

    expect(
      find.text('Total: ${CurrencyFormatter.rupiah(65000)}'),
      findsOneWidget,
    );
  });

  testWidgets('the total has no peso sign', (tester) async {
    await pumpDetail(tester);

    expect(find.textContaining('₱'), findsNothing);
  });
}
