import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/profile_page.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

const tUser = UserEntity(
  id: 'M-001',
  name: 'Test Member',
  status: 'Active',
  isActive: true,
);

BikeEntity bike(int n) => BikeEntity(
  unitId: 'YAMAHA $n',
  plateNo: 'L $n AB',
  chasisNo: '',
  engineNo: '',
  color: '',
  year: '',
);

/// The page builds its own BikesBloc through GetIt, so each test registers a
/// mock one in the state it wants to see.
Future<MockBikesBloc> pumpProfile(
  WidgetTester tester, {
  ProfilePage? page,
  BikesState bikesState = const BikesLoaded([]),
}) async {
  final bikesBloc = MockBikesBloc();
  whenListen(
    bikesBloc,
    const Stream<BikesState>.empty(),
    initialState: bikesState,
  );
  sl.registerFactory<BikesBloc>(() => bikesBloc);

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
        builder: (_, _) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: page ?? const ProfilePage(),
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
  return bikesBloc;
}

void main() {
  final settingsButton = find.widgetWithIcon(
    IconButton,
    Icons.settings_outlined,
  );
  final logoutButton = find.widgetWithIcon(IconButton, Icons.logout);
  final bikeColumn = find.byKey(const Key('bike-count-column'));

  tearDown(() => sl.reset());

  testWidgets('the app ships with the theme switch off', (tester) async {
    expect(AppConstants.themeSwitchEnabled, isFalse);
  });

  testWidgets('hides the Settings button by default while the switch is off', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(settingsButton, findsNothing);
    // Everything else in the bar is untouched.
    expect(logoutButton, findsOneWidget);
  });

  testWidgets('shows the Settings button again when turned back on', (
    tester,
  ) async {
    await pumpProfile(tester, page: const ProfilePage());

    expect(settingsButton, findsOneWidget);
    expect(logoutButton, findsOneWidget);
  });

  group('stat tiles', () {
    testWidgets('are compact but still a comfortable tap target', (
      tester,
    ) async {
      await pumpProfile(tester);

      final height = tester.getSize(bikeColumn).height;

      // Material's minimum touch target is 48; the old card was 120 tall.
      expect(height, greaterThanOrEqualTo(48));
      expect(height, lessThanOrEqualTo(70));
    });

    testWidgets('share the width equally', (tester) async {
      await pumpProfile(tester);

      expect(
        tester.getSize(bikeColumn).width,
        tester.getSize(find.byKey(const Key('points-stat-tile'))).width,
      );
    });

    testWidgets('no longer use a divider or a fixed-height card', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('tapping Bikes opens My Bikes', (tester) async {
      await pumpProfile(tester);

      await tester.tap(bikeColumn);
      await tester.pumpAndSettle();

      expect(find.text('my-bikes-page'), findsOneWidget);
    });

    testWidgets('tapping Points opens the Member tab', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.byKey(const Key('points-stat-tile')));
      await tester.pumpAndSettle();

      expect(find.text('membership-page'), findsOneWidget);
    });
  });

  group('bike count column', () {
    testWidgets('asks the API for the bikes when the page opens', (
      tester,
    ) async {
      final bloc = await pumpProfile(tester);

      verify(() => bloc.add(const BikesLoadRequested())).called(1);
    });

    testWidgets('shows icon, the number of bikes, and the label', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        bikesState: BikesLoaded([bike(1), bike(2), bike(3)]),
      );

      expect(
        find.descendant(
          of: bikeColumn,
          matching: find.byIcon(Icons.two_wheeler_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bikeColumn, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bikeColumn, matching: find.text('My Bikes')),
        findsOneWidget,
      );
    });

    testWidgets('shows 0 when the member has no bikes yet', (tester) async {
      await pumpProfile(tester);

      expect(
        find.descendant(of: bikeColumn, matching: find.text('0')),
        findsOneWidget,
      );
    });

    testWidgets('shows a spinner while loading, with icon and label already '
        'in place', (tester) async {
      await pumpProfile(tester, bikesState: const BikesLoading());

      expect(
        find.descendant(
          of: bikeColumn,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bikeColumn,
          matching: find.byIcon(Icons.two_wheeler_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bikeColumn, matching: find.text('My Bikes')),
        findsOneWidget,
      );
    });

    testWidgets('shows a dash when the bikes fail to load', (tester) async {
      await pumpProfile(tester, bikesState: const BikesError('boom'));

      expect(
        find.descendant(of: bikeColumn, matching: find.text('–')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bikeColumn,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('grows instead of clipping at a large font size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpProfile(tester, bikesState: BikesLoaded([bike(1)]));

      // A RenderFlex overflow would be reported as a test exception.
      expect(tester.takeException(), isNull);
      expect(tester.getSize(bikeColumn).height, greaterThan(70));
    });
  });
}
