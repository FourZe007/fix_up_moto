import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/create_booking_page.dart';
import 'package:fix_up_moto/features/bookings/presentation/widgets/booking_date_strip.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';

class MockBookingsBloc extends MockBloc<BookingsEvent, BookingsState>
    implements BookingsBloc {}

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
  Future<void> openCreatePage(WidgetTester tester) async {
    final bloc = MockBookingsBloc();
    whenListen(bloc, states.stream, initialState: const BookingsInitial());
    sl.registerFactory<BookingsBloc>(() => bloc);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('bookings-tab')),
        ),
        GoRoute(path: '/create', builder: (_, _) => const CreateBookingPage()),
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

  testWidgets('a failed booking does not signal anything', (tester) async {
    await openCreatePage(tester);

    states.add(const BookingsError('Server down'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, isNull);
    // Still on the create page, with the error shown.
    expect(find.text('bookings-tab'), findsNothing);
    expect(find.text('Server down'), findsOneWidget);
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
