import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_bloc.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_event.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_state.dart';
import 'package:fix_up_moto/features/workshops/presentation/pages/workshop_list_page.dart';

class MockWorkshopsBloc extends MockBloc<WorkshopsEvent, WorkshopsState>
    implements WorkshopsBloc {}

WorkshopEntity workshop({
  String shop = '01',
  String name = 'FIXUP MOTO - KUTISARI',
  String phoneNo = '0812-3113-3383',
}) {
  return WorkshopEntity(
    branch: '31',
    shop: shop,
    bsName: name,
    bsAddress: 'JL. KUTISARI UTARA NO. 16A',
    operationalHours: 'Senin - Jumat 08.00 - 16.00',
    phoneNo: phoneNo,
    active: true,
    lat: -7.3,
    lng: 112.7,
  );
}

Future<void> pumpPage(
  WidgetTester tester,
  List<WorkshopEntity> workshops,
) async {
  final bloc = MockWorkshopsBloc();
  whenListen(
    bloc,
    const Stream<WorkshopsState>.empty(),
    initialState: WorkshopsLoaded(workshops),
  );
  sl.registerFactory<WorkshopsBloc>(() => bloc);

  await tester.pumpWidget(const MaterialApp(home: WorkshopListPage()));
}

/// Stands in for the url_launcher plugin: answers every launch with [opens] and
/// records the calls it received.
List<MethodCall> mockLauncher({required bool opens}) {
  final calls = <MethodCall>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    return opens;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}

void main() {
  tearDown(() => sl.reset());

  final whatsapp = find.byKey(const Key('workshop-whatsapp-31-01'));

  testWidgets('each card chats on WhatsApp instead of calling', (tester) async {
    await pumpPage(tester, [workshop(), workshop(shop: '02')]);

    expect(find.text('WhatsApp'), findsNWidgets(2));
    expect(find.text('Telepon'), findsNothing);
    expect(find.byIcon(Icons.call_outlined), findsNothing);
  });

  testWidgets('opens the workshop number in WhatsApp', (tester) async {
    final calls = mockLauncher(opens: true);
    await pumpPage(tester, [workshop()]);

    await tester.tap(whatsapp);
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'launch');
    expect(calls.single.arguments['url'], 'https://wa.me/6281231133383');
    // Handed to WhatsApp (or the browser), not shown in an in-app web view.
    expect(calls.single.arguments['useWebView'], isFalse);
  });

  testWidgets('a number written with +62 gives the same link', (tester) async {
    final calls = mockLauncher(opens: true);
    await pumpPage(tester, [workshop(phoneNo: '+62 812-3113-3383')]);

    await tester.tap(whatsapp);
    await tester.pump();

    expect(calls.single.arguments['url'], 'https://wa.me/6281231133383');
  });

  testWidgets('says so when WhatsApp cannot be opened', (tester) async {
    mockLauncher(opens: false);
    await pumpPage(tester, [workshop()]);

    await tester.tap(whatsapp);
    await tester.pump();

    expect(find.text('WhatsApp tidak dapat dibuka'), findsOneWidget);
  });

  testWidgets('has nothing to open when the backend sent no number', (
    tester,
  ) async {
    await pumpPage(tester, [workshop(phoneNo: '')]);

    // Disabled, so a tap on it opens nothing (it would fall through to the
    // card, which picks the workshop).
    expect(tester.widget<OutlinedButton>(whatsapp).onPressed, isNull);
  });
}
