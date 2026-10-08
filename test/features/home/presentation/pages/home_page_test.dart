import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/home/presentation/pages/home_page.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_bloc.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_event.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_state.dart';
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

/// Pumped in the loading state, which is just a spinner: the reload wiring
/// doesn't depend on what the loaded page contains, and the loaded page pulls
/// in the promo carousel and workshop picker.
Future<MockHomeBloc> pumpHome(WidgetTester tester) async {
  final home = MockHomeBloc();
  whenListen(
    home,
    const Stream<HomeState>.empty(),
    initialState: const HomeLoading(),
  );
  sl.registerFactory<HomeBloc>(() => home);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(value: refreshCubit, child: const HomePage()),
    ),
  );
  return home;
}

/// Pumped in the loaded state, inside a router so that a tap which navigates
/// has somewhere to go: `/profile` is a stand-in for the Profile tab.
///
/// The promo carousel is given a failed state, which collapses it, so nothing
/// animates and `pumpAndSettle` settles.
Future<void> pumpLoadedHome(WidgetTester tester) async {
  final home = MockHomeBloc();
  whenListen(
    home,
    const Stream<HomeState>.empty(),
    initialState: const HomeLoaded(tStats),
  );
  sl.registerFactory<HomeBloc>(() => home);

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
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('profile-tab')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: refreshCubit),
        BlocProvider(create: (_) => SelectedWorkshopCubit()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => refreshCubit = DataRefreshCubit());
  tearDown(() => sl.reset());

  testWidgets('asks for the stats when the page opens', (tester) async {
    final home = await pumpHome(tester);

    verify(() => home.add(const HomeStatsRequested())).called(1);
  });

  testWidgets('reloads when the stats go out of date elsewhere', (
    tester,
  ) async {
    final home = await pumpHome(tester);

    refreshCubit.invalidate(DataKind.stats);
    await tester.pump();

    // Once on open, once for the signal.
    verify(() => home.add(const HomeStatsRequested())).called(2);
  });

  testWidgets('ignores bookings going out of date', (tester) async {
    final home = await pumpHome(tester);

    refreshCubit.invalidate(DataKind.bookings);
    await tester.pump();

    verify(() => home.add(const HomeStatsRequested())).called(1);
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
