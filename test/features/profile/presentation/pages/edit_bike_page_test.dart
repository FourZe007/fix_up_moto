import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/edit_bike_page.dart';

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

/// A bike with every value filled in.
const tBike = BikeEntity(
  line: '7',
  unitId: 'YAMAHA R25',
  plateNo: 'L 1234 AB',
  chasisNo: 'MH3RG1',
  engineNo: 'G3E1',
  color: 'Hitam',
  year: '2023',
);

/// A 1x1 PNG, as the base64 a bike's photo could come back as.
const tPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA6'
    '0e6kgAAAABJRU5ErkJggg==';

void main() {
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

  setUp(() => states = StreamController<BikesState>());

  tearDown(() async {
    await states.close();
    await sl.reset();
  });

  /// Opens the edit page for [bike] on top of a stand-in My Bikes page,
  /// returning the future that completes with whatever the page pops with.
  Future<Future<bool?>> openEditBikePage(
    WidgetTester tester, {
    BikeEntity bike = tBike,
    BikesState initialState = const BikesInitial(),
    ThemeData? theme,
  }) async {
    bloc = MockBikesBloc();
    whenListen(bloc, states.stream, initialState: initialState);
    sl.registerFactory<BikesBloc>(() => bloc);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('my-bikes')),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => EditBikePage(bike: bike),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: theme, routerConfig: router),
    );
    final result = router.push<bool>('/edit');
    await tester.pumpAndSettle();
    return result;
  }

  final unitField = find.widgetWithText(TextFormField, 'Merek & Model');
  final colorField = find.widgetWithText(TextFormField, 'Warna');
  final yearField = find.widgetWithText(TextFormField, 'Tahun');
  final plateField = find.widgetWithText(TextFormField, 'Plat Nomor');
  final chasisField = find.widgetWithText(TextFormField, 'No Chasis');
  final engineField = find.widgetWithText(TextFormField, 'No Mesin');
  final saveButton = find.widgetWithText(ElevatedButton, 'Simpan');
  final emptyPhotoIcon = find.byIcon(Icons.camera_alt_outlined);
  final confirmPanel = find.byKey(const Key('confirm-panel'));
  final confirmButton = find.byKey(const Key('confirm-panel-confirm'));
  final cancelButton = find.byKey(const Key('confirm-panel-cancel'));

  TextField inputOf(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      );

  String textOf(WidgetTester tester, Finder field) =>
      inputOf(tester, field).controller!.text;

  /// What the page sent the bloc: the one update event.
  BikeUpdateRequested sentUpdate() =>
      verify(() => bloc.add(captureAny())).captured.single
          as BikeUpdateRequested;

  group('what it shows', () {
    testWidgets('is titled Ubah Motor, with a Simpan button', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      expect(find.text('Ubah Motor'), findsOneWidget);
      expect(saveButton, findsOneWidget);
      expect(find.text('Tambah Motor'), findsNothing);
    });

    testWidgets('prefills every field from the bike', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      expect(textOf(tester, unitField), 'YAMAHA R25');
      expect(textOf(tester, colorField), 'Hitam');
      expect(textOf(tester, yearField), '2023');
      expect(textOf(tester, plateField), 'L 1234 AB');
      expect(textOf(tester, chasisField), 'MH3RG1');
      expect(textOf(tester, engineField), 'G3E1');
    });

    testWidgets('lets every field be edited, the plate included', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      // The plate is no longer the bike's key (the Line is), so it isn't locked.
      for (final field in [
        unitField,
        colorField,
        yearField,
        plateField,
        chasisField,
        engineField,
      ]) {
        expect(inputOf(tester, field).enabled, isTrue);
      }
      expect(find.byKey(const Key('plate-locked-note')), findsNothing);
      expect(find.text('Nomor polisi tidak dapat diubah'), findsNothing);
    });

    testWidgets('shows an empty photo box for a bike with no photo', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      expect(emptyPhotoIcon, findsOneWidget);
    });

    testWidgets('shows the bike\'s own photo in the box when it has one', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(
        tester,
        bike: const BikeEntity(
          unitId: 'YAMAHA R25',
          plateNo: 'L 1234 AB',
          chasisNo: '',
          engineNo: '',
          color: '',
          year: '',
          photo: tPhoto,
        ),
      );

      expect(emptyPhotoIcon, findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('sits on the warm wash, with a transparent bar', (
      tester,
    ) async {
      await openEditBikePage(tester);

      final wash = find.byType(WarmWash);
      expect(wash, findsOneWidget);
      expect(tester.getTopLeft(wash).dy, 0);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );
    });

    testWidgets('keeps the empty photo box orange', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      expect(tester.widget<Icon>(emptyPhotoIcon).color, AppColors.primary);
    });
  });

  group('saving', () {
    testWidgets('sends the bike back as it was when nothing was changed', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      await tester.tap(saveButton);
      await tester.pump();

      expect(
        sentUpdate(),
        const BikeUpdateRequested(
          line: '7',
          plateNo: 'L 1234 AB',
          unitId: 'YAMAHA R25',
          chasisNo: 'MH3RG1',
          engineNo: 'G3E1',
          color: 'Hitam',
          year: '2023',
          photo: '',
        ),
      );
    });

    testWidgets(
      'sends the trimmed edits, with the Line still the bike\'s own',
      (tester) async {
        useTallScreen(tester);
        await openEditBikePage(tester);

        await tester.enterText(unitField, '  Yamaha NMAX ');
        await tester.enterText(colorField, ' Merah ');
        await tester.enterText(yearField, '2024');
        await tester.enterText(chasisField, ' mh3rg2 ');
        await tester.enterText(engineField, ' g3e2 ');
        await tester.tap(saveButton);
        await tester.pump();

        expect(
          sentUpdate(),
          const BikeUpdateRequested(
            line: '7',
            plateNo: 'L 1234 AB',
            unitId: 'Yamaha NMAX',
            chasisNo: 'mh3rg2',
            engineNo: 'g3e2',
            color: 'Merah',
            year: '2024',
            photo: '',
          ),
        );
      },
    );

    testWidgets('sends a changed plate trimmed and upper-cased, the Line '
        'unchanged', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      await tester.enterText(plateField, ' b 9 zz ');
      await tester.tap(saveButton);
      await tester.pump();

      final sent = sentUpdate();
      expect(sent.plateNo, 'B 9 ZZ');
      // Which bike this is rides on the Line, not on the plate being edited.
      expect(sent.line, '7');
    });

    testWidgets('holds back a malformed plate, as Add Bike does', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      await tester.enterText(plateField, 'A');
      await tester.tap(saveButton);
      await tester.pump();

      expect(
        find.text('Masukkan plat nomor yang valid (contoh: L 1234 AB)'),
        findsOneWidget,
      );
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('asks for a stored plate that fails the format check to be '
        'corrected, now that it can be', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(
        tester,
        bike: const BikeEntity(
          line: '9',
          unitId: 'HONDA BEAT',
          // Hyphens and lower case: nothing the add form would accept.
          plateNo: 'b-5678-cd',
          chasisNo: '',
          engineNo: '',
          color: '',
          year: '',
        ),
      );

      await tester.tap(saveButton);
      await tester.pump();

      expect(
        find.text('Masukkan plat nomor yang valid (contoh: L 1234 AB)'),
        findsOneWidget,
      );
      verifyNever(() => bloc.add(any()));

      await tester.enterText(plateField, 'B 5678 CD');
      await tester.tap(saveButton);
      await tester.pump();

      final sent = sentUpdate();
      expect(sent.plateNo, 'B 5678 CD');
      expect(sent.line, '9');
    });

    testWidgets('allows clearing the optional fields', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      await tester.enterText(colorField, '');
      await tester.enterText(yearField, '');
      await tester.enterText(chasisField, '');
      await tester.enterText(engineField, '');
      await tester.tap(saveButton);
      await tester.pump();

      final sent = sentUpdate();
      expect(sent.color, '');
      expect(sent.year, '');
      expect(sent.chasisNo, '');
      expect(sent.engineNo, '');
    });

    testWidgets('still asks for the make', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      await tester.enterText(unitField, '   ');
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Merek & Model wajib diisi'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('still refuses a year that cannot be right', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      await tester.enterText(yearField, '1800');
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Masukkan tahun yang valid'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('cannot be sent twice while a save is in flight', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester, initialState: const BikesLoading());

      expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNull);
    });
  });

  group('the photo', () {
    const bikeWithPhoto = BikeEntity(
      unitId: 'YAMAHA R25',
      plateNo: 'L 1234 AB',
      chasisNo: '',
      engineNo: '',
      color: '',
      year: '',
      photo: tPhoto,
    );

    testWidgets('goes back exactly as it came when it was not touched', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester, bike: bikeWithPhoto);

      await tester.tap(saveButton);
      await tester.pump();

      expect(sentUpdate().photo, tPhoto);
    });

    testWidgets('is asked about first, in the sliding panel and not a dialog', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester, bike: bikeWithPhoto);

      // The close badge on the photo's corner.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(confirmPanel, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.descendant(of: confirmPanel, matching: find.text('Hapus Foto')),
        findsOneWidget,
      );
      // Still there while the member decides.
      expect(emptyPhotoIcon, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays when the member says Batal, and goes back as it came', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester, bike: bikeWithPhoto);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(confirmPanel, findsNothing);
      expect(emptyPhotoIcon, findsNothing);

      await tester.tap(saveButton);
      await tester.pump();

      expect(sentUpdate().photo, tPhoto);
    });

    testWidgets('is sent as empty once the member confirms removing it', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester, bike: bikeWithPhoto);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(confirmPanel, findsNothing);
      expect(emptyPhotoIcon, findsOneWidget);

      await tester.tap(saveButton);
      await tester.pump();

      expect(sentUpdate().photo, '');
    });

    testWidgets('drops the keyboard before the panel slides up', (
      tester,
    ) async {
      useTallScreen(tester);
      await openEditBikePage(tester, bike: bikeWithPhoto);

      await tester.tap(unitField);
      await tester.pump();
      EditableText unitInput() => tester.widget<EditableText>(
        find.descendant(of: unitField, matching: find.byType(EditableText)),
      );
      expect(unitInput().focusNode.hasFocus, isTrue);

      // A tap on the badge doesn't take focus from the field by itself.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(confirmPanel, findsOneWidget);
      expect(unitInput().focusNode.hasFocus, isFalse);
    });

    testWidgets('is not touched by a bike that never had one', (tester) async {
      useTallScreen(tester);
      await openEditBikePage(tester);

      await tester.tap(saveButton);
      await tester.pump();

      expect(sentUpdate().photo, '');
    });
  });

  group('the result', () {
    testWidgets('goes back with true, saying so, once the bike is updated', (
      tester,
    ) async {
      final result = await openEditBikePage(tester);

      states.add(const BikesUpdated('Bike updated successfully'));
      await tester.pumpAndSettle();

      // My Bikes reloads its own list when this is true.
      expect(await result, isTrue);
      expect(find.text('my-bikes'), findsOneWidget);
      expect(find.text('Motor berhasil diperbarui!'), findsOneWidget);
    });

    testWidgets('stays put and shows the reason when saving fails', (
      tester,
    ) async {
      final result = await openEditBikePage(tester);
      var finished = false;
      unawaited(result.whenComplete(() => finished = true));

      states.add(const BikesError('Plat nomor tidak ditemukan'));
      await tester.pumpAndSettle();

      expect(find.text('Plat nomor tidak ditemukan'), findsOneWidget);
      expect(find.text('Ubah Motor'), findsOneWidget);
      expect(find.text('my-bikes'), findsNothing);
      expect(finished, isFalse);
    });

    testWidgets('the back arrow leaves without a result', (tester) async {
      final result = await openEditBikePage(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(await result, isNull);
      expect(find.text('my-bikes'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });
  });
}
