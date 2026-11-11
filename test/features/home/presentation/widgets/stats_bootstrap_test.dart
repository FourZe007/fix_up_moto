import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/stats_bootstrap.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

const tUser = UserEntity(
  id: 'M-001',
  name: 'Test Member',
  status: 'Active',
  isActive: true,
);

const tStats = DashboardStatsEntity(
  status: 'AKTIF',
  memberId: 'M-001',
  memberName: 'Test Member',
  emailAddress: '-',
  phoneNo: '81234567890',
  active: true,
  qty: 0,
  point: 0,
  detail: [],
  detail2: [],
);

void main() {
  late MockAuthBloc auth;
  late MockHomeBloc home;
  late StreamController<AuthState> authStates;
  late DataRefreshCubit refresh;

  setUpAll(() => registerFallbackValue(const HomeStatsRequested()));

  setUp(() {
    refresh = DataRefreshCubit();
    authStates = StreamController<AuthState>.broadcast();
    addTearDown(authStates.close);
  });

  /// Mounts the bootstrap with the given auth state and home state in place.
  Future<void> pumpBootstrap(
    WidgetTester tester, {
    AuthState authState = const AuthUnauthenticated(),
    HomeState homeState = const HomeInitial(),
  }) async {
    auth = MockAuthBloc();
    whenListen(auth, authStates.stream, initialState: authState);
    home = MockHomeBloc();
    whenListen(home, const Stream<HomeState>.empty(), initialState: homeState);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<HomeBloc>.value(value: home),
          BlocProvider<DataRefreshCubit>.value(value: refresh),
        ],
        child: const MaterialApp(
          home: StatsBootstrap(child: Text('the app')),
        ),
      ),
    );
    // Lets the post-frame check for an already-live session run.
    await tester.pump();
  }

  /// A change of auth state, as AuthBloc would announce it.
  Future<void> authBecomes(WidgetTester tester, AuthState state) async {
    authStates.add(state);
    await tester.pump();
  }

  testWidgets('draws nothing of its own', (tester) async {
    await pumpBootstrap(tester);

    expect(find.text('the app'), findsOneWidget);
  });

  group('sign-in', () {
    testWidgets('loads the stats, once', (tester) async {
      await pumpBootstrap(tester);

      await authBecomes(tester, const AuthAuthenticated(tUser));

      verify(() => home.add(const HomeStatsRequested())).called(1);
    });

    testWidgets('does nothing while a sign-in is merely in flight', (
      tester,
    ) async {
      await pumpBootstrap(tester);

      await authBecomes(tester, const AuthLoading());

      verifyNever(() => home.add(any()));
    });

    testWidgets('a session already live at mount is loaded once', (
      tester,
    ) async {
      await pumpBootstrap(tester, authState: const AuthAuthenticated(tUser));

      verify(() => home.add(const HomeStatsRequested())).called(1);
    });

    testWidgets('a session already live is not loaded again if it already is', (
      tester,
    ) async {
      await pumpBootstrap(
        tester,
        authState: const AuthAuthenticated(tUser),
        homeState: const HomeLoaded(tStats),
      );

      verifyNever(() => home.add(any()));
    });

    testWidgets('opening while signed out loads nothing', (tester) async {
      await pumpBootstrap(tester);

      verifyNever(() => home.add(any()));
    });
  });

  group('sign-out', () {
    testWidgets('clears the stats, once', (tester) async {
      await pumpBootstrap(tester, authState: const AuthAuthenticated(tUser));
      clearInteractions(home);

      await authBecomes(tester, const AuthUnauthenticated());

      verify(() => home.add(const HomeResetRequested())).called(1);
      verifyNever(() => home.add(const HomeStatsRequested()));
    });
  });

  group('when the stats go out of date', () {
    testWidgets('one invalidate(stats) is exactly one reload', (tester) async {
      await pumpBootstrap(
        tester,
        authState: const AuthAuthenticated(tUser),
        homeState: const HomeLoaded(tStats),
      );

      refresh.invalidate(DataKind.stats);
      await tester.pump();

      verify(() => home.add(const HomeStatsRequested())).called(1);
    });

    testWidgets('invalidate(bookings) is none of its business', (tester) async {
      await pumpBootstrap(
        tester,
        authState: const AuthAuthenticated(tUser),
        homeState: const HomeLoaded(tStats),
      );

      refresh.invalidate(DataKind.bookings);
      await tester.pump();

      verifyNever(() => home.add(any()));
    });

    testWidgets('nothing is reloaded for a member who is signed out', (
      tester,
    ) async {
      await pumpBootstrap(tester);

      refresh.invalidate(DataKind.stats);
      await tester.pump();

      verifyNever(() => home.add(any()));
    });
  });
}
