import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/cupertino.dart' show CupertinoAlertDialog;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/bookings/domain/entities/booking_entity.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/models/booking_date_range.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/bookings_page.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';
import 'package:fix_up_moto/features/services/presentation/pages/services_page.dart';

class MockBookingsBloc extends MockBloc<BookingsEvent, BookingsState>
    implements BookingsBloc {}

class MockServicesBloc extends MockBloc<ServicesEvent, ServicesState>
    implements ServicesBloc {}

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

const r25 = BikeEntity(
  line: '1',
  unitId: 'YAMAHA R25',
  plateNo: 'B 1234 XY',
  chasisNo: '',
  engineNo: '',
  color: '',
  year: '',
);

const beat = BikeEntity(
  line: '2',
  unitId: 'HONDA BEAT',
  plateNo: 'D 5678 CD',
  chasisNo: '',
  engineNo: '',
  color: '',
  year: '',
);

late DataRefreshCubit refreshCubit;

/// The page's Riwayat side: the mock bloc it asks for history, the mock bloc it
/// loads the bikes from, and the stream a test pushes the bikes' answer into.
late MockServicesBloc services;
late MockBikesBloc bikes;
late StreamController<BikesState> bikeStates;

/// Opens Bookings with a mock bloc in [state] (no bookings unless told), on
/// [theme] (the default theme unless told). The bikes never answer until a test
/// pushes [BikesLoaded] (or another state) into [bikeStates].
Future<MockBookingsBloc> pumpBookings(
  WidgetTester tester, {
  BookingsState state = const BookingsLoaded([]),
  ThemeData? theme,
}) async {
  final bookings = MockBookingsBloc();
  whenListen(
    bookings,
    const Stream<BookingsState>.empty(),
    initialState: state,
  );
  sl.registerFactory<BookingsBloc>(() => bookings);

  // An empty, loaded history rather than "loading": a spinner never stops
  // animating, so a test could not pumpAndSettle with Riwayat on screen.
  services = MockServicesBloc();
  whenListen(
    services,
    const Stream<ServicesState>.empty(),
    initialState: const ServicesLoaded([]),
  );
  sl.registerFactory<ServicesBloc>(() => services);

  bikeStates = StreamController<BikesState>();
  bikes = MockBikesBloc();
  whenListen(bikes, bikeStates.stream, initialState: const BikesInitial());
  sl.registerFactory<BikesBloc>(() => bikes);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: BlocProvider.value(
        value: refreshCubit,
        child: const BookingsPage(),
      ),
    ),
  );
  return bookings;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      BookingsListRequested(
        range: DateTimeRange(start: DateTime(2026), end: DateTime(2026)),
      ),
    );
    registerFallbackValue(const ServicesListRequested(plateNo: 'X 1 Y'));
    registerFallbackValue(const BikesLoadRequested());
  });
  setUp(() => refreshCubit = DataRefreshCubit());
  tearDown(() async {
    // Not awaited: nobody may have listened to it, and closing a controller
    // nobody listened to only finishes once somebody does.
    unawaited(bikeStates.close());
    await sl.reset();
  });

  testWidgets('loads the bookings for its date range when the page opens', (
    tester,
  ) async {
    final bloc = await pumpBookings(tester);

    verify(() => bloc.add(any(that: isA<BookingsListRequested>()))).called(1);
  });

  testWidgets('reloads straight away when a booking is created elsewhere', (
    tester,
  ) async {
    final bloc = await pumpBookings(tester);

    // The create page signals this after a booking succeeds; this tab is alive
    // underneath, so it reloads without anyone opening it.
    refreshCubit.invalidate(DataKind.bookings);
    await tester.pump();

    // Once on open, once for the signal.
    verify(() => bloc.add(any(that: isA<BookingsListRequested>()))).called(2);
  });

  testWidgets('reloads with the same date range it was showing', (
    tester,
  ) async {
    final bloc = await pumpBookings(tester);

    refreshCubit.invalidate(DataKind.bookings);
    await tester.pump();

    final requests = verify(
      () => bloc.add(captureAny(that: isA<BookingsListRequested>())),
    ).captured.cast<BookingsListRequested>();
    expect(requests, hasLength(2));
    expect(requests[1].range, requests[0].range);
  });

  testWidgets('ignores stats going out of date', (tester) async {
    final bloc = await pumpBookings(tester);

    refreshCubit.invalidate(DataKind.stats);
    await tester.pump();

    verify(() => bloc.add(any(that: isA<BookingsListRequested>()))).called(1);
  });

  group('the booking card colours', () {
    final booking = BookingEntity(
      id: 'B1',
      bsName: 'FIXUP MOTO - KUTISARI',
      bsAddress: 'Jl. Kutisari',
      scheduledAt: DateTime.now().add(const Duration(days: 3)),
      plateNo: 'L 1234 AB',
      unitId: 'YAMAHA R25',
      status: 'MENUNGGU KONFIRMASI',
      notes: 'Bawa STNK',
    );

    Future<void> pumpCard(WidgetTester tester, {BookingEntity? entity}) =>
        pumpBookings(tester, state: BookingsLoaded([entity ?? booking]));

    Color? colorOf(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    testWidgets('a white surface with a warm hairline, not a grey outline', (
      tester,
    ) async {
      await pumpCard(tester);

      final card = tester.widget<Card>(find.byType(Card).first);
      final side = (card.shape! as RoundedRectangleBorder).side;
      expect(side.color, AppColors.peachHairline);
      expect(card.elevation, 0);
      expect(
        card.color,
        Theme.of(tester.element(find.byType(Card).first)).colorScheme.surface,
      );
    });

    testWidgets('the date, the bike and the notes are one soft grey', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(
        colorOf(tester, DateTimeFormatter.toFullDateTime(booking.scheduledAt)),
        AppColors.grey700,
      );
      expect(colorOf(tester, 'L 1234 AB · YAMAHA R25'), AppColors.grey700);
      expect(colorOf(tester, 'Bawa STNK'), AppColors.grey700);
    });

    testWidgets('the divider is the same warm hairline', (tester) async {
      await pumpCard(tester);

      final divider = find.descendant(
        of: find.byType(Card).first,
        matching: find.byType(Divider),
      );
      expect(tester.widget<Divider>(divider).color, AppColors.peachHairline);
    });

    testWidgets('the status is plain coloured text, not a tinted badge', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(colorOf(tester, 'MENUNGGU KONFIRMASI'), AppColors.warning);
      // Nothing in the card draws a fill or rounded outline of its own.
      final boxes = find.descendant(
        of: find.byType(Card).first,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final decoration = w.decoration;
          return decoration is BoxDecoration &&
              (decoration.color != null || decoration.borderRadius != null);
        }),
      );
      expect(boxes, findsNothing);
    });

    testWidgets('any other status stays neutral grey', (tester) async {
      await pumpCard(
        tester,
        entity: BookingEntity(
          id: 'B2',
          bsName: 'FIXUP MOTO - KUTISARI',
          bsAddress: 'Jl. Kutisari',
          scheduledAt: DateTime.now().add(const Duration(days: 3)),
          plateNo: 'L 1234 AB',
          unitId: 'YAMAHA R25',
          status: 'SELESAI',
        ),
      );

      expect(colorOf(tester, 'SELESAI'), AppColors.grey600);
    });
  });

  group('cancelling a booking', () {
    // A few days out: after tomorrow's start of the default range and before
    // its month-long end, so the page lists it, and it has not happened yet.
    final upcoming = BookingEntity(
      id: 'B1',
      bsName: 'FIXUP MOTO - KUTISARI',
      bsAddress: 'Jl. Kutisari',
      scheduledAt: DateTime.now().add(const Duration(days: 3)),
      plateNo: 'L 1234 AB',
      unitId: 'YAMAHA R25',
      status: 'MENUNGGU KONFIRMASI',
    );

    Future<MockBookingsBloc> pumpWithBooking(
      WidgetTester tester, {
      ThemeData? theme,
    }) => pumpBookings(tester, state: BookingsLoaded([upcoming]), theme: theme);

    Future<void> longPressBooking(WidgetTester tester) async {
      await tester.longPress(find.byType(Card).first);
      await tester.pumpAndSettle();
    }

    testWidgets('long-pressing an upcoming booking asks first', (tester) async {
      final bloc = await pumpWithBooking(tester);

      await longPressBooking(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel Booking'), findsOneWidget);
      // Nothing is cancelled just by asking.
      verifyNever(() => bloc.add(any(that: isA<BookingCancelRequested>())));
    });

    testWidgets('No closes the question and cancels nothing', (tester) async {
      final bloc = await pumpWithBooking(tester);
      await longPressBooking(tester);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => bloc.add(any(that: isA<BookingCancelRequested>())));
    });

    testWidgets('Yes, Cancel closes it and cancels that booking, once', (
      tester,
    ) async {
      final bloc = await pumpWithBooking(tester);
      await longPressBooking(tester);

      await tester.tap(find.text('Yes, Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verify(() => bloc.add(const BookingCancelRequested('B1'))).called(1);
    });

    testWidgets('on iOS the question is an iOS alert, and still works', (
      tester,
    ) async {
      final bloc = await pumpWithBooking(
        tester,
        theme: ThemeData(platform: TargetPlatform.iOS),
      );

      await longPressBooking(tester);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('Yes, Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      verify(() => bloc.add(const BookingCancelRequested('B1'))).called(1);
    });
  });

  group('Date filter panel', () {
    final panelTitle = find.text('Filter Tanggal');
    final fromCard = find.byKey(const Key('bookings-filter-from'));
    final apply = find.byKey(const Key('bookings-filter-apply'));
    final reset = find.byKey(const Key('bookings-filter-reset'));
    final custom = find.byKey(const Key('bookings-preset-custom'));
    final rangeChip = find.byKey(const Key('bookings-range-chip'));
    final picker = find.byType(DateRangePickerDialog);

    Finder preset(BookingRangePreset p) =>
        find.byKey(Key('bookings-preset-${p.name}'));

    bool selected(WidgetTester tester, Finder chip) =>
        tester.widget<ChoiceChip>(chip).selected;

    DateTimeRange on(BookingRangePreset p) => p.rangeOn(DateTime.now());

    Future<void> openPanel(WidgetTester tester) async {
      // A frame after the page's first, in case anything mounts after it.
      await tester.pump();
      // By icon: the tooltip reads "(aktif)" once a range has been applied.
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
    }

    /// Picks [p] in the open panel and applies it.
    Future<void> applyPreset(WidgetTester tester, BookingRangePreset p) async {
      await tester.tap(preset(p));
      await tester.pump();
      await tester.tap(apply);
      await tester.pumpAndSettle();
    }

    /// The ranges the page asked the bloc for, oldest first.
    List<DateTimeRange> requestedRanges(MockBookingsBloc bloc) =>
        verify(() => bloc.add(captureAny(that: isA<BookingsListRequested>())))
            .captured
            .cast<BookingsListRequested>()
            .map((request) => request.range)
            .toList();

    testWidgets('opens from the filter button, and is not there before', (
      tester,
    ) async {
      await pumpBookings(tester);
      expect(panelTitle, findsNothing);

      await openPanel(tester);

      expect(panelTitle, findsOneWidget);
      expect(find.text('Pilihan cepat'), findsOneWidget);
      expect(find.text('Rentang tanggal'), findsOneWidget);
    });

    testWidgets('starts on the range the page shows: 1 bulan', (tester) async {
      await pumpBookings(tester);
      await openPanel(tester);

      for (final p in BookingRangePreset.values) {
        expect(
          selected(tester, preset(p)),
          p == BookingRangePreset.month,
          reason: p.label,
        );
      }
      expect(selected(tester, custom), isFalse);
      expect(find.text(on(BookingRangePreset.month).summary), findsOneWidget);
    });

    testWidgets('each shortcut sets the range and the line under the cards', (
      tester,
    ) async {
      await pumpBookings(tester);
      await openPanel(tester);

      for (final p in BookingRangePreset.values) {
        await tester.tap(preset(p));
        await tester.pump();

        expect(selected(tester, preset(p)), isTrue, reason: p.label);
        expect(find.text(on(p).summary), findsOneWidget, reason: p.label);
      }
    });

    testWidgets('Terapkan applies the shortcut, closes and reloads', (
      tester,
    ) async {
      final bloc = await pumpBookings(tester);
      await openPanel(tester);

      await applyPreset(tester, BookingRangePreset.week);

      expect(panelTitle, findsNothing);
      // Once on open, once for Terapkan.
      expect(requestedRanges(bloc), [
        on(BookingRangePreset.month),
        on(BookingRangePreset.week),
      ]);
    });

    testWidgets('nothing reaches the page until Terapkan', (tester) async {
      final bloc = await pumpBookings(tester);
      await openPanel(tester);

      await tester.tap(preset(BookingRangePreset.threeMonths));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bookings-filter-close')));
      await tester.pumpAndSettle();

      expect(panelTitle, findsNothing);
      expect(requestedRanges(bloc), hasLength(1));
    });

    testWidgets('Dari and Sampai open the range picker above the panel', (
      tester,
    ) async {
      await pumpBookings(tester);
      await openPanel(tester);

      await tester.tap(fromCard);
      await tester.pumpAndSettle();
      expect(picker, findsOneWidget);

      // Saving is a tap on the picker itself. Were the panel (and its dimmed
      // backdrop) painted over the picker, this tap would land on the backdrop
      // and the picker would stay.
      await tester.tap(
        find.descendant(of: picker, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();

      expect(picker, findsNothing);
      // Back on the panel, which stayed open underneath.
      expect(panelTitle, findsOneWidget);
    });

    testWidgets('a range picked by hand selects Pilih sendiri', (tester) async {
      await pumpBookings(tester);
      await openPanel(tester);

      await tester.tap(custom);
      await tester.pumpAndSettle();
      // Typing the two dates is the one way to pick days that does not depend
      // on which month the calendar opens on.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final today = DateUtils.dateOnly(DateTime.now());
      final start = DateUtils.addDaysToDate(today, 10);
      final end = DateUtils.addDaysToDate(today, 12);
      String typed(DateTime d) =>
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.day.toString().padLeft(2, '0')}/${d.year}';
      // Scoped to the picker: the page's own search box is a TextField too.
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), typed(start));
      await tester.enterText(fields.at(1), typed(end));
      await tester.pump();
      // Typing mode has a Batal button beside the Simpan one.
      await tester.tap(
        find.descendant(of: picker, matching: find.text('Simpan')),
      );
      await tester.pumpAndSettle();

      expect(selected(tester, custom), isTrue);
      for (final p in BookingRangePreset.values) {
        expect(selected(tester, preset(p)), isFalse, reason: p.label);
      }
      expect(
        tester
            .widget<Text>(find.byKey(const Key('bookings-filter-summary')))
            .data,
        DateTimeRange(start: start, end: end).summary,
      );
    });

    testWidgets('typing a date uses a keyboard that has a "/" key', (
      tester,
    ) async {
      await pumpBookings(tester);
      await openPanel(tester);

      await tester.tap(custom);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // The default datetime pad is digits-only on many phones, so a date could
      // not be typed with its separators. Scoped to the picker: the page's own
      // search box is a TextField too.
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextField),
      );
      expect(fields, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        expect(
          tester.widget<TextField>(fields.at(i)).keyboardType,
          TextInputType.text,
          reason: i == 0 ? 'start date' : 'end date',
        );
      }
    });

    testWidgets('Reset goes back to the default, closes and reloads', (
      tester,
    ) async {
      final bloc = await pumpBookings(tester);
      await openPanel(tester);
      await applyPreset(tester, BookingRangePreset.threeMonths);
      await openPanel(tester);

      await tester.tap(reset);
      await tester.pumpAndSettle();

      expect(panelTitle, findsNothing);
      expect(requestedRanges(bloc), [
        on(BookingRangePreset.month),
        on(BookingRangePreset.threeMonths),
        on(BookingRangePreset.month),
      ]);
    });

    testWidgets('opens on the range that is applied', (tester) async {
      await pumpBookings(tester);
      await openPanel(tester);
      await applyPreset(tester, BookingRangePreset.threeMonths);

      await openPanel(tester);

      expect(selected(tester, preset(BookingRangePreset.threeMonths)), isTrue);
      expect(selected(tester, preset(BookingRangePreset.month)), isFalse);
    });

    testWidgets('the back button closes the panel, not the page', (
      tester,
    ) async {
      await pumpBookings(tester);
      await openPanel(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(panelTitle, findsNothing);
      expect(find.byType(BookingsPage), findsOneWidget);
    });

    testWidgets('tapping the dimmed area closes the panel', (tester) async {
      await pumpBookings(tester);
      await openPanel(tester);

      // Well above the panel, which sits at the bottom of the screen.
      await tester.tapAt(const Offset(400, 40));
      await tester.pumpAndSettle();

      expect(panelTitle, findsNothing);
    });

    testWidgets('opens again after it was closed', (tester) async {
      await pumpBookings(tester);
      await openPanel(tester);
      await tester.tap(reset);
      await tester.pumpAndSettle();

      await openPanel(tester);

      expect(panelTitle, findsOneWidget);
    });

    group('the page says a filter is on', () {
      bool dotShown(WidgetTester tester) =>
          tester.widget<Badge>(find.byType(Badge)).isLabelVisible;

      testWidgets('not while the default range is showing', (tester) async {
        await pumpBookings(tester);
        await tester.pump();

        expect(rangeChip, findsNothing);
        expect(dotShown(tester), isFalse);
        expect(find.byTooltip('Filter tanggal'), findsOneWidget);
      });

      testWidgets('a dot and a chip once another range is applied', (
        tester,
      ) async {
        await pumpBookings(tester);
        await openPanel(tester);

        await applyPreset(tester, BookingRangePreset.week);

        expect(dotShown(tester), isTrue);
        expect(find.byTooltip('Filter tanggal (aktif)'), findsOneWidget);
        expect(rangeChip, findsOneWidget);
        expect(
          find.descendant(
            of: rangeChip,
            matching: find.text(on(BookingRangePreset.week).chipLabel),
          ),
          findsOneWidget,
        );
      });

      testWidgets('the chip opens the panel', (tester) async {
        await pumpBookings(tester);
        await openPanel(tester);
        await applyPreset(tester, BookingRangePreset.week);

        await tester.tap(rangeChip);
        await tester.pumpAndSettle();

        expect(panelTitle, findsOneWidget);
      });

      testWidgets("the chip's cross goes back to the default and reloads", (
        tester,
      ) async {
        final bloc = await pumpBookings(tester);
        await openPanel(tester);
        await applyPreset(tester, BookingRangePreset.week);

        await tester.tap(find.byTooltip('Hapus filter tanggal'));
        await tester.pumpAndSettle();

        expect(rangeChip, findsNothing);
        expect(dotShown(tester), isFalse);
        expect(requestedRanges(bloc).last, on(BookingRangePreset.month));
      });

      testWidgets('applying the default range again shows no chip', (
        tester,
      ) async {
        await pumpBookings(tester);
        await openPanel(tester);
        await applyPreset(tester, BookingRangePreset.week);

        await openPanel(tester);
        await applyPreset(tester, BookingRangePreset.month);

        expect(rangeChip, findsNothing);
      });
    });
  });

  group('Riwayat', () {
    final panelTitle = find.text('Filter Riwayat');
    final plateChip = find.byKey(const Key('history-plate-chip'));
    final rangeChip = find.byKey(const Key('history-range-chip'));
    final apply = find.byKey(const Key('bookings-filter-apply'));
    final reset = find.byKey(const Key('bookings-filter-reset'));
    final noBikes = find.byKey(const Key('history-no-bikes'));
    final retry = find.byKey(const Key('history-bikes-retry'));
    final filterButton = find.widgetWithIcon(IconButton, Icons.tune);

    Finder plate(BikeEntity bike) =>
        find.byKey(Key('history-plate-${bike.plateNo}'));

    bool selected(WidgetTester tester, Finder chip) =>
        tester.widget<ChoiceChip>(chip).selected;

    /// The panel is taller than the default test screen allows without
    /// scrolling.
    void useTallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    /// The bikes' answer arrives.
    Future<void> bikesLoaded(WidgetTester tester, List<BikeEntity> list) async {
      bikeStates.add(BikesLoaded(list));
      await tester.pump();
      await tester.pump();
    }

    /// Not pumpAndSettle: before a bike is known Riwayat shows a spinner, which
    /// never stops animating. The tab slide takes 300 ms.
    Future<void> openRiwayat(WidgetTester tester) async {
      await tester.tap(find.text('Riwayat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> openPanel(WidgetTester tester) async {
      await tester.tap(filterButton);
      await tester.pumpAndSettle();
    }

    /// The plates the page asked the services bloc about, oldest first.
    List<String> requestedPlates() =>
        verify(
              () =>
                  services.add(captureAny(that: isA<ServicesListRequested>())),
            ).captured
            .cast<ServicesListRequested>()
            .map((request) => request.plateNo)
            .toList();

    group('loading', () {
      testWidgets('asks for the bikes when it opens, and for no history yet', (
        tester,
      ) async {
        await pumpBookings(tester);

        verify(() => bikes.add(const BikesLoadRequested())).called(1);
        // The backend answers per plate, so there is nothing to ask until one
        // is known (this used to ask at once, with no plate at all).
        verifyNever(
          () => services.add(any(that: isA<ServicesListRequested>())),
        );
      });

      testWidgets('asks for the first bike once the bikes arrive', (
        tester,
      ) async {
        await pumpBookings(tester);

        await bikesLoaded(tester, [r25, beat]);

        expect(requestedPlates(), ['B 1234 XY']);
      });

      testWidgets('asks for it with Riwayat never opened', (tester) async {
        await pumpBookings(tester);

        // Still on My Bookings, so the TabBarView never built Riwayat: the page
        // itself, not that tab, listens for the bikes.
        await bikesLoaded(tester, [beat]);

        expect(requestedPlates(), ['D 5678 CD']);
      });

      testWidgets('a bike list that reloads unchanged asks for nothing more', (
        tester,
      ) async {
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);

        bikeStates.add(const BikesLoading());
        await tester.pump();
        await bikesLoaded(tester, [r25, beat]);

        expect(requestedPlates(), ['B 1234 XY']);
      });

      testWidgets('reloads the bikes when one is added, edited or deleted', (
        tester,
      ) async {
        await pumpBookings(tester);

        refreshCubit.invalidate(DataKind.bikes);
        await tester.pump();

        // Once on open, once for the signal.
        verify(() => bikes.add(const BikesLoadRequested())).called(2);
      });

      testWidgets('ignores stats and bookings going out of date', (
        tester,
      ) async {
        await pumpBookings(tester);

        refreshCubit
          ..invalidate(DataKind.stats)
          ..invalidate(DataKind.bookings);
        await tester.pump();

        verify(() => bikes.add(const BikesLoadRequested())).called(1);
      });
    });

    group('when the bikes change', () {
      testWidgets('the chosen bike stays while it is still there', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
        await openPanel(tester);
        await tester.tap(plate(beat));
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        // The list reloads (say another bike was added); the chosen one is
        // still in it.
        await bikesLoaded(tester, [r25, beat]);

        expect(requestedPlates(), ['B 1234 XY', 'D 5678 CD']);
      });

      testWidgets('falls back to the first bike when the chosen one is gone', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
        await openPanel(tester);
        await tester.tap(plate(beat));
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        // The member deleted (or re-plated) the bike that was showing.
        await bikesLoaded(tester, [r25]);

        expect(requestedPlates(), ['B 1234 XY', 'D 5678 CD', 'B 1234 XY']);
        expect(
          find.descendant(
            of: plateChip,
            matching: find.text('B 1234 XY · YAMAHA R25'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('with no bike left there is nothing to show or ask', (
        tester,
      ) async {
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25]);
        await openRiwayat(tester);
        expect(plateChip, findsOneWidget);

        await bikesLoaded(tester, []);

        expect(plateChip, findsNothing);
        expect(noBikes, findsOneWidget);
        // Nothing was asked for the empty list: just the one first request.
        expect(requestedPlates(), ['B 1234 XY']);
      });

      testWidgets('a bike added later is picked up and shown', (tester) async {
        await pumpBookings(tester);
        await bikesLoaded(tester, []);
        await openRiwayat(tester);
        expect(noBikes, findsOneWidget);

        await bikesLoaded(tester, [r25]);

        expect(noBikes, findsNothing);
        expect(plateChip, findsOneWidget);
        expect(requestedPlates(), ['B 1234 XY']);
      });
    });

    group('before there is a bike to show', () {
      testWidgets('a spinner while the bikes are loading', (tester) async {
        await pumpBookings(tester);
        bikeStates.add(const BikesLoading());
        await tester.pump();

        await openRiwayat(tester);

        expect(find.text('Loading...'), findsOneWidget);
        expect(noBikes, findsNothing);
      });

      testWidgets('says so, and offers My Bikes, when the member has none', (
        tester,
      ) async {
        await pumpBookings(tester);
        await bikesLoaded(tester, []);

        await openRiwayat(tester);

        expect(noBikes, findsOneWidget);
        expect(find.text('Belum ada motor terdaftar'), findsOneWidget);
        expect(find.text('Motor Saya'), findsOneWidget);
        expect(plateChip, findsNothing);
      });

      testWidgets(
        'shows the failure, and Muat Ulang asks for the bikes again',
        (tester) async {
          await pumpBookings(tester);
          bikeStates.add(const BikesError('Koneksi terputus'));
          await tester.pump();
          await openRiwayat(tester);

          expect(find.text('Koneksi terputus'), findsOneWidget);
          await tester.tap(retry);
          await tester.pump();

          // Once on open, once for the retry.
          verify(() => bikes.add(const BikesLoadRequested())).called(2);
        },
      );

      testWidgets('the filter button waits for a bike, then works', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await openRiwayat(tester);

        expect(tester.widget<IconButton>(filterButton).onPressed, isNull);

        await bikesLoaded(tester, [r25]);

        expect(tester.widget<IconButton>(filterButton).onPressed, isNotNull);
        await openPanel(tester);
        expect(panelTitle, findsOneWidget);
      });
    });

    group('the chips under the tabs', () {
      testWidgets('say which bike, plate and model, on Riwayat only', (
        tester,
      ) async {
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);

        // My Bookings has no bike.
        expect(plateChip, findsNothing);

        await openRiwayat(tester);

        expect(
          find.descendant(
            of: plateChip,
            matching: find.text('B 1234 XY · YAMAHA R25'),
          ),
          findsOneWidget,
        );
      });

      testWidgets("My Bookings' range chip does not follow to Riwayat", (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25]);
        await tester.tap(find.byIcon(Icons.tune));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('bookings-preset-${BookingRangePreset.week.name}')),
        );
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bookings-range-chip')), findsOneWidget);

        await openRiwayat(tester);

        expect(find.byKey(const Key('bookings-range-chip')), findsNothing);
        expect(rangeChip, findsNothing);
      });

      testWidgets('the plate chip opens the panel', (tester) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25]);
        await openRiwayat(tester);

        await tester.tap(plateChip);
        await tester.pumpAndSettle();

        expect(panelTitle, findsOneWidget);
      });
    });

    group('the panel', () {
      testWidgets('is the Riwayat one here and the date one on My Bookings', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);

        // My Bookings: dates only, no bike to choose.
        await openPanel(tester);
        expect(find.text('Filter Tanggal'), findsOneWidget);
        expect(find.text('Motor'), findsNothing);
        expect(plate(r25), findsNothing);
        await tester.tap(find.byKey(const Key('bookings-filter-close')));
        await tester.pumpAndSettle();

        // Riwayat: the bikes, then the dates.
        await openRiwayat(tester);
        await openPanel(tester);
        expect(panelTitle, findsOneWidget);
        expect(find.text('Filter Tanggal'), findsNothing);
        expect(find.text('Motor'), findsOneWidget);
        expect(plate(r25), findsOneWidget);
        expect(plate(beat), findsOneWidget);
      });

      testWidgets('offers no "all bikes": one is always chosen, the first at '
          'first', (tester) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);

        await openPanel(tester);

        expect(find.textContaining('Semua motor'), findsNothing);
        expect(selected(tester, plate(r25)), isTrue);
        expect(selected(tester, plate(beat)), isFalse);
      });

      // The date section is the one My Bookings has, untouched: the same five
      // shortcuts, the two date cards and the summary line.
      testWidgets('has the same date section as My Bookings', (tester) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25]);
        await openRiwayat(tester);

        await openPanel(tester);

        expect(find.text('Pilihan cepat'), findsOneWidget);
        expect(find.text('Rentang tanggal'), findsOneWidget);
        for (final preset in BookingRangePreset.values) {
          final chip = find.byKey(Key('bookings-preset-${preset.name}'));
          expect(chip, findsOneWidget, reason: preset.label);
          expect(
            selected(tester, chip),
            preset == BookingRangePreset.month,
            reason: preset.label,
          );
        }
        expect(
          selected(tester, find.byKey(const Key('bookings-preset-custom'))),
          isFalse,
        );
        expect(find.byKey(const Key('bookings-filter-from')), findsOneWidget);
        expect(find.byKey(const Key('bookings-filter-to')), findsOneWidget);
        expect(
          find.text(BookingRangePreset.defaultRange(DateTime.now()).summary),
          findsOneWidget,
        );
        // Nothing of the look-back set from before.
        expect(find.text('Semua tanggal'), findsNothing);
        expect(find.text('30 hari terakhir'), findsNothing);
        expect(find.text('Tahun ini'), findsNothing);
      });

      testWidgets('each shortcut sets the range and the line under the cards', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25]);
        await openRiwayat(tester);
        await openPanel(tester);

        for (final preset in BookingRangePreset.values) {
          final chip = find.byKey(Key('bookings-preset-${preset.name}'));
          await tester.tap(chip);
          await tester.pump();

          expect(selected(tester, chip), isTrue, reason: preset.label);
          expect(
            find.text(preset.rangeOn(DateTime.now()).summary),
            findsOneWidget,
            reason: preset.label,
          );
        }
      });

      testWidgets('Pilih sendiri and the date cards open the range picker', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25]);
        await openRiwayat(tester);
        await openPanel(tester);

        // The panel opens on a range that starts tomorrow, so the picker has to
        // allow it: a picker that refused it would throw instead of opening.
        await tester.tap(find.byKey(const Key('bookings-preset-custom')));
        await tester.pumpAndSettle();
        expect(find.byType(DateRangePickerDialog), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.descendant(
            of: find.byType(DateRangePickerDialog),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('bookings-filter-from')));
        await tester.pumpAndSettle();
        expect(find.byType(DateRangePickerDialog), findsOneWidget);
      });
    });

    group('many bikes', () {
      const lihatSemua = 'Lihat Semua';
      const lebihSedikit = 'Tampilkan lebih sedikit';
      final toggle = find.byKey(const Key('history-plates-toggle'));

      /// [count] bikes, "B 1000 XY" for the first, "B 1001 XY" for the next...
      List<BikeEntity> fleet(int count) => [
        for (var i = 0; i < count; i++)
          BikeEntity(
            line: '${i + 1}',
            unitId: 'MODEL $i',
            plateNo: 'B ${1000 + i} XY',
            chasisNo: '',
            engineNo: '',
            color: '',
            year: '',
          ),
      ];

      Finder chipOf(List<BikeEntity> bikes, int index) => plate(bikes[index]);

      Future<List<BikeEntity>> openWith(WidgetTester tester, int count) async {
        useTallScreen(tester);
        final bikes = fleet(count);
        await pumpBookings(tester);
        await bikesLoaded(tester, bikes);
        await openRiwayat(tester);
        await openPanel(tester);
        return bikes;
      }

      testWidgets('five bikes all show, and there is no button', (
        tester,
      ) async {
        final bikes = await openWith(tester, 5);

        for (var i = 0; i < 5; i++) {
          expect(chipOf(bikes, i), findsOneWidget, reason: 'bike ${i + 1}');
        }
        expect(find.text(lihatSemua), findsNothing);
        expect(find.text(lebihSedikit), findsNothing);
        expect(toggle, findsNothing);
      });

      testWidgets('fewer than five show whole, with no button either', (
        tester,
      ) async {
        await openWith(tester, 2);

        expect(toggle, findsNothing);
      });

      testWidgets('six bikes show the first five and Lihat Semua', (
        tester,
      ) async {
        final bikes = await openWith(tester, 6);

        for (var i = 0; i < 5; i++) {
          expect(chipOf(bikes, i), findsOneWidget, reason: 'bike ${i + 1}');
        }
        expect(chipOf(bikes, 5), findsNothing);
        expect(find.text(lihatSemua), findsOneWidget);
        expect(find.text(lebihSedikit), findsNothing);
      });

      testWidgets('Lihat Semua opens the rest and turns into Tampilkan lebih '
          'sedikit', (tester) async {
        final bikes = await openWith(tester, 7);

        await tester.tap(toggle);
        await tester.pump();

        for (var i = 0; i < 7; i++) {
          expect(chipOf(bikes, i), findsOneWidget, reason: 'bike ${i + 1}');
        }
        expect(find.text(lebihSedikit), findsOneWidget);
        expect(find.text(lihatSemua), findsNothing);
      });

      testWidgets('Tampilkan lebih sedikit goes back to the first five', (
        tester,
      ) async {
        final bikes = await openWith(tester, 7);
        await tester.tap(toggle);
        await tester.pump();

        await tester.tap(toggle);
        await tester.pump();

        expect(chipOf(bikes, 4), findsOneWidget);
        expect(chipOf(bikes, 5), findsNothing);
        expect(chipOf(bikes, 6), findsNothing);
        expect(find.text(lihatSemua), findsOneWidget);
      });

      group('the button sits at the right of the Motor title', () {
        final title = find.text('Motor');

        /// The panel's right edge: the screen less the panel's 20 of padding.
        double rightEdge(WidgetTester tester) =>
            tester.view.physicalSize.width / tester.view.devicePixelRatio - 20;

        void expectBesideTitle(WidgetTester tester) {
          // The middle of the button is the middle of the title.
          expect(
            tester.getCenter(toggle).dy,
            closeTo(tester.getCenter(title).dy, 1),
          );
          // At its right, not under it, and flush with the panel's right edge.
          expect(
            tester.getTopLeft(toggle).dx,
            greaterThanOrEqualTo(tester.getTopRight(title).dx),
          );
          expect(tester.getTopRight(toggle).dx, closeTo(rightEdge(tester), 1));
        }

        testWidgets('as Lihat Semua, centred on the title', (tester) async {
          await openWith(tester, 6);

          expectBesideTitle(tester);
        });

        testWidgets('and as Tampilkan lebih sedikit, once opened', (
          tester,
        ) async {
          await openWith(tester, 6);
          await tester.tap(toggle);
          await tester.pump();

          expect(find.text(lebihSedikit), findsOneWidget);
          expectBesideTitle(tester);
        });

        testWidgets('above the bikes, not below them', (tester) async {
          final bikes = await openWith(tester, 6);

          expect(
            tester.getBottomLeft(toggle).dy,
            lessThanOrEqualTo(tester.getTopLeft(chipOf(bikes, 0)).dy),
          );
          expect(
            tester.getTopLeft(toggle).dy,
            lessThan(tester.getTopLeft(chipOf(bikes, 4)).dy),
          );
        });

        testWidgets('without moving anything: the title row is as tall as any '
            'other', (tester) async {
          final bikes = await openWith(tester, 6);

          // Title to first chip is the same gap under "Motor", which has the
          // button beside it, as under "Pilihan cepat", which has none.
          final motorGap =
              tester.getTopLeft(chipOf(bikes, 0)).dy -
              tester.getTopLeft(title).dy;
          final shortcutGap =
              tester
                  .getTopLeft(
                    find.byKey(
                      Key('bookings-preset-${BookingRangePreset.week.name}'),
                    ),
                  )
                  .dy -
              tester.getTopLeft(find.text('Pilihan cepat')).dy;
          expect(motorGap, closeTo(shortcutGap, 1));
        });

        testWidgets('with five or fewer bikes the title row is plain', (
          tester,
        ) async {
          final bikes = await openWith(tester, 5);

          expect(toggle, findsNothing);
          // Nothing to the right of the title.
          expect(
            tester.getTopLeft(chipOf(bikes, 0)).dy -
                tester.getTopLeft(title).dy,
            closeTo(
              tester
                      .getTopLeft(
                        find.byKey(
                          Key(
                            'bookings-preset-${BookingRangePreset.week.name}',
                          ),
                        ),
                      )
                      .dy -
                  tester.getTopLeft(find.text('Pilihan cepat')).dy,
              1,
            ),
          );
        });
      });

      testWidgets('opening and closing the list changes nothing chosen', (
        tester,
      ) async {
        final bikes = await openWith(tester, 7);
        await tester.tap(chipOf(bikes, 2));
        await tester.pump();

        await tester.tap(toggle);
        await tester.pump();
        await tester.tap(toggle);
        await tester.pump();

        expect(selected(tester, chipOf(bikes, 2)), isTrue);
        expect(selected(tester, chipOf(bikes, 0)), isFalse);
      });

      testWidgets('a bike from the opened-up part can be chosen and applied', (
        tester,
      ) async {
        final bikes = await openWith(tester, 7);

        await tester.tap(toggle);
        await tester.pump();
        await tester.tap(chipOf(bikes, 6));
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        // The first bike on load, then the seventh.
        expect(requestedPlates(), ['B 1000 XY', 'B 1006 XY']);
      });

      testWidgets('opens already open when the applied bike is a hidden one', (
        tester,
      ) async {
        final bikes = await openWith(tester, 7);
        await tester.tap(toggle);
        await tester.pump();
        await tester.tap(chipOf(bikes, 5));
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        await openPanel(tester);

        // The current choice is in view, not tucked behind Lihat Semua.
        expect(chipOf(bikes, 5), findsOneWidget);
        expect(selected(tester, chipOf(bikes, 5)), isTrue);
        expect(find.text(lebihSedikit), findsOneWidget);
      });

      testWidgets('opens closed when the applied bike is among the first '
          'five', (tester) async {
        final bikes = await openWith(tester, 7);
        await tester.tap(chipOf(bikes, 3));
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        await openPanel(tester);

        expect(chipOf(bikes, 5), findsNothing);
        expect(find.text(lihatSemua), findsOneWidget);
      });

      testWidgets('Reset with a hidden bike chosen goes back to the first '
          'bike', (tester) async {
        final bikes = await openWith(tester, 7);
        await tester.tap(toggle);
        await tester.pump();
        await tester.tap(chipOf(bikes, 6));
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        await openPanel(tester);

        await tester.tap(reset);
        await tester.pumpAndSettle();

        expect(requestedPlates(), ['B 1000 XY', 'B 1006 XY', 'B 1000 XY']);
      });

      testWidgets('opening the list asks the backend for nothing', (
        tester,
      ) async {
        await openWith(tester, 7);

        await tester.tap(toggle);
        await tester.pump();

        expect(requestedPlates(), ['B 1000 XY']);
      });
    });

    group('applying it', () {
      testWidgets('another bike asks the backend about that plate', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
        await openPanel(tester);

        await tester.tap(plate(beat));
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        expect(panelTitle, findsNothing);
        // Once for the first bike, once for this one.
        expect(requestedPlates(), ['B 1234 XY', 'D 5678 CD']);
        expect(
          find.descendant(
            of: plateChip,
            matching: find.text('D 5678 CD · HONDA BEAT'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('nothing reaches the page until Terapkan', (tester) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
        await openPanel(tester);

        await tester.tap(plate(beat));
        await tester.pump();
        await tester.tap(find.byKey(const Key('bookings-filter-close')));
        await tester.pumpAndSettle();

        expect(requestedPlates(), ['B 1234 XY']);
        expect(
          find.descendant(
            of: plateChip,
            matching: find.textContaining('B 1234'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a date range alone asks the backend for nothing', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25]);
        await openRiwayat(tester);
        await openPanel(tester);

        await tester.tap(
          find.byKey(Key('bookings-preset-${BookingRangePreset.week.name}')),
        );
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        // Only the first load: the range is cut on the device.
        expect(requestedPlates(), ['B 1234 XY']);
        expect(rangeChip, findsOneWidget);
        expect(
          find.descendant(
            of: rangeChip,
            matching: find.text(
              BookingRangePreset.week.rangeOn(DateTime.now()).chipLabel,
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('opens again on what is applied', (tester) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
        await openPanel(tester);
        await tester.tap(plate(beat));
        await tester.tap(
          find.byKey(
            Key('bookings-preset-${BookingRangePreset.threeMonths.name}'),
          ),
        );
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        await openPanel(tester);

        expect(selected(tester, plate(beat)), isTrue);
        expect(selected(tester, plate(r25)), isFalse);
        expect(
          selected(
            tester,
            find.byKey(
              Key('bookings-preset-${BookingRangePreset.threeMonths.name}'),
            ),
          ),
          isTrue,
        );
      });

      testWidgets('Reset goes back to the first bike and every date', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
        await openPanel(tester);
        await tester.tap(plate(beat));
        await tester.tap(
          find.byKey(
            Key('bookings-preset-${BookingRangePreset.thisMonth.name}'),
          ),
        );
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        await openPanel(tester);

        await tester.tap(reset);
        await tester.pumpAndSettle();

        expect(panelTitle, findsNothing);
        expect(requestedPlates(), ['B 1234 XY', 'D 5678 CD', 'B 1234 XY']);
        expect(rangeChip, findsNothing);
        expect(
          find.descendant(
            of: plateChip,
            matching: find.textContaining('B 1234'),
          ),
          findsOneWidget,
        );
      });

      testWidgets("the range chip's cross takes the range off, not the bike", (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
        await openPanel(tester);
        await tester.tap(plate(beat));
        await tester.tap(
          find.byKey(
            Key('bookings-preset-${BookingRangePreset.thisMonth.name}'),
          ),
        );
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Hapus filter tanggal'));
        await tester.pumpAndSettle();

        expect(rangeChip, findsNothing);
        expect(
          find.descendant(
            of: plateChip,
            matching: find.textContaining('D 5678'),
          ),
          findsOneWidget,
        );
        // The range was only ever applied on the device.
        expect(requestedPlates(), ['B 1234 XY', 'D 5678 CD']);
      });
    });

    // The panel's date section is My Bookings' and opens on its default range
    // (tomorrow to a month ahead), which no past visit falls inside. On Riwayat
    // that default must therefore mean "no cut", or applying the panel after
    // only choosing a bike would hide every visit again.
    group('the date range cutting the history', () {
      DateTimeRange? cutRange(WidgetTester tester) => tester
          .widget<ServicesHistoryView>(find.byType(ServicesHistoryView))
          .dateRange;

      Future<void> applyWith(
        WidgetTester tester, {
        BikeEntity? bike,
        BookingRangePreset? preset,
      }) async {
        await openPanel(tester);
        if (bike != null) await tester.tap(plate(bike));
        if (preset != null) {
          await tester.tap(find.byKey(Key('bookings-preset-${preset.name}')));
        }
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();
      }

      Future<void> openWithBikes(WidgetTester tester) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
      }

      testWidgets('cuts nothing until a range is applied', (tester) async {
        await openWithBikes(tester);

        expect(cutRange(tester), isNull);
      });

      testWidgets('choosing only a bike, then Terapkan, still cuts nothing', (
        tester,
      ) async {
        await openWithBikes(tester);

        await applyWith(tester, bike: beat);

        expect(cutRange(tester), isNull);
        expect(rangeChip, findsNothing);
      });

      testWidgets('another shortcut cuts the list to that range', (
        tester,
      ) async {
        await openWithBikes(tester);

        await applyWith(tester, preset: BookingRangePreset.threeMonths);

        expect(
          cutRange(tester),
          BookingRangePreset.threeMonths.rangeOn(DateTime.now()),
        );
        expect(rangeChip, findsOneWidget);
      });

      testWidgets('applying the default range again takes the cut off', (
        tester,
      ) async {
        await openWithBikes(tester);
        await applyWith(tester, preset: BookingRangePreset.week);
        expect(cutRange(tester), isNotNull);

        await applyWith(tester, preset: BookingRangePreset.month);

        expect(cutRange(tester), isNull);
        expect(rangeChip, findsNothing);
      });

      testWidgets('Reset takes the cut off, and goes back to the first bike', (
        tester,
      ) async {
        await openWithBikes(tester);
        await applyWith(
          tester,
          bike: beat,
          preset: BookingRangePreset.thisMonth,
        );
        await openPanel(tester);

        await tester.tap(reset);
        await tester.pumpAndSettle();

        expect(cutRange(tester), isNull);
        expect(requestedPlates(), ['B 1234 XY', 'D 5678 CD', 'B 1234 XY']);
      });

      testWidgets('the range chip opens the panel on the range that is cut', (
        tester,
      ) async {
        await openWithBikes(tester);
        await applyWith(tester, preset: BookingRangePreset.week);

        await tester.tap(rangeChip);
        await tester.pumpAndSettle();

        expect(
          selected(
            tester,
            find.byKey(Key('bookings-preset-${BookingRangePreset.week.name}')),
          ),
          isTrue,
        );
      });

      testWidgets('My Bookings keeps its own range apart from it', (
        tester,
      ) async {
        await openWithBikes(tester);
        await applyWith(tester, preset: BookingRangePreset.week);

        await tester.tap(find.text('My Bookings'));
        await tester.pumpAndSettle();
        await openPanel(tester);

        // Still on the default there, not on the Riwayat one's week.
        expect(
          selected(
            tester,
            find.byKey(Key('bookings-preset-${BookingRangePreset.month.name}')),
          ),
          isTrue,
        );
      });
    });

    group('the page says a filter is on', () {
      bool dotShown(WidgetTester tester) =>
          tester.widget<Badge>(find.byType(Badge)).isLabelVisible;

      testWidgets('not while it shows the first bike on every date', (
        tester,
      ) async {
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);

        expect(dotShown(tester), isFalse);
        expect(find.byTooltip('Filter riwayat'), findsOneWidget);
      });

      testWidgets('on for another bike, though the plate is always set', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25, beat]);
        await openRiwayat(tester);
        await openPanel(tester);
        await tester.tap(plate(beat));
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();

        expect(dotShown(tester), isTrue);
        expect(find.byTooltip('Filter riwayat (aktif)'), findsOneWidget);
      });

      testWidgets('on for a date range, and each tab has its own', (
        tester,
      ) async {
        useTallScreen(tester);
        await pumpBookings(tester);
        await bikesLoaded(tester, [r25]);
        await openRiwayat(tester);
        await openPanel(tester);
        await tester.tap(
          find.byKey(Key('bookings-preset-${BookingRangePreset.week.name}')),
        );
        await tester.pump();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(dotShown(tester), isTrue);

        // My Bookings is still on its default range.
        await tester.tap(find.text('My Bookings'));
        await tester.pumpAndSettle();
        expect(dotShown(tester), isFalse);
        expect(find.byTooltip('Filter tanggal'), findsOneWidget);
      });
    });
  });
}
