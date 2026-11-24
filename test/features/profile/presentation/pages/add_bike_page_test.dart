import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/tour/field_guide.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:fix_up_moto/features/profile/presentation/widgets/bike_form.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/add_bike_page.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';
import '../../../../support/haptic_recorder.dart';

class MockBikesBloc extends MockBloc<BikesEvent, BikesState>
    implements BikesBloc {}

const workshop = WorkshopEntity(
  branch: '31',
  shop: '01',
  bsName: 'FIXUP MOTO - KEDUNG TARUKAN',
  bsAddress: 'JL. KUTISARI UTARA NO. 16A',
  operationalHours: 'Senin - Jumat 08.00 - 16.00',
  phoneNo: '0312345678',
  active: true,
  lat: -7.3,
  lng: 112.7,
);

void main() {
  late DataRefreshCubit refreshCubit;
  late SelectedWorkshopCubit selectedWorkshop;
  late StreamController<BikesState> states;
  late MockBikesBloc bloc;

  /// What the stand-in booking form was last opened with as its `extra`.
  Object? bookingExtra;

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
    selectedWorkshop = SelectedWorkshopCubit();
    states = StreamController<BikesState>();
    bookingExtra = null;
  });

  tearDown(() async {
    await states.close();
    await selectedWorkshop.close();
    await sl.reset();
  });

  /// Opens the add-bike page on top of a stand-in My Bikes page, returning the
  /// future that completes with whatever the page pops with.
  ///
  /// [offerBooking] opens it as the guidance's bike step. The stand-ins for the
  /// workshop list (which answers with [workshop]) and the booking form are
  /// there for the offer's button to go to.
  ///
  /// [guidePrefs] switches on the field guide (its help button, and its
  /// automatic play when [autoGuide] is also set).
  Future<Future<bool?>> openAddBikePage(
    WidgetTester tester, {
    ThemeData? theme,
    bool offerBooking = false,
    SharedPreferences? guidePrefs,
    bool autoGuide = false,
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
        GoRoute(
          path: '/add',
          builder: (_, _) => AddBikePage(
            offerBooking: offerBooking,
            guidePrefs: guidePrefs,
            autoGuide: autoGuide,
          ),
        ),
        GoRoute(
          path: RouteNames.workshops,
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('workshop-list'),
                TextButton(
                  onPressed: () => context.pop(workshop),
                  child: const Text('Pilih bengkel'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.createBooking,
          builder: (_, state) {
            bookingExtra = state.extra;
            return const Scaffold(body: Text('booking-form'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: refreshCubit),
          BlocProvider.value(value: selectedWorkshop),
        ],
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

  testWidgets("adding a bike also tells Bookings' Riwayat its plates changed", (
    tester,
  ) async {
    final signals = <DataKind?>[];
    final subscription = refreshCubit.stream.listen((s) => signals.add(s.kind));
    addTearDown(subscription.cancel);
    await openAddBikePage(tester);

    states.add(const BikesAdded('Bike added successfully'));
    await tester.pumpAndSettle();

    // Stats stays the last signal; the bikes one goes first.
    expect(signals, [DataKind.bikes, DataKind.stats]);
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

  testWidgets('adding a bike gives a success tap on iOS', (tester) async {
    final haptics = HapticRecorder.start();

    await onDevice(TargetPlatform.iOS, () async {
      await openAddBikePage(tester);

      states.add(const BikesAdded('Bike added successfully'));
      await tester.pumpAndSettle();

      expect(haptics.taps, [successTap]);
    });
  });

  testWidgets('a failed add gives no tap', (tester) async {
    final haptics = HapticRecorder.start();

    await onDevice(TargetPlatform.iOS, () async {
      await openAddBikePage(tester);

      states.add(const BikesError('Server down'));
      await tester.pumpAndSettle();

      expect(haptics.taps, isEmpty);
    });
  });

  testWidgets('a failed add does not signal anything', (tester) async {
    await openAddBikePage(tester);

    states.add(const BikesError('Server down'));
    await tester.pumpAndSettle();

    expect(refreshCubit.state.kind, isNull);
    expect(find.text('my-bikes'), findsNothing);
  });

  group('the field guide', () {
    final card = find.byType(FieldGuideCard);
    final next = find.byKey(const Key('field-guide-next'));
    final back = find.byKey(const Key('field-guide-back'));
    final tag = find.byKey(const Key('field-guide-tag'));
    final skip = find.text('Lewati');
    final helpButton = find.byKey(const Key('add-bike-guide-button'));

    /// The seven steps (six text fields, then the photo box), in the form's
    /// order, and whether each is required.
    const fields = <(String, bool)>[
      ('Merek & Model', true),
      ('Warna', false),
      ('Tahun', false),
      ('Plat Nomor', true),
      ('No Chasis', false),
      ('No Mesin', false),
      ('Foto', false),
    ];

    /// What a step lights: the text field with that label, or the photo box.
    Finder lit(String label) => label == 'Foto'
        ? find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_PhotoPicker',
          )
        : find.widgetWithText(AuthTextField, label);

    Future<SharedPreferences> prefsWith(Map<String, Object> values) {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    /// Lets the guide come up, or move to its next field, after it was asked to.
    ///
    /// Fixed steps rather than `pumpAndSettle`: the overlay's chain (scroll the
    /// field in, light it, fade the card in) has gaps where no frame is
    /// scheduled, and `pumpAndSettle` takes the first gap for the end. A phone
    /// just keeps drawing frames. About 3 s covers the whole chain (fade out,
    /// scroll, light, fade in is about 1.3 s), with room to spare.
    Future<void> settleGuide(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    /// Lets the automatic start's wait pass, then the guide come up.
    Future<void> waitForAutoGuide(WidgetTester tester) async {
      await tester.pump(BikeForm.guideDelay);
      await settleGuide(tester);
    }

    Future<void> pressNext(WidgetTester tester) async {
      await tester.tap(next);
      await settleGuide(tester);
    }

    /// A page for a member with no bike, who has not seen the guide.
    Future<SharedPreferences> openForNewMember(WidgetTester tester) async {
      final prefs = await prefsWith({});
      await openAddBikePage(tester, guidePrefs: prefs, autoGuide: true);
      return prefs;
    }

    group('when it plays', () {
      testWidgets('not at all without guide settings: the page is as it was', (
        tester,
      ) async {
        await openAddBikePage(tester);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(helpButton, findsNothing);
        expect(card, findsNothing);
      });

      testWidgets('by itself the first time, for a member with no bike', (
        tester,
      ) async {
        await openForNewMember(tester);

        await waitForAutoGuide(tester);

        expect(card, findsOneWidget);
        expect(find.text('1 dari 7'), findsOneWidget);
        expect(find.text('Merek & Model'), findsWidgets);
      });

      testWidgets('not before the page has settled in', (tester) async {
        await openForNewMember(tester);

        // Just short of the wait. (pumpAndSettle would step past it.)
        await tester.pump(
          BikeForm.guideDelay - const Duration(milliseconds: 200),
        );

        expect(card, findsNothing);
      });

      testWidgets('not for a member who already has a bike', (tester) async {
        final prefs = await prefsWith({});
        await openAddBikePage(tester, guidePrefs: prefs, autoGuide: false);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(card, findsNothing);
        // They still have the help button.
        expect(helpButton, findsOneWidget);
      });

      testWidgets('not again once the phone has been through it', (
        tester,
      ) async {
        final prefs = await prefsWith({
          FieldGuideSeen.keyFor(FieldGuideId.addBike): true,
        });
        await openAddBikePage(tester, guidePrefs: prefs, autoGuide: true);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(card, findsNothing);
      });

      testWidgets('again from the help button, even when it was seen', (
        tester,
      ) async {
        final prefs = await prefsWith({
          FieldGuideSeen.keyFor(FieldGuideId.addBike): true,
        });
        await openAddBikePage(tester, guidePrefs: prefs, autoGuide: true);

        await tester.tap(helpButton);
        await settleGuide(tester);

        expect(card, findsOneWidget);
        expect(find.text('1 dari 7'), findsOneWidget);
      });

      testWidgets('the help button is not doubled by a second press', (
        tester,
      ) async {
        await openAddBikePage(tester, guidePrefs: await prefsWith({}));

        await tester.tap(helpButton);
        await settleGuide(tester);
        // The overlay swallows taps; ask the form directly, as a fast second
        // tap would.
        final form = tester.state<BikeFormState>(find.byType(BikeForm));

        expect(form.playGuide(), isFalse);
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
      });

      testWidgets('opening it for a replay waits for a raised keyboard', (
        tester,
      ) async {
        await openAddBikePage(tester, guidePrefs: await prefsWith({}));
        await tester.tap(find.widgetWithText(AuthTextField, 'Warna'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();

        await tester.tap(helpButton);
        // Not yet: the keyboard is lowered first.
        await tester.pump(const Duration(milliseconds: 100));
        expect(card, findsNothing);

        tester.view.resetViewInsets();
        await tester.pump(const Duration(milliseconds: 400));
        await settleGuide(tester);
        expect(card, findsOneWidget);
      });
    });

    group('walking through it', () {
      testWidgets(
        'lights the six fields in the form\'s order, with their tag',
        (tester) async {
          await openForNewMember(tester);
          await waitForAutoGuide(tester);

          for (var i = 0; i < fields.length; i++) {
            final (label, required) = fields[i];
            expect(find.text('${i + 1} dari 7'), findsOneWidget, reason: label);
            expect(
              find.descendant(of: card, matching: find.text(label)),
              findsOneWidget,
              reason: label,
            );
            expect(
              find.descendant(
                of: tag,
                matching: find.text(required ? 'Wajib diisi' : 'Opsional'),
              ),
              findsOneWidget,
              reason: '$label is ${required ? 'required' : 'optional'}',
            );
            if (i < fields.length - 1) await pressNext(tester);
          }
        },
      );

      testWidgets(
        'its "Wajib diisi" tags match what the form really insists on',
        (tester) async {
          // Submit the empty form and see which fields refuse: the guide's tags
          // must say the same, or it would mislead.
          useTallScreen(tester);
          await openAddBikePage(tester);

          await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Motor'));
          await tester.pumpAndSettle();

          final refused = find.textContaining('wajib diisi');
          expect(refused, findsNWidgets(2));
          expect(find.text('Merek & Model wajib diisi'), findsOneWidget);
          expect(find.text('Plat nomor wajib diisi'), findsOneWidget);
          expect(fields.where((f) => f.$2).map((f) => f.$1).toList(), [
            'Merek & Model',
            'Plat Nomor',
          ]);
        },
      );

      testWidgets('Kembali goes back a field, and is missing on the first', (
        tester,
      ) async {
        await openForNewMember(tester);
        await waitForAutoGuide(tester);
        expect(back, findsNothing);

        await pressNext(tester);
        await pressNext(tester);
        expect(find.text('3 dari 7'), findsOneWidget);

        await tester.tap(back);
        await settleGuide(tester);

        expect(find.text('2 dari 7'), findsOneWidget);
      });

      testWidgets('the last field says Selesai, and Lewati is gone', (
        tester,
      ) async {
        await openForNewMember(tester);
        await waitForAutoGuide(tester);
        expect(skip, findsOneWidget);

        for (var i = 0; i < fields.length - 1; i++) {
          await pressNext(tester);
        }

        expect(find.text('7 dari 7'), findsOneWidget);
        expect(
          find.descendant(of: next, matching: find.text('Selesai')),
          findsOneWidget,
        );
        expect(skip, findsNothing);
      });

      testWidgets('the help button steps aside while it plays, and comes back', (
        tester,
      ) async {
        await openForNewMember(tester);
        // Hidden, not removed (the title keeps its place), so look at the flag.
        bool buttonShown() => tester
            .widget<Visibility>(
              find
                  .ancestor(of: helpButton, matching: find.byType(Visibility))
                  .first,
            )
            .visible;
        expect(buttonShown(), isTrue);

        await waitForAutoGuide(tester);
        // "Lewati" sits in the same corner: the button must not be under it.
        expect(buttonShown(), isFalse);

        await tester.tap(skip);
        await settleGuide(tester);

        expect(buttonShown(), isTrue);
      });

      testWidgets('takes the form back to its top when it ends', (
        tester,
      ) async {
        // A short screen, so the late fields really scroll.
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await openForNewMember(tester);
        double scrolled() => tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(BikeForm),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .pixels;
        await waitForAutoGuide(tester);
        for (var i = 0; i < fields.length - 1; i++) {
          await pressNext(tester);
        }
        expect(scrolled(), greaterThan(0), reason: 'the last field is below');

        await pressNext(tester); // Selesai
        await settleGuide(tester);

        expect(scrolled(), 0);
      });

      testWidgets('leaves the form as it was when it ends: no extra room', (
        tester,
      ) async {
        await openForNewMember(tester);
        double maxScroll() => tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(BikeForm),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .maxScrollExtent;
        final before = maxScroll();

        await waitForAutoGuide(tester);
        // While it plays the late fields have room to scroll up...
        expect(maxScroll(), greaterThan(before));

        await tester.tap(skip);
        await settleGuide(tester);

        // ...and once it is over the form is exactly its own length again.
        expect(maxScroll(), before);
      });

      testWidgets('a tap on the lit field does nothing: no keyboard, no step', (
        tester,
      ) async {
        await openForNewMember(tester);
        await waitForAutoGuide(tester);

        await tester.tapAt(
          tester.getCenter(find.widgetWithText(AuthTextField, 'Merek & Model')),
        );
        await settleGuide(tester);

        final anyFieldFocused = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .any((field) => field.focusNode.hasFocus);
        expect(anyFieldFocused, isFalse);
        expect(find.text('1 dari 7'), findsOneWidget);
      });
    });

    group('remembering it', () {
      final key = FieldGuideSeen.keyFor(FieldGuideId.addBike);

      testWidgets('opening it is not enough to count as seen', (tester) async {
        final prefs = await openForNewMember(tester);

        await waitForAutoGuide(tester);

        expect(prefs.getBool(key), isNull);
      });

      testWidgets('Selesai marks it seen and closes it', (tester) async {
        final prefs = await openForNewMember(tester);
        await waitForAutoGuide(tester);

        for (var i = 0; i < fields.length - 1; i++) {
          await pressNext(tester);
        }
        await pressNext(tester);

        expect(card, findsNothing);
        expect(prefs.getBool(key), isTrue);
      });

      testWidgets('Lewati marks it seen and closes it', (tester) async {
        final prefs = await openForNewMember(tester);
        await waitForAutoGuide(tester);
        await pressNext(tester);

        await tester.tap(skip);
        await tester.pumpAndSettle();

        expect(card, findsNothing);
        expect(prefs.getBool(key), isTrue);
      });

      testWidgets('leaving the page halfway removes it and keeps it unseen', (
        tester,
      ) async {
        final prefs = await openForNewMember(tester);
        await waitForAutoGuide(tester);
        await pressNext(tester);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('my-bikes'), findsOneWidget);
        expect(card, findsNothing);
        expect(find.text('Lewati'), findsNothing);
        // So it comes round again the next time they open the page.
        expect(prefs.getBool(key), isNull);
      });

      testWidgets('a replay marks it seen too, at the end', (tester) async {
        final prefs = await prefsWith({});
        await openAddBikePage(tester, guidePrefs: prefs);

        await tester.tap(helpButton);
        await settleGuide(tester);
        await tester.tap(skip);
        await tester.pumpAndSettle();

        expect(prefs.getBool(key), isTrue);
      });
    });

    group('it never loses the field or the card off the screen', () {
      // A phone, a small phone and the test default: the form is longer than
      // all of them, so the later fields start below the fold.
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
          await openForNewMember(tester);
          await waitForAutoGuide(tester);
          final screen = Offset.zero & size;

          for (var i = 0; i < fields.length; i++) {
            final label = fields[i].$1;
            final field = tester.getRect(lit(label));
            final cardRect = tester.getRect(card);

            expect(
              screen.contains(field.topLeft),
              isTrue,
              reason: '$label top-left is on screen: $field',
            );
            expect(
              screen.contains(field.bottomRight),
              isTrue,
              reason: '$label bottom-right is on screen: $field',
            );
            expect(
              screen.contains(cardRect.topLeft),
              isTrue,
              reason: 'card for $label top-left is on screen: $cardRect',
            );
            expect(
              screen.contains(cardRect.bottomRight),
              isTrue,
              reason: 'card for $label bottom-right is on screen: $cardRect',
            );
            expect(
              cardRect.overlaps(field),
              isFalse,
              reason: 'card for $label does not cover it: $cardRect vs $field',
            );

            if (i < fields.length - 1) await pressNext(tester);
          }
        });
      }
    });
  });

  group('the confirmation', () {
    final saved = find.text('Motor berhasil ditambah!');
    final offer = find.text('Motor tersimpan. Buat booking sekarang?');
    final bookButton = find.text('Buat Booking');

    testWidgets('is the plain one, with no offer, when opened as usual', (
      tester,
    ) async {
      await openAddBikePage(tester);

      states.add(const BikesAdded('Bike added successfully'));
      await tester.pumpAndSettle();

      expect(saved, findsOneWidget);
      expect(offer, findsNothing);
      expect(bookButton, findsNothing);
    });

    testWidgets("offers a booking when opened as the guidance's bike step", (
      tester,
    ) async {
      await openAddBikePage(tester, offerBooking: true);

      states.add(const BikesAdded('Bike added successfully'));
      await tester.pumpAndSettle();

      expect(offer, findsOneWidget);
      expect(bookButton, findsOneWidget);
      // One confirmation, not two stacked.
      expect(saved, findsNothing);
    });

    testWidgets('still pops with true and tells the app, offer or not', (
      tester,
    ) async {
      final signals = <DataKind?>[];
      final subscription = refreshCubit.stream.listen(
        (s) => signals.add(s.kind),
      );
      addTearDown(subscription.cancel);
      final result = await openAddBikePage(tester, offerBooking: true);

      states.add(const BikesAdded('Bike added successfully'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
      expect(find.text('my-bikes'), findsOneWidget);
      expect(signals, [DataKind.bikes, DataKind.stats]);
    });

    testWidgets('offers nothing when the add failed', (tester) async {
      await openAddBikePage(tester, offerBooking: true);

      states.add(const BikesError('Server down'));
      await tester.pumpAndSettle();

      expect(offer, findsNothing);
      expect(bookButton, findsNothing);
      expect(find.text('Server down'), findsOneWidget);
    });

    testWidgets('lapses by itself, and starts nothing, if it is ignored', (
      tester,
    ) async {
      await openAddBikePage(tester, offerBooking: true);
      states.add(const BikesAdded('Bike added successfully'));
      await tester.pumpAndSettle();
      expect(offer, findsOneWidget);

      // A snack bar with a button would normally stay until dismissed.
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();

      expect(offer, findsNothing);
      expect(find.text('workshop-list'), findsNothing);
      expect(find.text('booking-form'), findsNothing);
      expect(find.text('my-bikes'), findsOneWidget);
    });

    group('"Buat Booking"', () {
      Future<void> addBikeAndTapOffer(WidgetTester tester) async {
        await openAddBikePage(tester, offerBooking: true);
        states.add(const BikesAdded('Bike added successfully'));
        await tester.pumpAndSettle();
        await tester.tap(bookButton);
        await tester.pumpAndSettle();
      }

      testWidgets('opens the booking form straight away, as the booking step', (
        tester,
      ) async {
        await addBikeAndTapOffer(tester);

        // No workshop list in front of it: the form picks a workshop itself.
        expect(find.text('workshop-list'), findsNothing);
        expect(find.text('booking-form'), findsOneWidget);
        expect(bookingExtra, FirstTaskStep.createBooking);
      });

      testWidgets('does the same with a workshop already chosen', (
        tester,
      ) async {
        selectedWorkshop.select(workshop);

        await addBikeAndTapOffer(tester);

        expect(find.text('workshop-list'), findsNothing);
        expect(find.text('booking-form'), findsOneWidget);
        expect(bookingExtra, FirstTaskStep.createBooking);
        expect(selectedWorkshop.state, workshop);
      });

      testWidgets('leaves the workshop choice to the form', (tester) async {
        await addBikeAndTapOffer(tester);

        expect(selectedWorkshop.state, isNull);
      });

      testWidgets('back from the form returns to where the member was', (
        tester,
      ) async {
        await addBikeAndTapOffer(tester);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('booking-form'), findsNothing);
        expect(find.text('my-bikes'), findsOneWidget);
      });
    });
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

  group('the photo', () {
    // A 1x1 PNG, which the faked gallery hands back from a file on disk.
    const photoBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA6'
        '0e6kgAAAABJRU5ErkJggg==';
    final emptyPhotoIcon = find.byIcon(Icons.camera_alt_outlined);
    final confirmPanel = find.byKey(const Key('confirm-panel'));
    final confirmButton = find.byKey(const Key('confirm-panel-confirm'));
    final cancelButton = find.byKey(const Key('confirm-panel-cancel'));

    /// Opens the page and picks a photo through a gallery that answers with the
    /// PNG above, so the close badge is there to tap.
    Future<void> openWithPickedPhoto(WidgetTester tester) async {
      useTallScreen(tester);
      await openAddBikePage(tester);

      final dir = Directory.systemTemp.createTempSync('add_bike_photo');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/photo.png')
        ..writeAsBytesSync(base64Decode(photoBase64));

      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'pickImage' ? file.path : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.tap(emptyPhotoIcon);
      // Reading the file is real I/O in several steps, and each one's
      // continuation only runs once the test clock is pumped — so wait for the
      // photo in turns of real time and pumping, rather than once.
      for (var i = 0; i < 50 && emptyPhotoIcon.evaluate().isNotEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(emptyPhotoIcon, findsNothing, reason: 'the photo was picked');
    }

    testWidgets('is asked about first, in the sliding panel and not a dialog', (
      tester,
    ) async {
      await openWithPickedPhoto(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(confirmPanel, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.descendant(of: confirmPanel, matching: find.text('Hapus Foto')),
        findsOneWidget,
      );
      expect(emptyPhotoIcon, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays when the member says Batal, and is still sent', (
      tester,
    ) async {
      await openWithPickedPhoto(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(confirmPanel, findsNothing);
      expect(emptyPhotoIcon, findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Merek & Model'),
        'Honda Beat',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Plat Nomor'),
        'L 1234 AB',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Motor'));
      await tester.pump();

      final sent =
          verify(() => bloc.add(captureAny())).captured.single
              as BikeAddRequested;
      expect(sent.photo, photoBase64);
    });

    testWidgets('goes, leaving the empty box, once the member confirms', (
      tester,
    ) async {
      await openWithPickedPhoto(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(confirmPanel, findsNothing);
      expect(emptyPhotoIcon, findsOneWidget);
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
        tester.widget<Icon>(find.byIcon(Icons.camera_alt_outlined)).color,
        AppColors.primary,
      );
    });
  });
}
