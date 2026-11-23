import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/home/presentation/pages/home_page.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_booking_guide.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_bike_card.dart';
import 'package:fix_up_moto/features/notification/presentation/cubit/notification_count_cubit.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_bloc.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_event.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_state.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class MockPromosBloc extends MockBloc<PromosEvent, PromosState>
    implements PromosBloc {}

const tStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Test Member',
  emailAddress: '-',
  phoneNo: '81234567890',
  active: true,
  qty: 4,
  point: 80,
  detail: [],
  detail2: [],
);

late DataRefreshCubit refreshCubit;

/// What the stand-in Add Bike route was last opened with as its `extra`.
Object? addBikeExtra;

/// What the stand-in booking form was last opened with as its `extra`, and how
/// often it has been opened.
Object? bookingExtra;
int bookingFormOpened = 0;

/// The app-wide workshop pick, which a test can preselect or read back.
late SelectedWorkshopCubit selectedWorkshop;

const aWorkshop = WorkshopEntity(
  branch: '31',
  shop: '01',
  bsName: 'FIXUP MOTO - KEDUNG TARUKAN',
  bsAddress: 'JL. KUTISARI UTARA NO. 16A',
  operationalHours: 'Senin - Jumat 08.00 - 16.00',
  phoneNo: '0312345678',
  active: true,
  lat: -7.3,
  lng: 112.7,
);

/// The unread count the bell reads; fresh (0) per test, so a test sets it.
late NotificationCountCubit notificationCount;

/// Pumped in the loading state by default, which is just a spinner: the reload
/// wiring doesn't depend on what the loaded page contains, and the loaded page
/// pulls in the promo carousel and workshop picker.
///
/// The page reads the app-wide HomeBloc from the tree (it never builds its
/// own), so the mock is provided there.
Future<MockHomeBloc> pumpHome(
  WidgetTester tester, {
  HomeState state = const HomeLoading(),
}) async {
  final home = MockHomeBloc();
  whenListen(home, const Stream<HomeState>.empty(), initialState: state);

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: refreshCubit),
          BlocProvider<HomeBloc>.value(value: home),
        ],
        child: const HomePage(),
      ),
    ),
  );
  return home;
}

/// Pumped in the loaded state, inside a router so that a tap which navigates
/// has somewhere to go: `/profile` is a stand-in for the Profile tab.
///
/// The promo carousel is given a failed state, which collapses it, so nothing
/// animates and `pumpAndSettle` settles.
///
/// [stats] is what the page opens on, and [states] what the app-wide bloc emits
/// afterwards (a reload).
///
/// [prefs] switches on the "first booking" card, as the router does in the app.
Future<void> pumpLoadedHome(
  WidgetTester tester, {
  DashboardStatsEntity stats = tStats,
  Stream<HomeState> states = const Stream<HomeState>.empty(),
  SharedPreferences? prefs,
}) async {
  final home = MockHomeBloc();
  whenListen(home, states, initialState: HomeLoaded(stats));

  final promos = MockPromosBloc();
  whenListen(
    promos,
    const Stream<PromosState>.empty(),
    initialState: const PromosError('no promos'),
  );
  sl.registerFactory<PromosBloc>(() => promos);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => HomePage(prefs: prefs)),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('profile-tab')),
      ),
      GoRoute(
        path: '/notification',
        builder: (_, _) => const Scaffold(body: Text('notification-page')),
      ),
      GoRoute(
        path: RouteNames.addBike,
        builder: (_, state) {
          addBikeExtra = state.extra;
          return const Scaffold(body: Text('add-bike-page'));
        },
      ),
      GoRoute(
        path: RouteNames.workshops,
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('workshop-list'),
              TextButton(
                onPressed: () => context.pop(aWorkshop),
                child: const Text('Pilih bengkel'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.createBooking,
        builder: (_, state) {
          bookingExtra = state.extra;
          bookingFormOpened++;
          return const Scaffold(body: Text('booking-form'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: refreshCubit),
        BlocProvider<HomeBloc>.value(value: home),
        BlocProvider.value(value: notificationCount),
        BlocProvider.value(value: selectedWorkshop),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // For `any()` on a HomeEvent (the verifyNever checks).
  setUpAll(() => registerFallbackValue(const HomeStatsRequested()));
  setUp(() {
    refreshCubit = DataRefreshCubit();
    notificationCount = NotificationCountCubit();
    selectedWorkshop = SelectedWorkshopCubit();
    bookingExtra = null;
    bookingFormOpened = 0;
  });
  tearDown(() async {
    await selectedWorkshop.close();
    await sl.reset();
  });

  testWidgets('does not ask for the stats when the page opens', (tester) async {
    // The app-wide HomeBloc is loaded once at sign-in (StatsBootstrap); the
    // page only reads it.
    final home = await pumpHome(tester);

    verifyNever(() => home.add(any()));
  });

  testWidgets('does not reload the stats itself when they go out of date', (
    tester,
  ) async {
    // StatsBootstrap holds the one listener, so one change is one request.
    final home = await pumpHome(tester);

    refreshCubit.invalidate(DataKind.stats);
    await tester.pump();

    verifyNever(() => home.add(any()));
  });

  testWidgets('shows the error with a Retry that asks again', (tester) async {
    final home = await pumpHome(tester, state: const HomeError('Server down'));

    expect(find.text('Server down'), findsOneWidget);

    await tester.tap(find.text('Retry'));

    verify(() => home.add(const HomeStatsRequested())).called(1);
  });

  group('the first booking card', () {
    final card = find.byKey(const Key('first-booking-card'));
    final bikeCard = find.byKey(const Key('first-bike-card'));

    /// [tStats] with a different bike count.
    DashboardStatsEntity withBikes(int qty) => DashboardStatsEntity(
      status: tStats.status,
      memberId: tStats.memberId,
      memberName: tStats.memberName,
      emailAddress: tStats.emailAddress,
      phoneNo: tStats.phoneNo,
      active: tStats.active,
      qty: qty,
      point: tStats.point,
      detail: tStats.detail,
      detail2: tStats.detail2,
    );

    Future<SharedPreferences> prefsWith([
      Map<String, Object> values = const {},
    ]) {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    /// A member this phone has already noted as new.
    Future<SharedPreferences> notedAsNew() =>
        prefsWith({
          FirstBookingGuide.pendingKey: [tStats.memberId],
        });

    testWidgets('is there for a new member who now has a bike', (
      tester,
    ) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await notedAsNew(),
      );

      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text('Buat booking pertama Anda'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('bengkel, tanggal, dan jam'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is never there for a member this phone did not see as new', (
      tester,
    ) async {
      // Everyone who already had a bike before the card existed.
      await pumpLoadedHome(
        tester,
        stats: withBikes(2),
        prefs: await prefsWith(),
      );

      expect(card, findsNothing);
    });

    testWidgets('is not there for a member who has already booked', (
      tester,
    ) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await prefsWith({
          FirstBookingGuide.settledKey: [tStats.memberId],
        }),
      );

      expect(card, findsNothing);
    });

    testWidgets('is not there for another member noted on the same phone', (
      tester,
    ) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await prefsWith({
          FirstBookingGuide.pendingKey: ['M-999'],
        }),
      );

      expect(card, findsNothing);
    });

    testWidgets('is not there while the member has no bike', (tester) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(0),
        prefs: await notedAsNew(),
      );

      expect(card, findsNothing);
      // The bike card has that moment to itself.
      expect(bikeCard, findsOneWidget);
    });

    testWidgets('seeing a member with no bike is what notes them as new', (
      tester,
    ) async {
      final prefs = await prefsWith();

      await pumpLoadedHome(tester, stats: withBikes(0), prefs: prefs);

      expect(FirstBookingGuide.isPending(prefs, tStats.memberId), isTrue);
    });

    testWidgets('seeing a member with a bike notes nobody', (tester) async {
      final prefs = await prefsWith();

      await pumpLoadedHome(tester, stats: withBikes(3), prefs: prefs);

      expect(FirstBookingGuide.isPending(prefs, tStats.memberId), isFalse);
    });

    testWidgets('turns up by itself once the first bike is saved', (
      tester,
    ) async {
      final states = StreamController<HomeState>();
      addTearDown(states.close);
      final prefs = await prefsWith();
      await pumpLoadedHome(
        tester,
        stats: withBikes(0),
        states: states.stream,
        prefs: prefs,
      );
      expect(card, findsNothing);
      expect(bikeCard, findsOneWidget);

      // Add Bike signals the stats to reload, and they come back with a bike.
      states.add(HomeLoaded(withBikes(1)));
      await tester.pumpAndSettle();

      expect(bikeCard, findsNothing);
      expect(card, findsOneWidget);
    });

    testWidgets('sits under the greeting, above the workshop', (tester) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await notedAsNew(),
      );

      final greeting = tester.getBottomLeft(find.textContaining('Hi, '));
      expect(tester.getTopLeft(card).dy, greaterThan(greeting.dy));
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.text('Booking')).dy),
      );
    });

    testWidgets('goes by itself, for good, once a booking is made', (
      tester,
    ) async {
      final prefs = await notedAsNew();
      await pumpLoadedHome(tester, stats: withBikes(1), prefs: prefs);
      expect(card, findsOneWidget);

      // Create Booking signals this when a booking has been made.
      refreshCubit.invalidate(DataKind.bookings);
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(FirstBookingGuide.isPending(prefs, tStats.memberId), isFalse);
    });

    testWidgets('does not come back if they later have no bike again', (
      tester,
    ) async {
      final states = StreamController<HomeState>();
      addTearDown(states.close);
      final prefs = await notedAsNew();
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        states: states.stream,
        prefs: prefs,
      );
      refreshCubit.invalidate(DataKind.bookings);
      await tester.pumpAndSettle();

      // They delete their last bike, then add one.
      states.add(HomeLoaded(withBikes(0)));
      await tester.pumpAndSettle();
      states.add(HomeLoaded(withBikes(1)));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });

    testWidgets('ignores signals about other data', (tester) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await notedAsNew(),
      );

      refreshCubit.invalidate(DataKind.stats);
      await tester.pumpAndSettle();

      expect(card, findsOneWidget);
    });

    testWidgets('is left out altogether when the page is given no prefs', (
      tester,
    ) async {
      await pumpLoadedHome(tester, stats: withBikes(1));

      expect(card, findsNothing);
    });

    testWidgets('pressing it asks for a workshop first when none is chosen', (
      tester,
    ) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await notedAsNew(),
      );

      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text('workshop-list'), findsOneWidget);
      expect(bookingFormOpened, 0);
    });

    testWidgets('then opens the booking form as the booking step', (
      tester,
    ) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await notedAsNew(),
      );
      await tester.tap(card);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih bengkel'));
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, aWorkshop);
      expect(find.text('booking-form'), findsOneWidget);
      expect(bookingExtra, FirstTaskStep.createBooking);
    });

    testWidgets('goes straight to the form when a workshop is chosen', (
      tester,
    ) async {
      selectedWorkshop.select(aWorkshop);
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await notedAsNew(),
      );

      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text('workshop-list'), findsNothing);
      expect(find.text('booking-form'), findsOneWidget);
      expect(bookingExtra, FirstTaskStep.createBooking);
    });

    testWidgets('backing out of the workshops leaves the card where it was', (
      tester,
    ) async {
      await pumpLoadedHome(
        tester,
        stats: withBikes(1),
        prefs: await notedAsNew(),
      );
      await tester.tap(card);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(bookingFormOpened, 0);
      expect(card, findsOneWidget);
    });
  });

  group('the first bike card', () {
    final card = find.byKey(const Key('first-bike-card'));

    /// [tStats] with a different bike count.
    DashboardStatsEntity withBikes(int qty) => DashboardStatsEntity(
      status: tStats.status,
      memberId: tStats.memberId,
      memberName: tStats.memberName,
      emailAddress: tStats.emailAddress,
      phoneNo: tStats.phoneNo,
      active: tStats.active,
      qty: qty,
      point: tStats.point,
      detail: tStats.detail,
      detail2: tStats.detail2,
    );

    testWidgets('is there for a member with no bike, saying what to do', (
      tester,
    ) async {
      await pumpLoadedHome(tester, stats: withBikes(0));

      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text('Tambah motor pertama Anda'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('agar bisa membuat booking'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is not there for a member who already has a bike', (
      tester,
    ) async {
      await pumpLoadedHome(tester, stats: withBikes(1));

      expect(card, findsNothing);
      expect(find.text('Tambah motor pertama Anda'), findsNothing);
    });

    testWidgets('is not there for the usual member with several bikes', (
      tester,
    ) async {
      await pumpLoadedHome(tester);

      expect(tStats.qty, greaterThan(1));
      expect(card, findsNothing);
    });

    testWidgets('sits right under the greeting, above the workshop', (
      tester,
    ) async {
      await pumpLoadedHome(tester, stats: withBikes(0));

      final greeting = tester.getBottomLeft(find.textContaining('Hi, '));
      expect(tester.getTopLeft(card).dy, greaterThan(greeting.dy));
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.text('Booking')).dy),
      );
    });

    testWidgets('pressing it opens Add Bike, and back returns to Home', (
      tester,
    ) async {
      await pumpLoadedHome(tester, stats: withBikes(0));

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('add-bike-page'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('add-bike-page'), findsNothing);
      expect(card, findsOneWidget);
    });

    testWidgets("opens Add Bike as the guidance's bike step", (tester) async {
      addBikeExtra = null;
      await pumpLoadedHome(tester, stats: withBikes(0));

      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(addBikeExtra, FirstTaskStep.addBike);
    });

    testWidgets('goes by itself once the stats reload with a bike', (
      tester,
    ) async {
      final states = StreamController<HomeState>();
      addTearDown(states.close);
      await pumpLoadedHome(tester, stats: withBikes(0), states: states.stream);
      expect(card, findsOneWidget);

      // What happens after Add Bike saves: the stats are loaded again.
      states.add(HomeLoaded(withBikes(1)));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });

    testWidgets('stays while the reload is still under way', (tester) async {
      final states = StreamController<HomeState>();
      addTearDown(states.close);
      await pumpLoadedHome(tester, stats: withBikes(0), states: states.stream);

      // The old figures, marked as refreshing, are still what the page holds.
      states.add(HomeLoaded(withBikes(0), refreshing: true));
      await tester.pumpAndSettle();

      expect(card, findsOneWidget);
    });

    testWidgets('does not ask for the stats itself', (tester) async {
      // Home only reads them; Add Bike's own signal is what reloads them.
      await pumpLoadedHome(tester, stats: withBikes(0));
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(refreshCubit.state.kind, isNull);
    });

    testWidgets('reads on a light card in dark mode too', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: FirstBikeCard(onTap: () {})),
        ),
      );

      // The colour the title is really painted in, after the theme and the
      // default text style have both had their say.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Tambah motor pertama Anda'),
      );
      final painted = paragraph.text.style!.color!;

      // Dark text on the light peach card, not the dark theme's white.
      expect(ThemeData.estimateBrightnessForColor(painted), Brightness.dark);
    });
  });

  group('the notification bell', () {
    final bell = find.byKey(const Key('notification-chip'));
    final badge = find.descendant(of: bell, matching: find.byType(Badge));

    /// Whether the bell's badge is showing, and what it says.
    ({bool visible, String? text}) badgeState(WidgetTester tester) {
      final widget = tester.widget<Badge>(badge);
      return (
        visible: widget.isLabelVisible,
        text: widget.label is Text ? (widget.label! as Text).data : null,
      );
    }

    testWidgets('shows no badge while nothing is unread', (tester) async {
      await pumpLoadedHome(tester);

      expect(bell, findsOneWidget);
      expect(badgeState(tester).visible, isFalse);
    });

    testWidgets('shows the unread count on the bell', (tester) async {
      notificationCount.set(2);
      await pumpLoadedHome(tester);

      expect(badgeState(tester).visible, isTrue);
      expect(badgeState(tester).text, '2');
      expect(
        find.descendant(of: bell, matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('shows 99+ for a big count', (tester) async {
      notificationCount.set(150);
      await pumpLoadedHome(tester);

      expect(badgeState(tester).text, '99+');
    });

    testWidgets('follows the count live, and disappears when it clears', (
      tester,
    ) async {
      await pumpLoadedHome(tester);
      expect(badgeState(tester).visible, isFalse);

      // A cubit emits through an async stream: the first pump lets the new
      // count arrive, the second builds the frame that shows it.
      notificationCount.set(3);
      await tester.pump();
      await tester.pump();
      expect(badgeState(tester).visible, isTrue);
      expect(badgeState(tester).text, '3');

      notificationCount.set(0);
      await tester.pump();
      await tester.pump();
      expect(badgeState(tester).visible, isFalse);
    });

    testWidgets('pressing it opens the notification page', (tester) async {
      notificationCount.set(2);
      await pumpLoadedHome(tester);

      await tester.tap(
        find.descendant(of: bell, matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();

      expect(find.text('notification-page'), findsOneWidget);
    });
  });

  group('the points chip', () {
    final chip = find.byKey(const Key('points-chip'));

    testWidgets('shows the member\'s points', (tester) async {
      await pumpLoadedHome(tester);

      expect(
        find.descendant(of: chip, matching: find.text('80 pts')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chip, matching: find.byIcon(Icons.star)),
        findsOneWidget,
      );
    });

    testWidgets('is a button, and keeps its rounded tinted look', (
      tester,
    ) async {
      await pumpLoadedHome(tester);

      final inkWell = tester.widget<InkWell>(
        find.descendant(of: chip, matching: find.byType(InkWell)),
      );
      expect(inkWell.onTap, isNotNull);
      expect(inkWell.borderRadius, BorderRadius.circular(20));

      // The same pill as before it was pressable.
      final material = tester.widget<Material>(chip);
      expect(material.color, AppColors.primary.withValues(alpha: 0.12));
      expect(material.borderRadius, BorderRadius.circular(20));
    });

    testWidgets('pressing it opens the Profile tab', (tester) async {
      await pumpLoadedHome(tester);
      expect(find.text('profile-tab'), findsNothing);

      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('profile-tab'), findsOneWidget);
      expect(find.text('Hi, Test Member'), findsNothing); // Home is left
    });

    testWidgets('pressing its text works too, not just its edge', (
      tester,
    ) async {
      await pumpLoadedHome(tester);

      await tester.tap(find.text('80 pts'));
      await tester.pumpAndSettle();

      expect(find.text('profile-tab'), findsOneWidget);
    });

    testWidgets('the greeting name still opens the Profile tab', (
      tester,
    ) async {
      await pumpLoadedHome(tester);

      await tester.tap(find.text('Hi, Test Member'));
      await tester.pumpAndSettle();

      expect(find.text('profile-tab'), findsOneWidget);
    });
  });
}
