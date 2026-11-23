import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/create_booking_page.dart';
import 'package:fix_up_moto/features/bookings/presentation/widgets/booking_date_strip.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';
import '../../../../support/haptic_recorder.dart';

class MockBookingsBloc extends MockBloc<BookingsEvent, BookingsState>
    implements BookingsBloc {}

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

const r25 = BikeEntity(
  unitId: 'YAMAHA R25',
  plateNo: 'B 1234 ABC',
  chasisNo: 'C1',
  engineNo: 'E1',
  color: 'Biru',
  year: '2022',
);

void main() {
  late DataRefreshCubit refreshCubit;
  late StreamController<BookingsState> states;

  setUp(() {
    refreshCubit = DataRefreshCubit();
    states = StreamController<BookingsState>();
  });

  tearDown(() async {
    await states.close();
    await sl.reset();
  });

  /// Opens the create page on top of a stand-in Bookings page, so a successful
  /// create can pop back to something.
  ///
  /// [bikesPerOpen] is what the bike picker finds each time it opens, in order
  /// (its last entry is reused after that): one list of registered bikes per
  /// opening, so a test can have the member start with none and then add one.
  ///
  /// [pointToBookings] opens it as the guidance's booking step, whose
  /// confirmation points to the Booking tab; the stand-in for that tab is a
  /// separate route, so going there can be told from going back.
  Future<void> openCreatePage(
    WidgetTester tester, {
    List<List<BikeEntity>> bikesPerOpen = const [[]],
    bool pointToBookings = false,
  }) async {
    final bloc = MockBookingsBloc();
    whenListen(bloc, states.stream, initialState: const BookingsInitial());
    sl.registerFactory<BookingsBloc>(() => bloc);

    // The picker builds its own BikesBloc each time it opens.
    var opens = 0;
    sl.registerFactory<BikesBloc>(() {
      final index = opens < bikesPerOpen.length
          ? opens
          : bikesPerOpen.length - 1;
      opens++;
      final bikes = MockBikesBloc();
      whenListen(
        bikes,
        const Stream<BikesState>.empty(),
        initialState: BikesLoaded(bikesPerOpen[index]),
      );
      return bikes;
    });

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('bookings-tab')),
        ),
        GoRoute(
          path: '/create',
          builder: (_, _) =>
              CreateBookingPage(pointToBookings: pointToBookings),
        ),
        GoRoute(
          path: RouteNames.bookings,
          builder: (_, _) => const Scaffold(body: Text('bookings-route')),
        ),
        // Stands in for Add Bike: "Simpan" is a bike saved (pops true), and the
        // system back button is backing out (pops nothing).
        GoRoute(
          path: RouteNames.addBike,
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('add-bike-page'),
                TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ),
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
    unawaited(router.push('/create'));
    await tester.pumpAndSettle();
  }

  testWidgets('a successful booking tells the Bookings tab to reload', (
    tester,
  ) async {
    await openCreatePage(tester);
    expect(refreshCubit.state.kind, isNull);

    states.add(const BookingActionSuccess('Booking confirmed!'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, DataKind.bookings);
    // ...and goes back to the tab that is now reloading.
    expect(find.text('bookings-tab'), findsOneWidget);
  });

  testWidgets('a successful booking gives a success tap on iOS', (
    tester,
  ) async {
    final haptics = HapticRecorder.start();

    await onDevice(TargetPlatform.iOS, () async {
      await openCreatePage(tester);

      states.add(const BookingActionSuccess('Booking confirmed!'));
      await tester.pumpAndSettle();

      expect(haptics.taps, [successTap]);
    });
  });

  testWidgets('a failed booking gives no tap', (tester) async {
    final haptics = HapticRecorder.start();

    await onDevice(TargetPlatform.iOS, () async {
      await openCreatePage(tester);

      states.add(const BookingsError('Server down'));
      await tester.pumpAndSettle();

      expect(haptics.taps, isEmpty);
    });
  });

  testWidgets('a failed booking does not signal anything', (tester) async {
    await openCreatePage(tester);

    states.add(const BookingsError('Server down'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, isNull);
    // Still on the create page, with the error shown.
    expect(find.text('bookings-tab'), findsNothing);
    expect(find.text('Server down'), findsOneWidget);
  });

  group('the confirmation', () {
    final plain = find.text('booking confirmed!');
    final pointer = find.text('Booking berhasil! Lihat di tab Booking.');
    final seeIt = find.text('Lihat');

    testWidgets('is the plain one, with Tutup, when opened as usual', (
      tester,
    ) async {
      await openCreatePage(tester);

      states.add(const BookingActionSuccess('Booking confirmed!'));
      await tester.pumpAndSettle();

      expect(plain, findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);
      expect(pointer, findsNothing);
      expect(seeIt, findsNothing);
    });

    testWidgets('points to the Booking tab when opened as the booking step', (
      tester,
    ) async {
      await openCreatePage(tester, pointToBookings: true);

      states.add(const BookingActionSuccess('Booking confirmed!'));
      await tester.pumpAndSettle();

      expect(pointer, findsOneWidget);
      expect(seeIt, findsOneWidget);
      // One confirmation, not two stacked.
      expect(plain, findsNothing);
      expect(find.text('Tutup'), findsNothing);
    });

    testWidgets('still reloads the Bookings tab and goes back, pointer or not', (
      tester,
    ) async {
      await openCreatePage(tester, pointToBookings: true);

      states.add(const BookingActionSuccess('Booking confirmed!'));
      await tester.pumpAndSettle();

      expect(refreshCubit.state.kind, DataKind.bookings);
      expect(find.text('bookings-tab'), findsOneWidget);
    });

    testWidgets('"Lihat" opens the Booking tab', (tester) async {
      await openCreatePage(tester, pointToBookings: true);
      states.add(const BookingActionSuccess('Booking confirmed!'));
      await tester.pumpAndSettle();

      await tester.tap(seeIt);
      await tester.pumpAndSettle();

      expect(find.text('bookings-route'), findsOneWidget);
    });

    testWidgets('the pointer lapses by itself if it is ignored', (
      tester,
    ) async {
      await openCreatePage(tester, pointToBookings: true);
      states.add(const BookingActionSuccess('Booking confirmed!'));
      await tester.pumpAndSettle();
      expect(pointer, findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();

      expect(pointer, findsNothing);
      expect(find.text('bookings-route'), findsNothing);
    });

    testWidgets('a failed booking points nowhere', (tester) async {
      await openCreatePage(tester, pointToBookings: true);

      states.add(const BookingsError('Server down'));
      await tester.pumpAndSettle();

      expect(pointer, findsNothing);
      expect(seeIt, findsNothing);
      expect(find.text('Server down'), findsOneWidget);
    });
  });

  group('date strip', () {
    // Midnight tomorrow, the strip's first card.
    DateTime tomorrow() =>
        DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));

    // The first day on or after [from] that falls on [weekday].
    DateTime nextWeekday(DateTime from, int weekday) {
      var day = from;
      while (day.weekday != weekday) {
        day = DateUtils.addDaysToDate(day, 1);
      }
      return day;
    }

    String summaryDate(DateTime day) => DateTimeFormatter.toDisplayDateId(day);

    testWidgets('opens with the first bookable day chosen, never a weekend', (
      tester,
    ) async {
      await openCreatePage(tester);

      final first = firstBookableDay(tomorrow());
      expect(first.weekday, lessThan(DateTime.saturday));
      expect(find.byKey(BookingDateStrip.keyFor(first)), findsOneWidget);
      expect(find.textContaining(summaryDate(first)), findsOneWidget);
    });

    testWidgets(
      'shows Saturday and Sunday greyed out and ignores taps on them',
      (tester) async {
        await openCreatePage(tester);
        final first = firstBookableDay(tomorrow());

        for (final weekday in [DateTime.saturday, DateTime.sunday]) {
          final weekend = nextWeekday(tomorrow(), weekday);
          final card = find.byKey(BookingDateStrip.keyFor(weekend));
          // Visible, not hidden...
          expect(card, findsOneWidget);
          // ...but not selectable.
          await tester.tap(card);
          await tester.pump();
          expect(find.textContaining(summaryDate(weekend)), findsNothing);
          expect(find.textContaining(summaryDate(first)), findsOneWidget);
        }
      },
    );

    testWidgets('tapping a bookable day chooses it', (tester) async {
      await openCreatePage(tester);
      final other = firstBookableDay(
        DateUtils.addDaysToDate(firstBookableDay(tomorrow()), 1),
      );

      await tester.tap(find.byKey(BookingDateStrip.keyFor(other)));
      await tester.pump();

      expect(find.textContaining(summaryDate(other)), findsOneWidget);
    });

    testWidgets('states the booking rules once, under the strip', (
      tester,
    ) async {
      await openCreatePage(tester);

      expect(find.text('Buka Senin - Jumat'), findsOneWidget);
      expect(
        find.text(
          '*Booking tidak tersedia pada hari Sabtu dan Minggu. Booking minimal satu hari sebelumnya.',
        ),
        findsOneWidget,
      );
    });
  });

  group('the bike picker', () {
    final addBike = find.byKey(const Key('booking-add-bike'));
    // The bike row on the page (the summary bar below repeats its words).
    final bikeRow = find.text('Pilih motor Anda').first;

    /// Opens the picker, taps Tambah Motor, and "saves" a bike in the stand-in
    /// Add Bike page: the member is back on the booking, picker open again.
    Future<void> addABike(WidgetTester tester) async {
      await tester.tap(bikeRow);
      await tester.pumpAndSettle();
      await tester.tap(addBike);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'lists the bikes of a member who has some, with no add button',
      (tester) async {
        await openCreatePage(
          tester,
          bikesPerOpen: const [
            [r25],
          ],
        );

        await tester.tap(bikeRow);
        await tester.pumpAndSettle();

        expect(find.text('YAMAHA R25'), findsOneWidget);
        expect(find.text('B 1234 ABC'), findsOneWidget);
        expect(addBike, findsNothing);
        expect(find.text('Belum ada motor terdaftar'), findsNothing);
      },
    );

    testWidgets('a member with no bike is told why, and can add one', (
      tester,
    ) async {
      await openCreatePage(tester);

      await tester.tap(bikeRow);
      await tester.pumpAndSettle();

      // Not a dead end: the line is still there, with the reason and a way on.
      expect(find.text('Belum ada motor terdaftar'), findsOneWidget);
      expect(
        find.text('Daftarkan motor Anda dulu untuk membuat booking.'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: addBike, matching: find.text('Tambah Motor')),
        findsOneWidget,
      );
    });

    testWidgets('Tambah Motor closes the picker and opens Add Bike', (
      tester,
    ) async {
      await openCreatePage(tester);
      await tester.tap(bikeRow);
      await tester.pumpAndSettle();

      await tester.tap(addBike);
      await tester.pumpAndSettle();

      expect(find.text('add-bike-page'), findsOneWidget);
      expect(find.text('Belum ada motor terdaftar'), findsNothing);
    });

    testWidgets('once the bike is saved the picker opens again with it', (
      tester,
    ) async {
      await openCreatePage(
        tester,
        bikesPerOpen: const [
          [],
          [r25],
        ],
      );

      await addABike(tester);

      // Back on the booking, with the picker open on the new bike.
      expect(find.text('add-bike-page'), findsNothing);
      expect(find.text('YAMAHA R25'), findsOneWidget);
      expect(addBike, findsNothing);
    });

    testWidgets('picking the new bike puts it on the booking', (tester) async {
      await openCreatePage(
        tester,
        bikesPerOpen: const [
          [],
          [r25],
        ],
      );
      await addABike(tester);

      await tester.tap(find.text('YAMAHA R25'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih motor Anda'), findsNothing);
      expect(find.textContaining('B 1234 ABC'), findsWidgets);
    });

    testWidgets('backing out of Add Bike leaves the booking as it was', (
      tester,
    ) async {
      await openCreatePage(tester);
      await tester.tap(bikeRow);
      await tester.pumpAndSettle();
      await tester.tap(addBike);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // No picker re-opened, no bike chosen, still on the booking page.
      expect(find.text('add-bike-page'), findsNothing);
      expect(find.text('Belum ada motor terdaftar'), findsNothing);
      expect(find.text('Pilih motor Anda'), findsNWidgets(2));
      expect(find.text('Konfirmasi'), findsOneWidget);
    });

    testWidgets('what was already chosen on the page survives the detour', (
      tester,
    ) async {
      await openCreatePage(
        tester,
        bikesPerOpen: const [
          [],
          [r25],
        ],
      );
      await tester.tap(find.text('09:00 - 10:00'));
      await tester.pump();
      await addABike(tester);
      await tester.tap(find.text('YAMAHA R25'));
      await tester.pumpAndSettle();

      // The time picked before the detour is still picked, and with the bike
      // now chosen Konfirmasi is on.
      expect(find.textContaining('09:00 - 10:00'), findsWidgets);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });
  });

  testWidgets('Confirm stays off until a time and a bike are chosen', (
    tester,
  ) async {
    await openCreatePage(tester);
    ElevatedButton confirm() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    // The summary says what is missing instead of leaving the button mute.
    expect(find.textContaining('Pilih jam'), findsOneWidget);
    // Once in the bike row, once in the summary bar.
    expect(find.text('Pilih motor Anda'), findsNWidgets(2));
    expect(confirm().onPressed, isNull);

    await tester.tap(find.text('09:00 - 10:00'));
    await tester.pump();

    expect(find.textContaining('Pilih jam'), findsNothing);
    expect(find.textContaining('09:00 - 10:00'), findsWidgets);
    // No bike yet, so still off.
    expect(confirm().onPressed, isNull);
  });

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    // A test that overflows fails on its own: Flutter reports it as an error.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openCreatePage(tester);

    expect(find.text('Pilih Tanggal'), findsOneWidget);
    expect(find.text('Pilih Jam'), findsOneWidget);
    expect(find.text('Konfirmasi'), findsOneWidget);
  });

  group('full calendar', () {
    Future<void> openCalendar(WidgetTester tester) async {
      await openCreatePage(tester);
      await tester.tap(find.text('Lihat kalender lengkap'));
      await tester.pumpAndSettle();
    }

    testWidgets('greys out weekends and opens on a weekday', (tester) async {
      await openCalendar(tester);

      final calendar = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      // 31 Oct 2026 is a Saturday, 1 Nov the Sunday and 2 Nov the Monday after.
      expect(calendar.selectableDayPredicate!(DateTime(2026, 10, 31)), isFalse);
      expect(calendar.selectableDayPredicate!(DateTime(2026, 11, 1)), isFalse);
      expect(calendar.selectableDayPredicate!(DateTime(2026, 11, 2)), isTrue);
      // showDatePicker would throw if it opened on a weekend day.
      expect(calendar.initialDate!.weekday, lessThan(DateTime.saturday));
    });

    testWidgets('starts tomorrow, so today cannot be booked', (tester) async {
      await openCalendar(tester);

      final calendar = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(
        DateUtils.dateOnly(
          calendar.firstDate,
        ).isAfter(DateUtils.dateOnly(DateTime.now())),
        isTrue,
      );
    });

    testWidgets('types a date on a keyboard that has a "/" key', (
      tester,
    ) async {
      await openCalendar(tester);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // The default datetime pad is digits-only on many phones, so a date could
      // not be typed with its separators.
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(field.keyboardType, TextInputType.text);
    });

    testWidgets('explains the rules when a blocked date is typed in', (
      tester,
    ) async {
      await openCalendar(tester);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // The first Saturday that is inside the pickable range.
      var saturday = DateTime.now().add(const Duration(days: 2));
      while (saturday.weekday != DateTime.saturday) {
        saturday = saturday.add(const Duration(days: 1));
      }
      final typed =
          '${saturday.month.toString().padLeft(2, '0')}/'
          '${saturday.day.toString().padLeft(2, '0')}/${saturday.year}';
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        typed,
      );
      await tester.tap(find.text('Pilih'));
      await tester.pumpAndSettle();

      expect(
        find.text('Akhir pekan dan hari ini tidak tersedia'),
        findsOneWidget,
      );
    });
  });
}
