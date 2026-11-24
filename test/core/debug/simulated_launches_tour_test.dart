import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/debug/simulated_first_booking.dart';
import 'package:fix_up_moto/core/debug/simulated_new_member.dart';
import 'package:fix_up_moto/core/tour/app_tour.dart';
import 'package:fix_up_moto/core/tour/app_tour_handoff.dart';
import 'package:fix_up_moto/core/tour/app_tour_host.dart';
import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/widgets/app_tab_bar.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/domain/usecases/get_dashboard_stats_usecase.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_booking_guide.dart';

/// The two debug launches, end to end without a phone: the real [HomeBloc] with
/// the simulation a launch hands it, an [AppTourHost] reading it the way
/// `AppRouter` does, and an account that **really has three bikes** (what the
/// user signs in with when testing).
///
/// Neither launch hand-writes the bike count or the pending flag: both come out
/// of the simulation, so these tests fail if a launch stops producing the tour
/// and the right last step.

class MockGetDashboardStats extends Mock implements GetDashboardStatsUseCase {}

const threeBikes = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Test Member',
  emailAddress: 'a@example.com',
  phoneNo: '81234567890',
  active: true,
  qty: 3,
  point: 80,
  detail: [],
  detail2: [],
);

final card = find.byType(AppTourCard);
final next = find.byKey(const Key('tour-next'));
final accept = find.byKey(const Key('tour-accept'));

/// The shell's tour wiring, as `AppRouter` builds it: the count and the
/// first-booking flag read from the stats the bloc holds right now.
int? bikeCountOf(HomeBloc bloc) {
  final state = bloc.state;
  return state is HomeLoaded ? state.stats.qty : null;
}

bool bookingPendingOf(HomeBloc bloc, SharedPreferences prefs) {
  final state = bloc.state;
  return state is HomeLoaded &&
      FirstBookingGuide.isPending(prefs, state.stats.memberId);
}

/// Opens the shell's tour host over [bloc], with the stats not loaded yet (as at
/// a cold start), then loads them and lets the tour's quiet checks pass.
Future<void> launch(
  WidgetTester tester, {
  required HomeBloc bloc,
  required SharedPreferences prefs,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppTourHost(
        prefs: prefs,
        bikeCount: () => bikeCountOf(bloc),
        bookingPending: () => bookingPendingOf(bloc, prefs),
        handoff: () => AppTourHandoff.forBikeCount(
          bikeCountOf(bloc),
          bookingPending: bookingPendingOf(bloc, prefs),
        ),
        builder: (context, tabKeys) => Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: AppTabBar(
            selectedIndex: 0,
            onSelected: (_) {},
            tabKeys: tabKeys,
          ),
        ),
      ),
    ),
  );

  // Not loaded yet: the tour must wait, not guess.
  await tester.pump(AppTourHost.checkEvery * 2);
  expect(card, findsNothing);

  bloc.add(const HomeStatsRequested());
  await tester.pump();
  await tester.pump();
  expect(bloc.state, isA<HomeLoaded>());

  await tester.pump(AppTourHost.checkEvery * AppTourHost.calmChecksNeeded);
  await tester.pumpAndSettle();
}

Future<void> toLastStep(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.tap(next);
    await tester.pumpAndSettle();
  }
}

void main() {
  late MockGetDashboardStats getStats;
  late SharedPreferences prefs;

  setUp(() async {
    getStats = MockGetDashboardStats();
    when(() => getStats()).thenAnswer((_) async => const Right(threeBikes));
    // The phone has seen the tour on an earlier run, and remembers the member as
    // having booked: both are what a launch has to undo.
    SharedPreferences.setMockInitialValues({
      AppTourSeen.key: true,
      FirstBookingGuide.settledKey: ['M-001'],
    });
    prefs = await SharedPreferences.getInstance();
  });

  group('without a simulation (an ordinary launch)', () {
    testWidgets('a member with bikes who has booked is not shown the tour', (
      tester,
    ) async {
      // Seen is cleared here only so the audience rule is what decides.
      await prefs.remove(AppTourSeen.key);
      final bloc = HomeBloc(getDashboardStats: getStats);
      addTearDown(bloc.close);

      await launch(tester, bloc: bloc, prefs: prefs);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });
  });

  group('the new-member launch', () {
    testWidgets('plays the tour for an account that has bikes', (tester) async {
      final simulation = await SimulatedNewMember.start(
        prefs,
        enabled: true,
        release: false,
      );
      final bloc = HomeBloc(
        getDashboardStats: getStats,
        simulateNewMember: simulation,
      );
      addTearDown(bloc.close);

      await launch(tester, bloc: bloc, prefs: prefs);

      expect(card, findsOneWidget);
      expect(find.text('1 dari 5'), findsOneWidget);
    });

    testWidgets('and its last step offers adding the first bike', (
      tester,
    ) async {
      final simulation = await SimulatedNewMember.start(
        prefs,
        enabled: true,
        release: false,
      );
      final bloc = HomeBloc(
        getDashboardStats: getStats,
        simulateNewMember: simulation,
      );
      addTearDown(bloc.close);
      await launch(tester, bloc: bloc, prefs: prefs);

      await toLastStep(tester);

      expect(find.text(AppTourHandoff.addFirstBike.message), findsOneWidget);
      expect(
        find.descendant(
          of: accept,
          matching: find.text('Tambah motor sekarang'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the first-booking launch', () {
    testWidgets('plays the tour for an account that has bikes', (tester) async {
      final simulation = await SimulatedFirstBooking.start(
        prefs,
        enabled: true,
        release: false,
      );
      final bloc = HomeBloc(
        getDashboardStats: getStats,
        simulateFirstBooking: simulation,
      );
      addTearDown(bloc.close);

      await launch(tester, bloc: bloc, prefs: prefs);

      expect(card, findsOneWidget);
      expect(find.text('1 dari 5'), findsOneWidget);
    });

    testWidgets('keeps the bikes real while it does', (tester) async {
      final simulation = await SimulatedFirstBooking.start(
        prefs,
        enabled: true,
        release: false,
      );
      final bloc = HomeBloc(
        getDashboardStats: getStats,
        simulateFirstBooking: simulation,
      );
      addTearDown(bloc.close);

      await launch(tester, bloc: bloc, prefs: prefs);

      expect(bikeCountOf(bloc), 3);
    });

    testWidgets('and its last step offers booking, not adding a bike', (
      tester,
    ) async {
      final simulation = await SimulatedFirstBooking.start(
        prefs,
        enabled: true,
        release: false,
      );
      final bloc = HomeBloc(
        getDashboardStats: getStats,
        simulateFirstBooking: simulation,
      );
      addTearDown(bloc.close);
      await launch(tester, bloc: bloc, prefs: prefs);

      await toLastStep(tester);

      expect(
        find.text(AppTourHandoff.bookFirstService.message),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: accept,
          matching: find.text('Buat booking sekarang'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tambah motor sekarang'), findsNothing);
    });

    testWidgets('and without the launch switch the same account gets nothing', (
      tester,
    ) async {
      // Same phone, same account, no simulation handed in.
      await prefs.remove(AppTourSeen.key);
      final bloc = HomeBloc(getDashboardStats: getStats);
      addTearDown(bloc.close);

      await launch(tester, bloc: bloc, prefs: prefs);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
    });
  });
}
