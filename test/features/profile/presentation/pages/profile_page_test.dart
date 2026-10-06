import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/profile_page.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

/// Signed in, used only so the sign-out button has an AuthBloc to talk to.
const tUser = UserEntity(
  id: 'M-001',
  name: 'Test Member',
  status: 'Active',
  isActive: true,
);

/// What the page shows: the dashboard stats record, not the login record. The
/// backend sends the phone without its leading zero.
const tStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Stats Member',
  emailAddress: 'stats@example.com',
  phoneNo: '87700001111',
  active: true,
  qty: 4,
  point: 80,
  detail: [],
  detail2: [],
);

/// The blocs behind the page, so tests can verify what was sent to them.
class Mocks {
  final MockHomeBloc home;
  final MockAuthBloc auth;
  const Mocks(this.home, this.auth);
}

/// The app-wide "reload this" signal the page listens to; fresh per test.
late DataRefreshCubit refreshCubit;

/// The page builds its own HomeBloc through GetIt, so each test registers a
/// mock one in the state it wants to see.
Future<Mocks> pumpProfile(
  WidgetTester tester, {
  HomeState homeState = const HomeLoaded(tStats),
}) async {
  final homeBloc = MockHomeBloc();
  whenListen(
    homeBloc,
    const Stream<HomeState>.empty(),
    initialState: homeState,
  );
  sl.registerFactory<HomeBloc>(() => homeBloc);

  final authBloc = MockAuthBloc();
  whenListen(
    authBloc,
    const Stream<AuthState>.empty(),
    initialState: const AuthAuthenticated(tUser),
  );

  // A real router, so tapping a tile can be checked by where it lands.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<DataRefreshCubit>.value(
          value: refreshCubit,
          child: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const ProfilePage(),
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.myBikes,
        builder: (_, _) => const Scaffold(body: Text('my-bikes-page')),
      ),
      GoRoute(
        path: RouteNames.membership,
        builder: (_, _) => const Scaffold(body: Text('membership-page')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  return Mocks(homeBloc, authBloc);
}

void main() {
  setUp(() => refreshCubit = DataRefreshCubit());
  tearDown(() => sl.reset());

  final settingsButton = find.widgetWithIcon(
    IconButton,
    Icons.settings_outlined,
  );
  final logoutButton = find.widgetWithIcon(IconButton, Icons.logout);
  final bikeTile = find.byKey(const Key('bike-count-column'));
  final pointsTile = find.byKey(const Key('points-stat-tile'));

  testWidgets('shows the Settings and Sign out buttons', (tester) async {
    await pumpProfile(tester);

    expect(settingsButton, findsOneWidget);
    expect(logoutButton, findsOneWidget);
  });

  group('member details come from the dashboard stats', () {
    testWidgets('shows name, phone and email from the stats record', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.text('Stats Member'), findsOneWidget);
      // Shown with the leading zero the backend leaves off.
      expect(find.text('087700001111'), findsOneWidget);
      expect(find.text('stats@example.com'), findsOneWidget);
      // The avatar initial comes from the stats name, not the login record's.
      expect(find.text('S'), findsOneWidget);
      // The login record's name is no longer shown.
      expect(find.text(tUser.name), findsNothing);
    });

    testWidgets('no longer shows the hardcoded placeholder phone number', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.text('081234567890'), findsNothing);
    });

    testWidgets('hides phone and email the backend sent as a dash or blank', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        homeState: const HomeLoaded(
          DashboardStatsEntity(
            status: 'AKTIF',
            memberId: 'M-001',
            memberName: 'Stats Member',
            emailAddress: '-',
            phoneNo: ' ',
            active: true,
            qty: 0,
            point: 0,
            detail: [],
            detail2: [],
          ),
        ),
      );

      expect(find.text('Stats Member'), findsOneWidget);
      expect(find.text('-'), findsNothing);
    });

    testWidgets('asks for the stats when the page opens', (tester) async {
      final mocks = await pumpProfile(tester);

      verify(() => mocks.home.add(const HomeStatsRequested())).called(1);
    });

    testWidgets('shows a spinner while loading, not the member', (
      tester,
    ) async {
      await pumpProfile(tester, homeState: const HomeLoading());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Stats Member'), findsNothing);
    });

    testWidgets('shows the error with a Retry that asks again', (tester) async {
      final mocks = await pumpProfile(
        tester,
        homeState: const HomeError('Server down'),
      );

      expect(find.text('Server down'), findsOneWidget);

      await tester.tap(find.text('Retry'));

      // Once on open, once for the retry.
      verify(() => mocks.home.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('sign out still goes through AuthBloc', (tester) async {
      final mocks = await pumpProfile(tester);

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
      await tester.pumpAndSettle();

      verify(() => mocks.auth.add(const AuthLogoutRequested())).called(1);
    });
  });

  group('reloads when the stats go out of date elsewhere', () {
    testWidgets('invalidate(stats) sends HomeStatsRequested again', (
      tester,
    ) async {
      final mocks = await pumpProfile(tester);

      refreshCubit.invalidate(DataKind.stats);
      await tester.pump();

      // Once when the page opened, once for the signal.
      verify(() => mocks.home.add(const HomeStatsRequested())).called(2);
    });

    testWidgets('invalidate(bookings) is none of its business', (tester) async {
      final mocks = await pumpProfile(tester);

      refreshCubit.invalidate(DataKind.bookings);
      await tester.pump();

      verify(() => mocks.home.add(const HomeStatsRequested())).called(1);
    });
  });

  group('stat tiles', () {
    testWidgets('show the bike count and the points from the stats', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(
        find.descendant(of: bikeTile, matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bikeTile, matching: find.text('My Bikes')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bikeTile,
          matching: find.byIcon(Icons.two_wheeler_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pointsTile, matching: find.text('80')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pointsTile, matching: find.text('Points')),
        findsOneWidget,
      );
    });

    testWidgets('show 0 for a member with no bikes and no points', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        homeState: const HomeLoaded(
          DashboardStatsEntity(
            status: 'AKTIF',
            memberId: 'M-001',
            memberName: 'Stats Member',
            emailAddress: '-',
            phoneNo: '87700001111',
            active: true,
            qty: 0,
            point: 0,
            detail: [],
            detail2: [],
          ),
        ),
      );

      expect(
        find.descendant(of: bikeTile, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pointsTile, matching: find.text('0')),
        findsOneWidget,
      );
    });

    testWidgets('are compact but still a comfortable tap target', (
      tester,
    ) async {
      await pumpProfile(tester);

      final height = tester.getSize(bikeTile).height;

      // Material's minimum touch target is 48; the old card was 120 tall.
      expect(height, greaterThanOrEqualTo(48));
      expect(height, lessThanOrEqualTo(70));
    });

    testWidgets('share the width equally', (tester) async {
      await pumpProfile(tester);

      expect(tester.getSize(bikeTile).width, tester.getSize(pointsTile).width);
    });

    testWidgets('no longer use a divider or a fixed-height card', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('tapping Bikes opens My Bikes', (tester) async {
      await pumpProfile(tester);

      await tester.tap(bikeTile);
      await tester.pumpAndSettle();

      expect(find.text('my-bikes-page'), findsOneWidget);
    });

    testWidgets('tapping Points opens the Member tab', (tester) async {
      await pumpProfile(tester);

      await tester.tap(pointsTile);
      await tester.pumpAndSettle();

      expect(find.text('membership-page'), findsOneWidget);
    });

    testWidgets('grow instead of clipping at a large font size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpProfile(tester);

      // A RenderFlex overflow would be reported as a test exception.
      expect(tester.takeException(), isNull);
      expect(tester.getSize(bikeTile).height, greaterThan(70));
    });
  });
}
