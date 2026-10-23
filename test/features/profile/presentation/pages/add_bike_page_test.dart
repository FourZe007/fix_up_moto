import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/add_bike_page.dart';

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

void main() {
  late DataRefreshCubit refreshCubit;
  late StreamController<BikesState> states;
  late MockBikesBloc bloc;

  setUpAll(() => registerFallbackValue(const BikesLoadRequested()));

  /// The whole form on screen, so every field can be typed into and the photo
  /// box at its foot is visible.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    refreshCubit = DataRefreshCubit();
    states = StreamController<BikesState>();
  });

  tearDown(() async {
    await states.close();
    await sl.reset();
  });

  /// Opens the add-bike page on top of a stand-in My Bikes page, returning the
  /// future that completes with whatever the page pops with.
  Future<Future<bool?>> openAddBikePage(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    bloc = MockBikesBloc();
    whenListen(bloc, states.stream, initialState: const BikesInitial());
    sl.registerFactory<BikesBloc>(() => bloc);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('my-bikes')),
        ),
        GoRoute(path: '/add', builder: (_, _) => const AddBikePage()),
      ],
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: refreshCubit,
        child: MaterialApp.router(theme: theme, routerConfig: router),
      ),
    );
    final result = router.push<bool>('/add');
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('adding a bike tells Home, Membership and Profile to reload', (
    tester,
  ) async {
    await openAddBikePage(tester);
    expect(refreshCubit.state.kind, isNull);

    states.add(const BikesAdded('Bike added successfully'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, DataKind.stats);
  });

  testWidgets('it still pops with true so My Bikes reloads its own list', (
    tester,
  ) async {
    final result = await openAddBikePage(tester);

    states.add(const BikesAdded('Bike added successfully'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect(find.text('my-bikes'), findsOneWidget);
  });

  testWidgets('a failed add does not signal anything', (tester) async {
    await openAddBikePage(tester);

    states.add(const BikesError('Server down'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, isNull);
    expect(find.text('my-bikes'), findsNothing);
  });

  group('the form', () {
    final unitField = find.widgetWithText(TextFormField, 'Merek & Model');
    final colorField = find.widgetWithText(TextFormField, 'Warna');
    final yearField = find.widgetWithText(TextFormField, 'Tahun');
    final plateField = find.widgetWithText(TextFormField, 'Plat Nomor');
    final chasisField = find.widgetWithText(TextFormField, 'No Chasis');
    final engineField = find.widgetWithText(TextFormField, 'No Mesin');
    final addButton = find.widgetWithText(ElevatedButton, 'Tambah Motor');

    testWidgets('keeps its six fields, in two titled groups and a photo', (
      tester,
    ) async {
      useTallScreen(tester);
      await openAddBikePage(tester);

      for (final field in [
        unitField,
        colorField,
        yearField,
        plateField,
        chasisField,
        engineField,
      ]) {
        expect(field, findsOneWidget);
      }
      for (final title in ['Informasi Motor', 'Registrasi', 'Foto']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('asks for the make and the plate before it sends anything', (
      tester,
    ) async {
      useTallScreen(tester);
      await openAddBikePage(tester);

      await tester.tap(addButton);
      await tester.pump();

      expect(find.text('Merek & Model wajib diisi'), findsOneWidget);
      expect(find.text('Plat nomor wajib diisi'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('refuses a malformed plate', (tester) async {
      useTallScreen(tester);
      await openAddBikePage(tester);

      await tester.enterText(unitField, 'Honda Beat');
      await tester.enterText(plateField, 'A');
      await tester.tap(addButton);
      await tester.pump();

      expect(
        find.text('Masukkan plat nomor yang valid (contoh: L 1234 AB)'),
        findsOneWidget,
      );
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('refuses a year that cannot be right', (tester) async {
      useTallScreen(tester);
      await openAddBikePage(tester);

      await tester.enterText(unitField, 'Honda Beat');
      await tester.enterText(plateField, 'L 1234 AB');
      await tester.enterText(yearField, '1800');
      await tester.tap(addButton);
      await tester.pump();

      expect(find.text('Masukkan tahun yang valid'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('sends the trimmed values with an upper-cased plate and no '
        'photo', (tester) async {
      useTallScreen(tester);
      await openAddBikePage(tester);

      await tester.enterText(unitField, '  Honda Supra X 125 ');
      await tester.enterText(colorField, ' Hitam ');
      await tester.enterText(yearField, '2023');
      await tester.enterText(plateField, ' l 1234 ab ');
      await tester.enterText(chasisField, ' MH3RG1 ');
      await tester.enterText(engineField, ' G3E1 ');
      await tester.tap(addButton);
      await tester.pump();

      verify(
        () => bloc.add(
          const BikeAddRequested(
            plateNumber: 'L 1234 AB',
            unitId: 'Honda Supra X 125',
            chasisNo: 'MH3RG1',
            engineNo: 'G3E1',
            color: 'Hitam',
            year: '2023',
            photo: '',
          ),
        ),
      ).called(1);
    });

    testWidgets('asks the keyboard for capitals on the plate and numbers', (
      tester,
    ) async {
      useTallScreen(tester);
      await openAddBikePage(tester);

      TextCapitalization capitalizationOf(Finder field) => tester
          .widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          )
          .textCapitalization;

      expect(capitalizationOf(plateField), TextCapitalization.characters);
      expect(capitalizationOf(chasisField), TextCapitalization.characters);
      expect(capitalizationOf(engineField), TextCapitalization.characters);
      expect(capitalizationOf(unitField), TextCapitalization.none);
    });
  });

  group('the warm colouring', () {
    testWidgets('puts the warm wash behind the page, with a transparent bar', (
      tester,
    ) async {
      await openAddBikePage(tester);

      final wash = find.byType(WarmWash);
      expect(wash, findsOneWidget);
      expect(tester.getTopLeft(wash).dy, 0);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        Colors.transparent,
      );
    });

    testWidgets('sets the group titles in the dark red, as Profile does', (
      tester,
    ) async {
      await openAddBikePage(tester, theme: AppTheme.light);

      final title = tester.widget<Text>(find.text('Informasi Motor'));
      expect(title.style?.color, AppColors.primaryDark);
    });

    testWidgets('sets them in the light orange on the dark theme', (
      tester,
    ) async {
      await openAddBikePage(tester, theme: AppTheme.dark);

      final title = tester.widget<Text>(find.text('Informasi Motor'));
      expect(title.style?.color, AppColors.primaryLight);
    });

    testWidgets('draws the empty photo box in orange on a peach fill', (
      tester,
    ) async {
      useTallScreen(tester);
      await openAddBikePage(tester);

      expect(
        tester
            .widget<Icon>(find.byIcon(Icons.camera_alt_outlined))
            .color,
        AppColors.primary,
      );
    });
  });
}
