import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/my_bikes_page.dart';

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

/// Every value filled in.
const tFull = BikeEntity(
  line: '1',
  unitId: 'YAMAHA R25',
  plateNo: 'L 1234 AB',
  chasisNo: 'MH3RG1',
  engineNo: 'G3E1',
  color: 'Hitam',
  year: '2023',
);

/// Only what the backend always sends.
const tBare = BikeEntity(
  line: '2',
  unitId: 'HONDA BEAT',
  plateNo: 'B 5678 CD',
  chasisNo: '',
  engineNo: '',
  color: '',
  year: '',
);

/// What the Add Bike stand-in pops with, so a test can say "a bike was added"
/// or "the member backed out".
const _popTrue = Key('stand-in-pop-true');
const _popNothing = Key('stand-in-pop-nothing');

/// The same two exits on the Edit Bike stand-in: "a bike was saved" or "the
/// member backed out".
const _editPopTrue = Key('stand-in-edit-pop-true');
const _editPopNothing = Key('stand-in-edit-pop-nothing');

/// Opens My Bikes with a mock [BikesBloc] in [state]. Add Bike and Edit Bike
/// are stand-in pages with two buttons each, so the page's reaction to their
/// result can be checked. Edit Bike's names the bike it was handed.
///
/// [states] lets a test push what the bloc emits next (a delete finishing, say);
/// [refreshCubit] stands in for the app-wide one that a finished delete signals.
Future<MockBikesBloc> pumpMyBikes(
  WidgetTester tester, {
  BikesState state = const BikesLoaded([tFull]),
  ThemeData? theme,
  Stream<BikesState> states = const Stream<BikesState>.empty(),
  DataRefreshCubit? refreshCubit,
}) async {
  final bloc = MockBikesBloc();
  whenListen(bloc, states, initialState: state);
  sl.registerFactory<BikesBloc>(() => bloc);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const MyBikesPage()),
      GoRoute(
        path: RouteNames.addBike,
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('add-bike-page'),
              ElevatedButton(
                key: _popTrue,
                onPressed: () => context.pop(true),
                child: const Text('added'),
              ),
              ElevatedButton(
                key: _popNothing,
                onPressed: () => context.pop(),
                child: const Text('back'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.editBike,
        builder: (context, routeState) => Scaffold(
          body: Column(
            children: [
              Text('edit-bike-page:${(routeState.extra as BikeEntity).unitId}'),
              ElevatedButton(
                key: _editPopTrue,
                onPressed: () => context.pop(true),
                child: const Text('saved'),
              ),
              ElevatedButton(
                key: _editPopNothing,
                onPressed: () => context.pop(),
                child: const Text('back'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  final app = MaterialApp.router(theme: theme, routerConfig: router);
  await tester.pumpWidget(
    refreshCubit == null
        ? app
        : BlocProvider.value(value: refreshCubit, child: app),
  );
  // Settles the first frame, in which the page mounts its overlay panels.
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  setUpAll(() => registerFallbackValue(const BikesLoadRequested()));
  tearDown(() => sl.reset());

  final confirmPanel = find.byKey(const Key('confirm-panel'));
  final confirmButton = find.byKey(const Key('confirm-panel-confirm'));
  final cancelButton = find.byKey(const Key('confirm-panel-cancel'));
  final editRow = find.byKey(const Key('bike-edit'));
  final deleteRow = find.byKey(const Key('bike-delete'));
  final moreActions = find.byTooltip('Aksi lainnya');

  group('what it shows', () {
    testWidgets('asks for the bikes when it opens', (tester) async {
      final bloc = await pumpMyBikes(tester);

      verify(() => bloc.add(const BikesLoadRequested())).called(1);
    });

    testWidgets('lists a bike with its plate line and its numbers', (
      tester,
    ) async {
      await pumpMyBikes(tester);

      expect(find.text('YAMAHA R25'), findsOneWidget);
      expect(find.text('L 1234 AB - Hitam - 2023'), findsOneWidget);
      expect(find.text('No Chasis'), findsOneWidget);
      expect(find.text('MH3RG1'), findsOneWidget);
      expect(find.text('No Mesin'), findsOneWidget);
      expect(find.text('G3E1'), findsOneWidget);
    });

    testWidgets('shows just the plate, and no number rows, for a bare bike', (
      tester,
    ) async {
      await pumpMyBikes(tester, state: const BikesLoaded([tBare]));

      expect(find.text('HONDA BEAT'), findsOneWidget);
      expect(find.text('B 5678 CD'), findsOneWidget);
      expect(find.text('No Chasis'), findsNothing);
      expect(find.text('No Mesin'), findsNothing);
    });

    testWidgets('hides only the number a bike does not have', (tester) async {
      await pumpMyBikes(
        tester,
        state: const BikesLoaded([
          BikeEntity(
            unitId: 'SUZUKI SATRIA',
            plateNo: 'N 9 EF',
            chasisNo: 'MH8',
            engineNo: '',
            color: '',
            year: '',
          ),
        ]),
      );

      expect(find.text('No Chasis'), findsOneWidget);
      expect(find.text('No Mesin'), findsNothing);
    });

    testWidgets('shows a spinner while the bikes load', (tester) async {
      final bloc = MockBikesBloc();
      whenListen(
        bloc,
        const Stream<BikesState>.empty(),
        initialState: const BikesLoading(),
      );
      sl.registerFactory<BikesBloc>(() => bloc);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const MyBikesPage()),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('says there are no bikes, with a way to add one', (
      tester,
    ) async {
      await pumpMyBikes(tester, state: const BikesLoaded([]));

      expect(find.text('Belum ada motor'), findsOneWidget);
      expect(find.text('No bikes added yet'), findsNothing);
      expect(
        find.widgetWithText(ElevatedButton, 'Tambah Motor'),
        findsOneWidget,
      );
    });

    testWidgets('shows the error with a retry that asks again', (tester) async {
      final bloc = await pumpMyBikes(
        tester,
        state: const BikesError('Server down'),
      );

      expect(find.text('Server down'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Coba lagi'));

      // Once on open, once for the retry.
      verify(() => bloc.add(const BikesLoadRequested())).called(2);
    });
  });

  group('adding a bike', () {
    testWidgets('the + button opens Add Bike', (tester) async {
      await pumpMyBikes(tester);

      await tester.tap(find.byTooltip('Tambah motor'));
      await tester.pumpAndSettle();

      expect(find.text('add-bike-page'), findsOneWidget);
    });

    testWidgets('the empty state\'s button opens Add Bike too', (tester) async {
      await pumpMyBikes(tester, state: const BikesLoaded([]));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Motor'));
      await tester.pumpAndSettle();

      expect(find.text('add-bike-page'), findsOneWidget);
    });

    testWidgets('reloads the list when a bike was added', (tester) async {
      final bloc = await pumpMyBikes(tester);

      await tester.tap(find.byTooltip('Tambah motor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_popTrue));
      await tester.pumpAndSettle();

      // Once on open, once for the reload.
      verify(() => bloc.add(const BikesLoadRequested())).called(2);
    });

    testWidgets('does not reload when the member just backed out', (
      tester,
    ) async {
      final bloc = await pumpMyBikes(tester);

      await tester.tap(find.byTooltip('Tambah motor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_popNothing));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const BikesLoadRequested())).called(1);
    });
  });

  group('editing a bike', () {
    /// Opens the sheet for the card at [index], then taps Edit.
    Future<void> tapEditFor(WidgetTester tester, {int index = 0}) async {
      await tester.tap(moreActions.at(index));
      await tester.pumpAndSettle();
      await tester.tap(editRow);
      await tester.pumpAndSettle();
    }

    testWidgets('Edit opens Edit Bike with the bike whose sheet it is', (
      tester,
    ) async {
      await pumpMyBikes(tester);

      await tapEditFor(tester);

      expect(find.text('edit-bike-page:YAMAHA R25'), findsOneWidget);
      // The sheet slid shut rather than staying open over the new page. A
      // closed panel keeps its rows in the tree, parked below the screen.
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getTopLeft(editRow).dy,
        greaterThanOrEqualTo(screen.height),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('hands over the bike that was tapped, not just the first', (
      tester,
    ) async {
      await pumpMyBikes(tester, state: const BikesLoaded([tFull, tBare]));

      await tapEditFor(tester, index: 1);

      expect(find.text('edit-bike-page:HONDA BEAT'), findsOneWidget);
      expect(find.text('edit-bike-page:YAMAHA R25'), findsNothing);
    });

    testWidgets('reloads the list when a bike was saved', (tester) async {
      final bloc = await pumpMyBikes(tester);

      await tapEditFor(tester);
      await tester.tap(find.byKey(_editPopTrue));
      await tester.pumpAndSettle();

      // Once on open, once for the reload.
      verify(() => bloc.add(const BikesLoadRequested())).called(2);
      expect(find.text('Motor Saya'), findsOneWidget);
    });

    testWidgets('does not reload when the member just backed out', (
      tester,
    ) async {
      final bloc = await pumpMyBikes(tester);

      await tapEditFor(tester);
      await tester.tap(find.byKey(_editPopNothing));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const BikesLoadRequested())).called(1);
      expect(find.text('YAMAHA R25'), findsOneWidget);
    });

    testWidgets('can edit again after coming back', (tester) async {
      await pumpMyBikes(tester);

      await tapEditFor(tester);
      await tester.tap(find.byKey(_editPopNothing));
      await tester.pumpAndSettle();
      await tapEditFor(tester);

      expect(find.text('edit-bike-page:YAMAHA R25'), findsOneWidget);
    });
  });

  group('the more-actions sheet', () {
    testWidgets('opens with an Edit and a Hapus row, inside the screen', (
      tester,
    ) async {
      await pumpMyBikes(tester);
      expect(editRow, findsNothing);

      await tester.tap(moreActions);
      await tester.pumpAndSettle();

      expect(editRow, findsOneWidget);
      expect(deleteRow, findsOneWidget);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getRect(deleteRow).bottom,
        lessThanOrEqualTo(screen.height),
      );
      // A sheet too small for its rows would have overflowed.
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws the rows like Profile\'s: peach tile, red Hapus', (
      tester,
    ) async {
      await pumpMyBikes(tester);
      await tester.tap(moreActions);
      await tester.pumpAndSettle();

      Color? tileColor(Finder row) =>
          (tester
                      .widget<Container>(
                        find.descendant(
                          of: row,
                          matching: find.byKey(const Key('row-icon-tile')),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color;

      expect(tileColor(editRow), AppColors.peachMist);
      expect(tileColor(deleteRow), AppColors.errorBackground);
      expect(
        tester
            .widget<Text>(
              find.descendant(of: deleteRow, matching: find.text('Hapus')),
            )
            .style
            ?.color,
        AppColors.error,
      );
    });

    testWidgets('Hapus asks first, in the sliding panel and not a dialog', (
      tester,
    ) async {
      await pumpMyBikes(tester);
      await tester.tap(moreActions);
      await tester.pumpAndSettle();

      await tester.tap(deleteRow);
      await tester.pumpAndSettle();

      expect(confirmPanel, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.descendant(of: confirmPanel, matching: find.text('Hapus Motor')),
        findsOneWidget,
      );
      // It names the bike being deleted.
      expect(
        find.descendant(
          of: confirmPanel,
          matching: find.textContaining('YAMAHA R25'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Batal closes the panel and leaves the list as it was', (
      tester,
    ) async {
      final bloc = await pumpMyBikes(tester);
      await tester.tap(moreActions);
      await tester.pumpAndSettle();
      await tester.tap(deleteRow);
      await tester.pumpAndSettle();

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(confirmPanel, findsNothing);
      expect(find.text('YAMAHA R25'), findsOneWidget);
      verify(() => bloc.add(const BikesLoadRequested())).called(1);
      // Declining sends no delete.
      verifyNever(() => bloc.add(any(that: isA<BikeDeleteRequested>())));
    });

    testWidgets('Hapus closes the panel and deletes that bike by its Line', (
      tester,
    ) async {
      final bloc = await pumpMyBikes(tester);
      await tester.tap(moreActions);
      await tester.pumpAndSettle();
      await tester.tap(deleteRow);
      await tester.pumpAndSettle();

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(confirmPanel, findsNothing);
      verify(() => bloc.add(const BikeDeleteRequested(line: '1'))).called(1);
    });

    testWidgets('deletes the bike whose actions were opened, not the first', (
      tester,
    ) async {
      final bloc = await pumpMyBikes(
        tester,
        state: const BikesLoaded([tFull, tBare]),
      );
      await tester.tap(moreActions.last);
      await tester.pumpAndSettle();
      await tester.tap(deleteRow);
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const BikeDeleteRequested(line: '2'))).called(1);
      verifyNever(() => bloc.add(const BikeDeleteRequested(line: '1')));
    });
  });

  group('after a delete', () {
    late StreamController<BikesState> states;

    setUp(() => states = StreamController<BikesState>());
    tearDown(() => states.close());

    testWidgets('says so in a snackbar and tells the stats to reload', (
      tester,
    ) async {
      final refreshCubit = DataRefreshCubit();
      await pumpMyBikes(
        tester,
        states: states.stream,
        refreshCubit: refreshCubit,
      );
      expect(refreshCubit.state.kind, isNull);

      states.add(const BikesDeleted('Bike deleted successfully'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Motor berhasil dihapus!'), findsOneWidget);
      // The bike count on Home, Membership and Profile has changed.
      expect(refreshCubit.state.kind, DataKind.stats);
    });

    testWidgets('shows the reload as a spinner, then the list without the '
        'bike', (tester) async {
      await pumpMyBikes(
        tester,
        states: states.stream,
        refreshCubit: DataRefreshCubit(),
      );

      states
        ..add(const BikesDeleted('Bike deleted successfully'))
        ..add(const BikesLoading());
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      states.add(const BikesLoaded([tBare]));
      await tester.pump();
      await tester.pump();

      expect(find.text('YAMAHA R25'), findsNothing);
      expect(find.text('HONDA BEAT'), findsOneWidget);
    });

    testWidgets('a refused delete shows the reason, signals nothing, and '
        'leaves the list to come back', (tester) async {
      final refreshCubit = DataRefreshCubit();
      await pumpMyBikes(
        tester,
        states: states.stream,
        refreshCubit: refreshCubit,
      );

      states
        ..add(const BikesError('Motor masih memiliki booking'))
        ..add(const BikesLoading())
        ..add(const BikesLoaded([tFull]));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Motor masih memiliki booking'), findsOneWidget);
      // The bike is still there, and no stats reload was asked for.
      expect(find.text('YAMAHA R25'), findsOneWidget);
      expect(refreshCubit.state.kind, isNull);
      expect(find.text('Motor berhasil dihapus!'), findsNothing);
    });
  });

  group('the warm colouring', () {
    testWidgets('puts the warm wash behind the page, from the very top', (
      tester,
    ) async {
      await pumpMyBikes(tester);

      final wash = find.byType(WarmWash);
      expect(wash, findsOneWidget);
      expect(tester.getTopLeft(wash).dy, 0);
      // The bar and the Scaffold are transparent, so the wash shows through
      // behind them, as on the Profile page.
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
    });

    testWidgets('edges a bike card with the warm hairline, 12 px corners', (
      tester,
    ) async {
      await pumpMyBikes(tester);

      final card = tester
          .element(find.text('YAMAHA R25'))
          .findAncestorWidgetOfExactType<Material>()!;
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.peachHairline);
      expect(shape.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('puts the bike\'s thumbnail on a peach tile with an orange '
        'icon', (tester) async {
      await pumpMyBikes(tester);

      final tile = find.byWidgetPredicate(
        (w) => w is Container && w.color == AppColors.peachMist,
      );
      expect(tile, findsOneWidget);
      expect(tester.getSize(tile), const Size(64, 64));
      final icon = tester.widget<Icon>(
        find.descendant(
          of: tile,
          matching: find.byIcon(Icons.two_wheeler_outlined),
        ),
      );
      expect(icon.color, AppColors.primary);
    });

    testWidgets('keeps the card pale and its text dark in the dark theme', (
      tester,
    ) async {
      await pumpMyBikes(tester, theme: AppTheme.dark);

      final card = tester
          .element(find.text('YAMAHA R25'))
          .findAncestorWidgetOfExactType<Material>()!;
      expect(card.color!.computeLuminance(), greaterThan(0.5));
      expect(
        tester
            .widget<Text>(find.text('YAMAHA R25'))
            .style!
            .color!
            .computeLuminance(),
        lessThan(0.5),
      );
    });

    testWidgets('leaves the empty message on the page\'s own theme in dark', (
      tester,
    ) async {
      await pumpMyBikes(
        tester,
        state: const BikesLoaded([]),
        theme: AppTheme.dark,
      );

      // On the black page, so it must not take the pale card's dark text.
      final text = tester.widget<Text>(find.text('Belum ada motor'));
      final color = text.style?.color;
      expect(color == null || color.computeLuminance() > 0.5, isTrue);
    });
  });
}
