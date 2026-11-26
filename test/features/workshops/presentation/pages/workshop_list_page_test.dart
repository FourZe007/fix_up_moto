import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/geo.dart';
import 'package:fix_up_moto/core/services/location_service.dart';
import 'package:fix_up_moto/core/widgets/app_spinner.dart';
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
  bool active = true,
  double lat = -7.3,
  double lng = 112.7,
  String address = 'JL. KUTISARI UTARA NO. 16A',
}) {
  return WorkshopEntity(
    branch: '31',
    shop: shop,
    bsName: name,
    bsAddress: address,
    operationalHours: 'Senin - Jumat 08.00 - 16.00',
    phoneNo: phoneNo,
    active: active,
    lat: lat,
    lng: lng,
  );
}

/// A [LocationService] a test can answer by hand, counting how often it is asked.
class FakeLocation implements LocationService {
  final Future<GeoPoint?> Function() answer;
  var asked = 0;

  FakeLocation(this.answer);

  /// Answers straight away with [here] (null: the position is unknown).
  FakeLocation.at(GeoPoint? here) : this(() async => here);

  @override
  Future<GeoPoint?> currentPosition() {
    asked++;
    return answer();
  }
}

Future<MockWorkshopsBloc> pumpPage(
  WidgetTester tester,
  List<WorkshopEntity> workshops, {
  LocationService location = const NoLocationService(),
  WorkshopsState? initialState,
  Stream<WorkshopsState>? states,
}) async {
  final bloc = MockWorkshopsBloc();
  whenListen(
    bloc,
    states ?? const Stream<WorkshopsState>.empty(),
    initialState: initialState ?? WorkshopsLoaded(workshops),
  );
  sl.registerFactory<WorkshopsBloc>(() => bloc);
  sl.registerSingleton<LocationService>(location);

  await tester.pumpWidget(const MaterialApp(home: WorkshopListPage()));
  // The frame after the position is answered, if it was answered at once.
  await tester.pump();
  return bloc;
}

/// A screen tall enough to build every card.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The workshop names on screen, from the top card down.
List<String> shownNames(WidgetTester tester) {
  final cards = [
    for (final element in find.textContaining('FIXUP MOTO - ').evaluate())
      (
        name: (element.widget as Text).data!.replaceFirst('FIXUP MOTO - ', ''),
        top: tester.getTopLeft(find.byWidget(element.widget)).dy,
      ),
  ]..sort((a, b) => a.top.compareTo(b.top));
  return [for (final card in cards) card.name];
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

  group('the text under the spinner', () {
    final loading = find.text('Memuat...');
    final finding = find.text('Mencari bengkel terdekat dari lokasi Anda...');
    const here = GeoPoint(-7.3, 112.7);

    /// A position that has not been answered yet. Answered when the test ends,
    /// so that the page's safety timer does not outlive it.
    Completer<GeoPoint?> pendingPosition(WidgetTester tester) {
      final answer = Completer<GeoPoint?>();
      addTearDown(() {
        if (!answer.isCompleted) answer.complete(null);
      });
      return answer;
    }

    for (final state in const [WorkshopsInitial(), WorkshopsLoading()]) {
      testWidgets('is the plain one while the list loads ($state)', (
        tester,
      ) async {
        final answer = pendingPosition(tester);
        await pumpPage(
          tester,
          const [],
          location: FakeLocation(() => answer.future),
          initialState: state,
        );

        // The position is being looked up too, but the list is what is missing.
        expect(loading, findsOneWidget);
        expect(finding, findsNothing);
        answer.complete(here);
        await tester.pump();
      });
    }

    testWidgets('says it is finding the nearest once only that is left', (
      tester,
    ) async {
      final answer = pendingPosition(tester);
      final states = StreamController<WorkshopsState>();
      addTearDown(states.close);
      await pumpPage(
        tester,
        const [],
        location: FakeLocation(() => answer.future),
        initialState: const WorkshopsLoading(),
        states: states.stream,
      );
      expect(loading, findsOneWidget);
      expect(finding, findsNothing);

      states.add(WorkshopsLoaded([workshop()]));
      await tester.pump();
      await tester.pump();

      expect(finding, findsOneWidget);
      expect(loading, findsNothing);
      expect(find.byType(AppSpinner), findsOneWidget);

      answer.complete(here);
      await tester.pump();

      expect(finding, findsNothing);
      expect(find.byType(AppSpinner), findsNothing);
      expect(shownNames(tester), ['KUTISARI']);
    });

    testWidgets('never says it if the position was answered before the list', (
      tester,
    ) async {
      final states = StreamController<WorkshopsState>();
      addTearDown(states.close);
      // As with location switched off: answered at once, with nothing.
      await pumpPage(
        tester,
        const [],
        location: FakeLocation.at(null),
        initialState: const WorkshopsLoading(),
        states: states.stream,
      );
      expect(loading, findsOneWidget);
      expect(finding, findsNothing);

      states.add(WorkshopsLoaded([workshop()]));
      await tester.pump();
      expect(finding, findsNothing);
      await tester.pump();

      expect(finding, findsNothing);
      expect(shownNames(tester), ['KUTISARI']);
    });

    testWidgets('has nothing to find for an empty list', (tester) async {
      final answer = pendingPosition(tester);
      await pumpPage(
        tester,
        const [],
        location: FakeLocation(() => answer.future),
      );

      expect(find.text('No workshops available'), findsOneWidget);
      expect(finding, findsNothing);
      expect(find.byType(AppSpinner), findsNothing);
      answer.complete(here);
      await tester.pump();
    });

    testWidgets('follows a reload through both waits again', (tester) async {
      final second = pendingPosition(tester);
      var lookups = 0;
      final states = StreamController<WorkshopsState>();
      addTearDown(states.close);
      await pumpPage(
        tester,
        const [],
        location: FakeLocation(
          () => ++lookups == 1 ? Future.value(here) : second.future,
        ),
        initialState: const WorkshopsError('Gagal memuat'),
        states: states.stream,
      );

      await tester.tap(find.text('Retry'));
      states.add(const WorkshopsLoading());
      await tester.pump();
      await tester.pump();
      expect(loading, findsOneWidget);
      expect(finding, findsNothing);

      states.add(WorkshopsLoaded([workshop()]));
      await tester.pump();
      await tester.pump();
      expect(finding, findsOneWidget);
      expect(loading, findsNothing);

      second.complete(here);
      await tester.pump();
      expect(finding, findsNothing);
      expect(shownNames(tester), ['KUTISARI']);
    });

    testWidgets(
      'sits under the spinner and fits a narrow screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final answer = pendingPosition(tester);
        await pumpPage(tester, [
          workshop(),
        ], location: FakeLocation(() => answer.future));

        final spinner = tester.getRect(find.byType(AppSpinner));
        final text = tester.getRect(finding);

        expect(spinner.shortestSide, greaterThanOrEqualTo(20));
        expect(text.top, greaterThan(spinner.bottom));
        expect(text.center.dx, closeTo(spinner.center.dx, 1));
        expect(text.left, greaterThanOrEqualTo(0));
        expect(text.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
        answer.complete(here);
        await tester.pump();
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  });

  group('the line when the location was not found', () {
    final notice = find.text('Lokasi Anda gagal ditemukan');
    const here = GeoPoint(-7.3, 112.7);

    for (final (name, answer) in [
      ('no position', null),
      ('a position that is not a real place', const GeoPoint(0, 0)),
    ]) {
      testWidgets('is above the list with $name', (tester) async {
        useTallScreen(tester);
        await pumpPage(tester, [workshop()], location: FakeLocation.at(answer));

        expect(notice, findsOneWidget);
        // Between the search field and the first card.
        expect(
          tester.getRect(notice).top,
          greaterThan(tester.getRect(find.byType(TextField)).bottom),
        );
        expect(
          tester.getRect(notice).bottom,
          lessThan(tester.getRect(find.text('FIXUP MOTO - KUTISARI')).top),
        );
        expect(find.textContaining(' km'), findsNothing);
      });
    }

    testWidgets('is not there when the position was found', (tester) async {
      await pumpPage(tester, [workshop()], location: FakeLocation.at(here));

      expect(shownNames(tester), ['KUTISARI']);
      expect(notice, findsNothing);
    });

    testWidgets('waits until the lookup is really over', (tester) async {
      final answer = Completer<GeoPoint?>();
      final states = StreamController<WorkshopsState>();
      addTearDown(states.close);
      await pumpPage(
        tester,
        const [],
        location: FakeLocation(() => answer.future),
        initialState: const WorkshopsLoading(),
        states: states.stream,
      );
      expect(notice, findsNothing);

      states.add(WorkshopsLoaded([workshop()]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(notice, findsNothing);

      answer.complete(null);
      await tester.pump();
      expect(notice, findsOneWidget);
    });

    testWidgets('appears when the 30 s safety limit is reached', (
      tester,
    ) async {
      final answer = Completer<GeoPoint?>();
      await pumpPage(tester, [
        workshop(),
      ], location: FakeLocation(() => answer.future));

      await tester.pump(const Duration(seconds: 31));

      expect(notice, findsOneWidget);
      answer.complete(null);
    });

    testWidgets('goes once a pull to refresh finds the position', (
      tester,
    ) async {
      GeoPoint? answer;
      await pumpPage(tester, [
        workshop(),
      ], location: FakeLocation(() async => answer));
      expect(notice, findsOneWidget);

      Future<void> pull() async {
        await tester.fling(
          find.text('FIXUP MOTO - KUTISARI'),
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();
      }

      answer = here;
      await pull();
      expect(notice, findsNothing);
      expect(find.textContaining(' km'), findsOneWidget);

      answer = null;
      await pull();
      expect(notice, findsOneWidget);
    });

    testWidgets('stays above search results', (tester) async {
      await pumpPage(tester, [workshop()]);

      await tester.enterText(find.byType(TextField), 'kutisari');
      await tester.pump();

      expect(shownNames(tester), ['KUTISARI']);
      expect(notice, findsOneWidget);
    });

    testWidgets('is not said of an empty list', (tester) async {
      await pumpPage(tester, const []);

      expect(find.text('No workshops available'), findsOneWidget);
      expect(notice, findsNothing);
    });

    testWidgets('is not said over a loading error', (tester) async {
      await pumpPage(
        tester,
        const [],
        initialState: const WorkshopsError('Gagal memuat'),
      );

      expect(find.text('Gagal memuat'), findsOneWidget);
      expect(notice, findsNothing);
    });

    testWidgets(
      'fits a narrow screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpPage(tester, [workshop()]);

        final line = tester.getRect(notice);
        expect(line.left, greaterThanOrEqualTo(16));
        expect(line.right, lessThanOrEqualTo(304));
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  });

  group('nearest first', () {
    // One degree of latitude is about 111 km, so these are about 5.6 km,
    // 2.2 km and 0 km from [atDarmo].
    const atDarmo = GeoPoint(-7.30, 112.70);
    const atKutisari = GeoPoint(-7.35, 112.70);

    // As the server sends them: furthest from Darmo first.
    WorkshopEntity branch(
      String shop,
      String name, {
      double lat = -7.3,
      bool active = true,
    }) => workshop(
      shop: shop,
      name: 'FIXUP MOTO - $name',
      lat: lat,
      active: active,
      // Plain, so that a search below matches names only.
      address: 'JL. CONTOH $shop',
    );
    final branches = [
      branch('01', 'KUTISARI', lat: -7.35),
      branch('02', 'TUTUP', active: false),
      branch('03', 'RUNGKUT', lat: -7.32),
      branch('04', 'DARMO'),
    ];
    const serverOrder = ['KUTISARI', 'TUTUP', 'RUNGKUT', 'DARMO'];
    // The closed one is as close as can be, and still last.
    const fromDarmo = ['DARMO', 'RUNGKUT', 'KUTISARI', 'TUTUP'];
    const fromKutisari = ['KUTISARI', 'RUNGKUT', 'DARMO', 'TUTUP'];

    String distanceOf(WidgetTester tester, String id) =>
        tester.widget<Text>(find.byKey(Key('workshop-distance-$id'))).data!;

    testWidgets('lists nearest first, with closed ones at the bottom', (
      tester,
    ) async {
      useTallScreen(tester);
      await pumpPage(tester, branches, location: FakeLocation.at(atDarmo));

      expect(shownNames(tester), fromDarmo);
    });

    testWidgets('shows nothing until the position is answered', (tester) async {
      useTallScreen(tester);
      final answer = Completer<GeoPoint?>();
      await pumpPage(
        tester,
        branches,
        location: FakeLocation(() => answer.future),
      );
      await tester.pump(const Duration(seconds: 5));

      expect(find.byType(AppSpinner), findsOneWidget);
      expect(shownNames(tester), isEmpty);

      answer.complete(atDarmo);
      await tester.pump();

      expect(find.byType(AppSpinner), findsNothing);
      expect(shownNames(tester), fromDarmo);
    });

    testWidgets('keeps the spinner while the list is still loading', (
      tester,
    ) async {
      useTallScreen(tester);
      final states = StreamController<WorkshopsState>();
      addTearDown(states.close);
      await pumpPage(
        tester,
        branches,
        location: FakeLocation.at(atDarmo),
        initialState: const WorkshopsLoading(),
        states: states.stream,
      );

      expect(find.byType(AppSpinner), findsOneWidget);

      states.add(WorkshopsLoaded(branches));
      await tester.pump();
      await tester.pump();

      expect(shownNames(tester), fromDarmo);
    });

    testWidgets('says how far each workshop is', (tester) async {
      useTallScreen(tester);
      await pumpPage(tester, [
        workshop(shop: '01', lat: -7.32),
        // About 55 m and 111 m away: either side of the "under 100 m" line.
        workshop(shop: '02', lat: -7.3005),
        workshop(shop: '03', lat: -7.301),
        // No coordinates: nothing to say.
        workshop(shop: '04', lat: 0, lng: 0),
      ], location: FakeLocation.at(atDarmo));

      expect(distanceOf(tester, '31-01'), '± 2,2 km');
      expect(distanceOf(tester, '31-02'), '< 0,1 km');
      expect(distanceOf(tester, '31-03'), '± 0,1 km');
      expect(find.byKey(const Key('workshop-distance-31-04')), findsNothing);
    });

    testWidgets('without a position, keeps the server order and no distance', (
      tester,
    ) async {
      useTallScreen(tester);
      await pumpPage(tester, branches, location: FakeLocation.at(null));

      expect(shownNames(tester), serverOrder);
      expect(find.textContaining(' km'), findsNothing);
      expect(find.text('Lokasi Anda gagal ditemukan'), findsOneWidget);
    });

    testWidgets('search results stay nearest first', (tester) async {
      useTallScreen(tester);
      await pumpPage(tester, branches, location: FakeLocation.at(atDarmo));

      // "ut" is in KUTISARI, RUNGKUT and TUTUP.
      await tester.enterText(find.byType(TextField), 'ut');
      await tester.pump();

      expect(shownNames(tester), ['RUNGKUT', 'KUTISARI', 'TUTUP']);
    });

    testWidgets('lists without a position after 30 s, and then stays put', (
      tester,
    ) async {
      useTallScreen(tester);
      final answer = Completer<GeoPoint?>();
      await pumpPage(
        tester,
        branches,
        location: FakeLocation(() => answer.future),
      );

      await tester.pump(const Duration(seconds: 29));
      expect(shownNames(tester), isEmpty);

      await tester.pump(const Duration(seconds: 2));
      expect(shownNames(tester), serverOrder);

      // Too late: a card must not move under a finger.
      answer.complete(atDarmo);
      await tester.pump();
      expect(shownNames(tester), serverOrder);
    });

    testWidgets('pull to refresh asks where the member is again', (
      tester,
    ) async {
      useTallScreen(tester);
      // Nullable, like the real service's answer.
      GeoPoint? here = atDarmo;
      final location = FakeLocation(() async => here);
      final bloc = await pumpPage(tester, branches, location: location);
      expect(shownNames(tester), fromDarmo);

      here = atKutisari;
      // A pull counts once it covers about a quarter of the list's height,
      // which is a long way on this tall screen.
      await tester.fling(
        find.text('FIXUP MOTO - DARMO'),
        const Offset(0, 800),
        1000,
      );
      await tester.pumpAndSettle();

      expect(location.asked, 2);
      // Once when the page opened, once for the pull.
      verify(() => bloc.add(const WorkshopsRequested())).called(2);
      expect(shownNames(tester), fromKutisari);
    });

    testWidgets('an error shows at once, and Retry asks both again', (
      tester,
    ) async {
      final location = FakeLocation.at(atDarmo);
      final bloc = await pumpPage(
        tester,
        branches,
        location: location,
        initialState: const WorkshopsError('Gagal memuat'),
      );
      expect(find.text('Gagal memuat'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(location.asked, 2);
      verify(() => bloc.add(const WorkshopsRequested())).called(2);
    });

    testWidgets('a late answer from before a reload is ignored', (
      tester,
    ) async {
      useTallScreen(tester);
      final first = Completer<GeoPoint?>();
      final second = Completer<GeoPoint?>();
      final answers = [first, second];
      final location = FakeLocation(() => answers.removeAt(0).future);
      final states = StreamController<WorkshopsState>();
      addTearDown(states.close);
      await pumpPage(
        tester,
        branches,
        location: location,
        initialState: const WorkshopsError('Gagal memuat'),
        states: states.stream,
      );

      await tester.tap(find.text('Retry'));
      states.add(WorkshopsLoaded(branches));
      second.complete(atKutisari);
      await tester.pump();
      await tester.pump();
      expect(shownNames(tester), fromKutisari);

      first.complete(atDarmo);
      await tester.pump();
      expect(shownNames(tester), fromKutisari);
    });

    testWidgets('leaving while still waiting does nothing', (tester) async {
      final answer = Completer<GeoPoint?>();
      await pumpPage(
        tester,
        branches,
        location: FakeLocation(() => answer.future),
      );

      await tester.pumpWidget(const SizedBox());
      answer.complete(atDarmo);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
