import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/helpers/geo.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/services/location_service.dart';
import 'package:fix_up_moto/core/tour/field_guide.dart';
import 'package:fix_up_moto/core/tour/field_guide_player.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_event.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_state.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/create_booking_page.dart';
import 'package:fix_up_moto/features/bookings/presentation/widgets/booking_date_strip.dart';
import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_bloc.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_event.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_state.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';
import '../../../../support/haptic_recorder.dart';

class MockBookingsBloc extends MockBloc<BookingsEvent, BookingsState>
    implements BookingsBloc {}

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

class MockWorkshopsBloc extends MockBloc<WorkshopsEvent, WorkshopsState>
    implements WorkshopsBloc {}

WorkshopEntity workshopOf(
  String shop,
  String name, {
  bool active = true,
  double lat = -7.3,
  double lng = 112.7,
}) => WorkshopEntity(
  branch: '31',
  shop: shop,
  bsName: name,
  bsAddress: 'JL. CONTOH NO. $shop',
  operationalHours: 'Senin - Jumat 08.00 - 16.00',
  phoneNo: '0312345678',
  active: active,
  lat: lat,
  lng: lng,
);

final kutisari = workshopOf(
  '01',
  'FIXUP MOTO - KUTISARI',
  lat: -7.3166,
  lng: 112.7527,
);
final darmo = workshopOf(
  '02',
  'FIXUP MOTO - DARMO',
  lat: -7.2950,
  lng: 112.6850,
);
final closedShop = workshopOf('03', 'FIXUP MOTO - TUTUP', active: false);
final gedangan = workshopOf(
  '04',
  'FIXUP MOTO - GEDANGAN',
  lat: -7.3773,
  lng: 112.7292,
);

// Where a member might be.
const nearDarmo = GeoPoint(-7.2900, 112.6800);
const nearGedangan = GeoPoint(-7.3800, 112.7300);

/// A [LocationService] a test can answer by hand, counting how often it is asked.
class FakeLocation implements LocationService {
  final Future<GeoPoint?> Function() answer;
  var asked = 0;

  FakeLocation(this.answer);

  /// Answers straight away with [here] (null: the position is unknown).
  FakeLocation.at(GeoPoint? here) : answer = (() async => here);

  @override
  Future<GeoPoint?> currentPosition() {
    asked++;
    return answer();
  }
}

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

  /// The app-wide workshop choice, which a test can preselect or read back.
  late SelectedWorkshopCubit selectedWorkshop;

  /// How many times the page asked for a workshops bloc (so, for the list).
  var workshopsBuilt = 0;

  /// The bookings bloc the page was given, to see what it was asked to send.
  late MockBookingsBloc bookingsBloc;

  setUpAll(() {
    registerFallbackValue(
      BookingCreateRequested(
        scheduledAt: DateTime(2026),
        branch: '',
        shop: '',
        plateNo: '',
        unitId: '',
      ),
    );
  });

  setUp(() {
    refreshCubit = DataRefreshCubit();
    states = StreamController<BookingsState>();
    selectedWorkshop = SelectedWorkshopCubit();
    workshopsBuilt = 0;
  });

  tearDown(() async {
    await states.close();
    await selectedWorkshop.close();
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
  ///
  /// [workshopStream] is what the workshop list answers when the page asks for it
  /// (it only asks when no workshop is chosen): by default it loads
  /// [kutisari] and [darmo]. [chosen] is a workshop already picked on arrival.
  Future<void> openCreatePage(
    WidgetTester tester, {
    List<List<BikeEntity>> bikesPerOpen = const [[]],
    bool pointToBookings = false,
    SharedPreferences? guidePrefs,
    bool autoGuide = false,
    Stream<WorkshopsState>? workshopStream,
    WorkshopEntity? chosen,
    LocationService? location,
  }) async {
    // With a default workshop the form is taller (its row shows a name and an
    // address), so on the test's default 800 x 600 surface the time chips fall
    // below the fold. A test that chose its own size keeps it.
    if (tester.view.physicalSize == const Size(2400, 1800)) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    if (chosen != null) selectedWorkshop.select(chosen);

    // Nobody knows where the member is unless a test says so.
    sl.registerSingleton<LocationService>(
      location ?? const NoLocationService(),
    );

    final workshops = MockWorkshopsBloc();
    whenListen(
      workshops,
      workshopStream ??
          Stream<WorkshopsState>.fromIterable([
            const WorkshopsLoading(),
            WorkshopsLoaded([kutisari, darmo]),
          ]),
      initialState: const WorkshopsInitial(),
    );
    sl.registerFactory<WorkshopsBloc>(() {
      workshopsBuilt++;
      return workshops;
    });

    final bloc = MockBookingsBloc();
    bookingsBloc = bloc;
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
          builder: (_, _) => CreateBookingPage(
            pointToBookings: pointToBookings,
            guidePrefs: guidePrefs,
            autoGuide: autoGuide,
          ),
        ),
        GoRoute(
          path: RouteNames.bookings,
          builder: (_, _) => const Scaffold(body: Text('bookings-route')),
        ),
        // Stands in for the workshop list, reached from the page's workshop row:
        // "Pilih bengkel" is picking [darmo].
        GoRoute(
          path: RouteNames.workshops,
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('workshop-list'),
                TextButton(
                  onPressed: () => context.pop(darmo),
                  child: const Text('Pilih bengkel'),
                ),
              ],
            ),
          ),
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
          BlocProvider.value(value: selectedWorkshop),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    unawaited(router.push('/create'));
    await tester.pumpAndSettle();
  }

  group('the field guide', () {
    final card = find.byType(FieldGuideCard);
    final next = find.byKey(const Key('field-guide-next'));
    final back = find.byKey(const Key('field-guide-back'));
    final tag = find.byKey(const Key('field-guide-tag'));
    final warning = find.byKey(const Key('field-guide-warning'));
    final skip = find.text('Lewati');
    final helpButton = find.byKey(const Key('create-booking-guide-button'));
    final seenKey = FieldGuideSeen.keyFor(FieldGuideId.createBooking);

    /// The six steps in the page's order: what it is called, and its tag
    /// (true "Wajib diisi", false "Opsional", null none).
    const steps = <(String, bool?)>[
      ('Bengkel', null),
      ('Motor', true),
      ('Tanggal', true),
      ('Jam', true),
      ('Catatan', false),
      ('Konfirmasi', null),
    ];

    bool named(Widget w, String name) => w.runtimeType.toString() == name;

    /// What each step lights up on the page.
    Finder lit(String title) => switch (title) {
      'Bengkel' => find.byWidgetPredicate((w) => named(w, '_SetupRow')).at(0),
      'Motor' => find.byWidgetPredicate((w) => named(w, '_SetupRow')).at(1),
      'Tanggal' => find.byType(BookingDateStrip),
      // The row of the three time chips (three chips and two gaps).
      'Jam' => find.byWidgetPredicate(
        (w) => w is Row && w.key is GlobalKey && w.children.length == 5,
      ),
      'Catatan' => find.byType(TextFormField),
      _ => find.byWidgetPredicate((w) => named(w, '_SummaryBar')),
    };

    Future<SharedPreferences> prefsWith(Map<String, Object> values) {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    /// Lets the guide come up, or move to its next step. Fixed steps rather than
    /// `pumpAndSettle`, which takes the overlay's first frame-less gap for the
    /// end of it; a phone just keeps drawing frames.
    Future<void> settleGuide(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> waitForAutoGuide(WidgetTester tester) async {
      await tester.pump(FieldGuidePlayer.autoDelay);
      await settleGuide(tester);
    }

    Future<void> pressNext(WidgetTester tester) async {
      await tester.tap(next);
      await settleGuide(tester);
    }

    /// A member whose first booking is still to make, on a phone that has not
    /// seen the guide.
    Future<SharedPreferences> openForFirstBooking(WidgetTester tester) async {
      final prefs = await prefsWith({});
      await openCreatePage(tester, guidePrefs: prefs, autoGuide: true);
      return prefs;
    }

    group('when it plays', () {
      testWidgets('not at all without guide settings: the page is as it was', (
        tester,
      ) async {
        await openCreatePage(tester);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(helpButton, findsNothing);
        expect(card, findsNothing);
      });

      testWidgets('by itself the first time, for a first booking', (
        tester,
      ) async {
        await openForFirstBooking(tester);

        await waitForAutoGuide(tester);

        expect(card, findsOneWidget);
        expect(find.text('1 dari 6'), findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.text('Bengkel')),
          findsOneWidget,
        );
      });

      testWidgets('not before the page has settled in', (tester) async {
        await openForFirstBooking(tester);

        await tester.pump(
          FieldGuidePlayer.autoDelay - const Duration(milliseconds: 200),
        );

        expect(card, findsNothing);
      });

      testWidgets('not for a member who has booked: only the help button', (
        tester,
      ) async {
        await openCreatePage(
          tester,
          guidePrefs: await prefsWith({}),
          autoGuide: false,
        );

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(card, findsNothing);
        expect(helpButton, findsOneWidget);
      });

      testWidgets('not again once the phone has been through it', (
        tester,
      ) async {
        final prefs = await prefsWith({seenKey: true});
        await openCreatePage(tester, guidePrefs: prefs, autoGuide: true);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(card, findsNothing);
      });

      testWidgets('again from the help button, even when it was seen', (
        tester,
      ) async {
        final prefs = await prefsWith({seenKey: true});
        await openCreatePage(tester, guidePrefs: prefs, autoGuide: true);

        await tester.tap(helpButton);
        await settleGuide(tester);

        expect(card, findsOneWidget);
        expect(find.text('1 dari 6'), findsOneWidget);
      });

      testWidgets('the help button steps aside while it plays, and returns', (
        tester,
      ) async {
        await openForFirstBooking(tester);
        bool buttonShown() => tester
            .widget<Visibility>(
              find
                  .ancestor(of: helpButton, matching: find.byType(Visibility))
                  .first,
            )
            .visible;
        expect(buttonShown(), isTrue);

        await waitForAutoGuide(tester);
        expect(buttonShown(), isFalse);

        await tester.tap(skip);
        await settleGuide(tester);
        expect(buttonShown(), isTrue);
      });
    });

    group('walking through it', () {
      testWidgets('lights each step in the page\'s order, with its tag', (
        tester,
      ) async {
        await openForFirstBooking(tester);
        await waitForAutoGuide(tester);

        for (var i = 0; i < steps.length; i++) {
          final (title, required) = steps[i];
          expect(find.text('${i + 1} dari 6'), findsOneWidget, reason: title);
          expect(
            find.descendant(of: card, matching: find.text(title)),
            findsOneWidget,
            reason: title,
          );
          if (required == null) {
            expect(tag, findsNothing, reason: '$title has no tag');
          } else {
            expect(
              find.descendant(
                of: tag,
                matching: find.text(required ? 'Wajib diisi' : 'Opsional'),
              ),
              findsOneWidget,
              reason: title,
            );
          }
          if (i < steps.length - 1) await pressNext(tester);
        }
      });

      testWidgets('warns about the bike on the bike step, and only there', (
        tester,
      ) async {
        await openForFirstBooking(tester);
        await waitForAutoGuide(tester);

        for (var i = 0; i < steps.length; i++) {
          final title = steps[i].$1;
          if (title == 'Motor') {
            expect(warning, findsOneWidget);
            final text = tester
                .widget<Text>(
                  find.descendant(of: warning, matching: find.byType(Text)),
                )
                .data!;
            expect(text, contains('Jangan lupa'));
            expect(text, contains('data motor'));
            expect(text, contains('sebelum bisa membuat booking'));
          } else {
            expect(warning, findsNothing, reason: '$title has no warning');
          }
          if (i < steps.length - 1) await pressNext(tester);
        }
      });

      testWidgets('the warning comes after the explanation, in the same card', (
        tester,
      ) async {
        await openForFirstBooking(tester);
        await waitForAutoGuide(tester);
        await pressNext(tester);
        expect(find.text('2 dari 6'), findsOneWidget);

        final explanation = tester.getRect(
          find.textContaining('Pilih motor yang akan diservis'),
        );
        final caution = tester.getRect(warning);

        expect(caution.top, greaterThanOrEqualTo(explanation.bottom));
        expect(
          find.descendant(of: card, matching: warning),
          findsOneWidget,
          reason: 'inside the card, not a separate step',
        );
      });

      testWidgets('Kembali goes back a step, and is missing on the first', (
        tester,
      ) async {
        await openForFirstBooking(tester);
        await waitForAutoGuide(tester);
        expect(back, findsNothing);

        await pressNext(tester);
        await pressNext(tester);
        expect(find.text('3 dari 6'), findsOneWidget);

        await tester.tap(back);
        await settleGuide(tester);

        expect(find.text('2 dari 6'), findsOneWidget);
      });

      testWidgets('the last step says Selesai, and Lewati is gone', (
        tester,
      ) async {
        await openForFirstBooking(tester);
        await waitForAutoGuide(tester);
        expect(skip, findsOneWidget);

        for (var i = 0; i < steps.length - 1; i++) {
          await pressNext(tester);
        }

        expect(find.text('6 dari 6'), findsOneWidget);
        expect(
          find.descendant(of: next, matching: find.text('Selesai')),
          findsOneWidget,
        );
        expect(skip, findsNothing);
      });

      testWidgets('a tap on the lit bike row does not open the bike picker', (
        tester,
      ) async {
        await openForFirstBooking(tester);
        await waitForAutoGuide(tester);
        await pressNext(tester);
        expect(find.text('2 dari 6'), findsOneWidget);

        await tester.tapAt(tester.getCenter(lit('Motor')));
        await settleGuide(tester);

        expect(find.text('Belum ada motor terdaftar'), findsNothing);
        expect(find.text('2 dari 6'), findsOneWidget);
      });
    });

    group('remembering it', () {
      testWidgets('opening it is not enough to count as seen', (tester) async {
        final prefs = await openForFirstBooking(tester);

        await waitForAutoGuide(tester);

        expect(prefs.getBool(seenKey), isNull);
      });

      testWidgets('Selesai marks it seen and closes it', (tester) async {
        final prefs = await openForFirstBooking(tester);
        await waitForAutoGuide(tester);

        for (var i = 0; i < steps.length - 1; i++) {
          await pressNext(tester);
        }
        await pressNext(tester);

        expect(card, findsNothing);
        expect(prefs.getBool(seenKey), isTrue);
      });

      testWidgets('Lewati marks it seen and closes it', (tester) async {
        final prefs = await openForFirstBooking(tester);
        await waitForAutoGuide(tester);

        await tester.tap(skip);
        await tester.pumpAndSettle();

        expect(card, findsNothing);
        expect(prefs.getBool(seenKey), isTrue);
      });

      testWidgets('leaving the page halfway removes it and keeps it unseen', (
        tester,
      ) async {
        final prefs = await openForFirstBooking(tester);
        await waitForAutoGuide(tester);
        await pressNext(tester);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('bookings-tab'), findsOneWidget);
        expect(card, findsNothing);
        expect(find.text('Lewati'), findsNothing);
        expect(prefs.getBool(seenKey), isNull);
      });
    });

    group('leaves the page as it was', () {
      testWidgets('no extra scroll room once it ends', (tester) async {
        await openForFirstBooking(tester);
        double maxScroll() => tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(SingleChildScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .maxScrollExtent;
        final before = maxScroll();

        await waitForAutoGuide(tester);
        expect(maxScroll(), greaterThan(before));

        await tester.tap(skip);
        await settleGuide(tester);

        expect(maxScroll(), before);
      });

      testWidgets('back at the top when it ends', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await openForFirstBooking(tester);
        double scrolled() => tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(SingleChildScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .pixels;
        await waitForAutoGuide(tester);
        for (var i = 0; i < steps.length - 1; i++) {
          await pressNext(tester);
        }
        expect(scrolled(), greaterThan(0), reason: 'the notes are below');

        await pressNext(tester); // Selesai
        await settleGuide(tester);

        expect(scrolled(), 0);
      });
    });

    group('it never loses what it lights or its card off the screen', () {
      for (final size in const [
        Size(412, 915),
        Size(360, 640),
        Size(800, 600),
      ]) {
        testWidgets('${size.width.toInt()} x ${size.height.toInt()}', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await openForFirstBooking(tester);
          await waitForAutoGuide(tester);
          // Edges, not Rect.contains: the bottom bar sits exactly on the
          // screen's edge, which contains() counts as outside.
          bool onScreen(Rect r) =>
              r.left >= 0 &&
              r.top >= 0 &&
              r.right <= size.width &&
              r.bottom <= size.height;

          for (var i = 0; i < steps.length; i++) {
            final title = steps[i].$1;
            final thing = tester.getRect(lit(title));
            final cardRect = tester.getRect(card);

            expect(
              onScreen(thing),
              isTrue,
              reason: '$title is on screen: $thing',
            );
            expect(
              onScreen(cardRect),
              isTrue,
              reason: 'the card for $title is on screen: $cardRect',
            );
            expect(
              cardRect.overlaps(thing),
              isFalse,
              reason:
                  'the card for $title does not cover it: $cardRect vs $thing',
            );

            if (i < steps.length - 1) await pressNext(tester);
          }
        });
      }
    });
  });

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

  group('the workshop is chosen on the page', () {
    ElevatedButton confirm(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    Future<void> chooseTimeAndBike(WidgetTester tester) async {
      await tester.tap(find.text('09:00 - 10:00'));
      await tester.pump();
      await tester.tap(find.text('Pilih motor Anda').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('YAMAHA R25'));
      await tester.pumpAndSettle();
    }

    testWidgets('selects the first workshop by itself when none is chosen', (
      tester,
    ) async {
      await openCreatePage(tester);
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, kutisari);
      expect(find.text(kutisari.bsName), findsOneWidget);
      expect(find.text('Pilih bengkel favorit kamu'), findsNothing);
    });

    testWidgets('skips a workshop that cannot be picked', (tester) async {
      await openCreatePage(
        tester,
        workshopStream: Stream<WorkshopsState>.fromIterable([
          WorkshopsLoaded([closedShop, darmo, kutisari]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, darmo);
    });

    testWidgets('says it is loading while it looks', (tester) async {
      final answer = StreamController<WorkshopsState>();
      addTearDown(answer.close);
      await openCreatePage(tester, workshopStream: answer.stream);
      await tester.pump();

      expect(find.text('Memuat bengkel...'), findsOneWidget);
      expect(find.text('Pilih bengkel favorit kamu'), findsNothing);
      expect(selectedWorkshop.state, isNull);

      answer.add(WorkshopsLoaded([kutisari]));
      await tester.pumpAndSettle();

      expect(find.text('Memuat bengkel...'), findsNothing);
      expect(find.text(kutisari.bsName), findsOneWidget);
    });

    testWidgets('keeps a workshop that was already chosen, and asks for no '
        'list', (tester) async {
      await openCreatePage(tester, chosen: darmo);
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, darmo);
      expect(find.text(darmo.bsName), findsOneWidget);
      // Not even looked up: no request for a member who already has a choice.
      expect(workshopsBuilt, 0);
    });

    testWidgets('never overrides a workshop picked while the list loads', (
      tester,
    ) async {
      final answer = StreamController<WorkshopsState>();
      addTearDown(answer.close);
      await openCreatePage(tester, workshopStream: answer.stream);
      await tester.pump();

      // The member picks one from the row before the list has come back...
      await tester.tap(find.text('Memuat bengkel...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih bengkel'));
      await tester.pumpAndSettle();
      expect(selectedWorkshop.state, darmo);

      // ...and the list arriving later does not change it.
      answer.add(WorkshopsLoaded([kutisari, darmo]));
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, darmo);
      expect(find.text(darmo.bsName), findsOneWidget);
    });

    testWidgets('leaves the row asking for a pick when no workshop is open', (
      tester,
    ) async {
      await openCreatePage(
        tester,
        workshopStream: Stream<WorkshopsState>.fromIterable([
          WorkshopsLoaded([closedShop]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, isNull);
      expect(find.text('Pilih bengkel favorit kamu'), findsOneWidget);
    });

    group('when the list cannot be loaded', () {
      Future<void> openFailed(WidgetTester tester) => openCreatePage(
        tester,
        bikesPerOpen: [
          [r25],
        ],
        workshopStream: Stream<WorkshopsState>.fromIterable([
          const WorkshopsError('Server down'),
        ]),
      );

      testWidgets('the row asks for a pick, the usual way', (tester) async {
        await openFailed(tester);
        await tester.pumpAndSettle();

        expect(selectedWorkshop.state, isNull);
        expect(find.text('Pilih bengkel favorit kamu'), findsOneWidget);

        await tester.tap(find.text('Pilih bengkel favorit kamu'));
        await tester.pumpAndSettle();
        expect(find.text('workshop-list'), findsOneWidget);
      });

      testWidgets('Konfirmasi stays off, however much else is chosen', (
        tester,
      ) async {
        await openFailed(tester);
        await tester.pumpAndSettle();

        await chooseTimeAndBike(tester);

        expect(confirm(tester).onPressed, isNull);
      });

      testWidgets('and turns on once a workshop is picked by hand', (
        tester,
      ) async {
        await openFailed(tester);
        await tester.pumpAndSettle();
        await chooseTimeAndBike(tester);
        expect(confirm(tester).onPressed, isNull);

        await tester.tap(find.text('Pilih bengkel favorit kamu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pilih bengkel'));
        await tester.pumpAndSettle();

        expect(selectedWorkshop.state, darmo);
        expect(confirm(tester).onPressed, isNotNull);
      });
    });

    testWidgets('Konfirmasi turns on with the default workshop, a time and a '
        'bike', (tester) async {
      await openCreatePage(
        tester,
        bikesPerOpen: [
          [r25],
        ],
      );
      await tester.pumpAndSettle();

      await chooseTimeAndBike(tester);

      expect(confirm(tester).onPressed, isNotNull);
    });

    testWidgets('books at the default workshop', (tester) async {
      await openCreatePage(
        tester,
        bikesPerOpen: [
          [r25],
        ],
      );
      await tester.pumpAndSettle();
      await chooseTimeAndBike(tester);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      final sent =
          verify(() => bookingsBloc.add(captureAny<BookingsEvent>()))
                  .captured
                  .single
              as BookingCreateRequested;
      expect(sent.branch, kutisari.branch);
      expect(sent.shop, kutisari.shop);
      expect(sent.plateNo, r25.plateNo);
    });
  });

  group('the nearest workshop is the default', () {
    final all = Stream<WorkshopsState>.fromIterable([
      WorkshopsLoaded([kutisari, darmo, gedangan]),
    ]);
    Stream<WorkshopsState> loaded(List<WorkshopEntity> workshops) =>
        Stream<WorkshopsState>.fromIterable([WorkshopsLoaded(workshops)]);

    testWidgets('picks the workshop closest to the member', (tester) async {
      await openCreatePage(
        tester,
        workshopStream: all,
        location: FakeLocation.at(nearDarmo),
      );
      await tester.pumpAndSettle();

      // Not the first in the list (Kutisari): the nearest.
      expect(selectedWorkshop.state, darmo);
      expect(find.text(darmo.bsName), findsOneWidget);
    });

    testWidgets('follows the member to another part of town', (tester) async {
      await openCreatePage(
        tester,
        workshopStream: all,
        location: FakeLocation.at(nearGedangan),
      );
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, gedangan);
    });

    testWidgets('falls back to the first open workshop when the position is '
        'unknown', (tester) async {
      await openCreatePage(
        tester,
        workshopStream: all,
        location: FakeLocation.at(null),
      );
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, kutisari);
    });

    testWidgets('never picks a workshop that is closed, however near', (
      tester,
    ) async {
      final closedNearDarmo = workshopOf(
        '05',
        'FIXUP MOTO - TUTUP DEKAT',
        active: false,
        lat: -7.2900,
        lng: 112.6800,
      );
      await openCreatePage(
        tester,
        workshopStream: loaded([closedNearDarmo, kutisari, darmo]),
        location: FakeLocation.at(nearDarmo),
      );
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, darmo);
    });

    testWidgets('does not treat a workshop with no coordinates as near', (
      tester,
    ) async {
      final noCoordinates = workshopOf(
        '06',
        'FIXUP MOTO - KOSONG',
        lat: 0,
        lng: 0,
      );
      await openCreatePage(
        tester,
        workshopStream: loaded([noCoordinates, kutisari]),
        location: FakeLocation.at(const GeoPoint(-1, 1)),
      );
      await tester.pumpAndSettle();

      expect(selectedWorkshop.state, kutisari);
    });

    testWidgets('asks for the position once, and only to choose', (
      tester,
    ) async {
      final location = FakeLocation.at(nearDarmo);
      await openCreatePage(tester, workshopStream: all, location: location);
      await tester.pumpAndSettle();

      expect(location.asked, 1);
    });

    testWidgets('does not ask at all when a workshop is already chosen', (
      tester,
    ) async {
      final location = FakeLocation.at(nearDarmo);
      await openCreatePage(
        tester,
        chosen: kutisari,
        workshopStream: all,
        location: location,
      );
      await tester.pumpAndSettle();

      expect(location.asked, 0);
      expect(selectedWorkshop.state, kutisari);
    });

    testWidgets('does not ask when the list could not be loaded', (
      tester,
    ) async {
      final location = FakeLocation.at(nearDarmo);
      await openCreatePage(
        tester,
        workshopStream: Stream<WorkshopsState>.fromIterable([
          const WorkshopsError('Server down'),
        ]),
        location: location,
      );
      await tester.pumpAndSettle();

      expect(location.asked, 0);
      expect(find.text('Pilih bengkel favorit kamu'), findsOneWidget);
    });

    group('while the position is being found', () {
      testWidgets('says it is loading, and nothing is chosen yet', (
        tester,
      ) async {
        final position = Completer<GeoPoint?>();
        await openCreatePage(
          tester,
          workshopStream: all,
          location: FakeLocation(() => position.future),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Memuat bengkel...'), findsOneWidget);
        expect(selectedWorkshop.state, isNull);

        position.complete(nearDarmo);
        await tester.pumpAndSettle();

        expect(find.text('Memuat bengkel...'), findsNothing);
        expect(selectedWorkshop.state, darmo);
      });

      testWidgets('a workshop picked by hand wins over the answer', (
        tester,
      ) async {
        final position = Completer<GeoPoint?>();
        await openCreatePage(
          tester,
          workshopStream: all,
          location: FakeLocation(() => position.future),
        );
        await tester.pump();
        await tester.pump();

        // The member picks Darmo from the row (the stand-in list answers with it)...
        await tester.tap(find.text('Memuat bengkel...'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pilih bengkel'));
        await tester.pumpAndSettle();
        expect(selectedWorkshop.state, darmo);

        // ...and a position that would have chosen Gedangan arrives too late.
        position.complete(nearGedangan);
        await tester.pumpAndSettle();

        expect(selectedWorkshop.state, darmo);
      });

      testWidgets('carries on with the first open workshop if it never '
          'answers', (tester) async {
        final never = Completer<GeoPoint?>();
        await openCreatePage(
          tester,
          workshopStream: all,
          location: FakeLocation(() => never.future),
        );
        await tester.pump();
        await tester.pump();
        expect(selectedWorkshop.state, isNull);

        // The page's own limit, in case a service never gives up.
        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();

        expect(selectedWorkshop.state, kutisari);
        expect(find.text('Memuat bengkel...'), findsNothing);
      });

      testWidgets('Konfirmasi stays off until a workshop is there', (
        tester,
      ) async {
        final position = Completer<GeoPoint?>();
        await openCreatePage(
          tester,
          bikesPerOpen: [
            [r25],
          ],
          workshopStream: all,
          location: FakeLocation(() => position.future),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('09:00 - 10:00'));
        await tester.pump();
        await tester.tap(find.text('Pilih motor Anda').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('YAMAHA R25'));
        await tester.pumpAndSettle();
        ElevatedButton confirm() =>
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(confirm().onPressed, isNull);

        position.complete(nearDarmo);
        await tester.pumpAndSettle();

        expect(confirm().onPressed, isNotNull);
      });

      testWidgets('the guide waits for the answer, so a prompt never lands on '
          'it', (tester) async {
        final position = Completer<GeoPoint?>();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await openCreatePage(
          tester,
          guidePrefs: prefs,
          autoGuide: true,
          workshopStream: all,
          location: FakeLocation(() => position.future),
        );

        // Well past the usual start, and still no guide.
        await tester.pump(FieldGuidePlayer.autoDelay);
        await tester.pump(const Duration(seconds: 3));
        expect(find.byType(FieldGuideCard), findsNothing);

        position.complete(nearDarmo);
        await tester.pump(FieldGuidePlayer.retryEvery);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }

        expect(find.byType(FieldGuideCard), findsOneWidget);
        // And what the card talks about is already true.
        expect(selectedWorkshop.state, darmo);
      });
    });
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
