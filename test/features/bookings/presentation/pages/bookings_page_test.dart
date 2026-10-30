import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/models/booking_date_range.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/bookings_page.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';

class MockBookingsBloc extends MockBloc<BookingsEvent, BookingsState>
    implements BookingsBloc {}

class MockServicesBloc extends MockBloc<ServicesEvent, ServicesState>
    implements ServicesBloc {}

late DataRefreshCubit refreshCubit;

Future<MockBookingsBloc> pumpBookings(WidgetTester tester) async {
  final bookings = MockBookingsBloc();
  whenListen(
    bookings,
    const Stream<BookingsState>.empty(),
    initialState: const BookingsLoaded([]),
  );
  sl.registerFactory<BookingsBloc>(() => bookings);

  final services = MockServicesBloc();
  whenListen(
    services,
    const Stream<ServicesState>.empty(),
    initialState: const ServicesInitial(),
  );
  sl.registerFactory<ServicesBloc>(() => services);

  await tester.pumpWidget(
    MaterialApp(
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
  });
  setUp(() => refreshCubit = DataRefreshCubit());
  tearDown(() => sl.reset());

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
}
