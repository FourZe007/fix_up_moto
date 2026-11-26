# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About the Project

**fix_up_moto** is a Flutter motorcycle repair and service booking app. It targets the REST API at `https://api.fixupmoto.com/v1` (defined in `lib/core/constants/api_constants.dart`).

## Commands

```bash
# Run the app
flutter run

# Analyze (lint)
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart

# Regenerate code after modifying @freezed or @JsonSerializable classes
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

The app follows **Clean Architecture** with a strict 3-layer structure per feature:

```
lib/
  core/           # Shared infrastructure (DI, routing, network, theme, error types)
  features/
    <feature>/
      data/       # datasources, models (JSON models with .g.dart), repository impls
      domain/     # entities, abstract repositories, use cases
      presentation/ # bloc (events/states), pages, widgets
```

**Features:** `auth`, `home`, `services`, `bookings`, `profile`

### Data Flow

`Presentation (BLoC)` → `UseCase` → `Repository (abstract)` → `RepositoryImpl` → `DataSource`

- **Data sources** call Dio and throw typed exceptions (`lib/core/error/exceptions.dart`).
- **Repository impls** catch exceptions and convert them to `Failure` subtypes (`lib/core/error/failures.dart`), returning `Either<Failure, T>` from `dartz`.
- **Use cases** extend `UseCase<T, P>` or `NoParamsUseCase<T>` from `lib/core/usecases/usecase.dart`. Called like functions: `await useCase(params)`.
- **BLoCs** call use cases and `fold()` the `Either` result to emit success or error states.

### Dependency Injection

GetIt is the service locator, accessed globally as `sl<Type>()`.

All registrations live in `lib/core/di/injection_container.dart` → `initDependencies()`, called once in `main()` before `runApp()`.

**Critical rule:** the split is *page-scoped vs app-scoped*, not *BLoC vs everything else*.

- **Page-scoped BLoCs** (`ServicesBloc`, `BookingsBloc`, `ProfileBloc`) are
  **`registerFactory`** — a new instance per `BlocProvider`, so state cannot bleed between
  screen navigations.
- **`AuthBloc` is `registerLazySingleton`.** It is created once at the root in `App.build` and
  lives for the whole run, so the bleeding hazard cannot arise — and `AppRouter` must observe
  that exact instance through `refreshListenable`.
- **`HomeBloc` is `registerLazySingleton` too.** It holds the member's stats record (name, phone,
  email, points, point history), which Home, Profile, MyPoint and Edit Profile all read, so it is
  loaded once instead of once per page. Pages **read** it and never dispatch `HomeStatsRequested`
  on mount; only `StatsBootstrap` (`lib/features/home/presentation/widgets/stats_bootstrap.dart`)
  loads it at sign-in, reloads it on `DataRefreshCubit.invalidate(DataKind.stats)`, and sends
  `HomeResetRequested` at sign-out so one member's data never shows for the next. A reload while
  stats are on screen emits `HomeLoaded(refreshing: true)` rather than `HomeLoading`, so nothing
  unmounts (an open Edit Profile form keeps its text). Like `AuthBloc`, provide it with
  `BlocProvider.value`, never `create:`. A page that only needs *some* of this data still reads the
  same bloc: do not add a second loader for the same record (`ProfileLoadRequested` is unused for
  that reason).
- Data sources, repositories, and use cases are `registerLazySingleton`.

`AuthBloc` must be provided with **`BlocProvider.value`**, never `create:`. `create:` transfers
ownership, so `BlocProvider` would close the singleton on dispose and `sl<AuthBloc>()` would hand
out a closed bloc for the rest of the process.

### Navigation

`lib/core/router/app_router.dart` — GoRouter with:
- **Auth guard**: `redirect` checks `AuthBloc` state. Unauthenticated users go to `/login`; authenticated users are bounced away from auth routes.
- **`refreshListenable`**: `GoRouterRefreshStream(sl<AuthBloc>().stream)` — **required**. `redirect` is not reactive; it runs only on route resolution, navigation, or a listenable firing. Without it the guard is evaluated once at startup against an unresolved state and never again, so an unauthenticated launch stays on the dashboard and a successful login never navigates.
- **Splash route** (`/`) is `initialLocation`. `AuthInitial` means "cold start, still checking" and holds the splash; `AuthLoading` means "an operation is in flight" and the router leaves the user where they are. `AuthBloc` deliberately does **not** emit `AuthLoading` during the session check — conflating the two would eject the user from the login form mid-request.
- **ShellRoute** wraps the four main tabs (`/`, `/services`, `/bookings`, `/profile`) in `MainShell`, keeping the bottom nav bar persistent.
- Nested routes (e.g. `/services/detail/:id`, `/bookings/create`) are children of their parent tab route.

Route name constants are in `lib/core/router/route_names.dart`.

### App Tour

`lib/core/tour/` — a one-time walk through the five bottom-bar tabs, built on `tutorial_coach_mark` (Bahasa copy, one step per tab in `AppTourSteps.all`; each title must match the tab's label, a test checks it).

- **`AppTourHost`** wraps `MainShell`'s `Scaffold`. It owns one `GlobalKey` per tab and hands them to `AppTabBar.tabKeys` / `IosFloatingTabBar.tabKeys` (null = the bars are drawn exactly as before), plays the tour by itself once, and exposes `AppTourScope.start` so Profile's "Panduan Aplikasi" row can replay it. No page is wrapped in the package's own widgets.
- **Opt-in by constructor, so existing tests are untouched:** `MainShell(prefs:)` null means no automatic start, and `AppTourScope.maybeOf` null means Profile leaves the row out. `AppRouter` passes `sl<SharedPreferences>()`.
- **Seen** is `AppTourSeen` (`app_tour_seen` in SharedPreferences, like `WelcomeSeen`), marked when the tour *ends* (Selesai or Lewati), not when it opens, so a member who closes the app halfway gets it again.
- **Only new members get it unasked:** with `MainShell.tourBikeCount` given (`AppRouter` reads it from `HomeBloc`; null until the stats load), the host waits for the count and plays only for `AppTourAudience.isNew`: **0 bikes, or a bike and a first booking still to make** (`MainShell.tourBookingPending`, which `AppRouter` answers with `FirstBookingGuide.isPending` for the member in `HomeBloc`; false until the stats load). Anyone else (a bike, and booked or never noted new, which is every existing member) is marked seen without being shown it, so deleting their last bike later cannot bring it back. Unknown never means new. In a debug build the host prints one `[app tour] ...` line to the console each time the reason it is not starting changes (stats not loaded, a dialog or page on top, app not in the foreground, bar not drawn, counting quiet checks, not for this member, starting), so a tour that never appears can be explained. Profile's "Panduan Aplikasi" row still plays it for anyone.
- **It waits before starting:** the host needs the shell to be the screen on top, the app resumed and the bar laid out for 3 checks 500 ms apart. The push-notification explainer is a dialog on the same root navigator, and the tour is a root `OverlayEntry`, which sits above any route pushed after it and would hide that dialog. Do not shorten this wait without moving the explainer.
- **The last step can hand the member on:** `AppTourHost.handoff` (passed down as `MainShell.tourHandoff`, set in `AppRouter` from `HomeBloc`'s bike count and the first-booking flag via `AppTourHandoff.forBikeCount(count, bookingPending:)`) is asked each time the tour starts. It is a task (`AppTourHandoffTask`), and the last card swaps "Selesai" for the offer and "Nanti saja": for a member with 0 bikes `addFirstBike`, "Tambah motor sekarang" (a bike comes first, so it wins over pending), which pushes `RouteNames.addBike` as `FirstTaskStep.addBike`; for a member with a bike and a first booking to make `bookFirstService`, "Buat booking sekarang", which runs `startGuidedBooking` (the same start as Home's "Buat booking pertama Anda" card, so it ends in the "Lihat" pointer; it opens the booking form straight away, with no workshop step in front). Accepting closes the tour (via `controller.skip()`, so at once) and the host opens the task. With a bike and nothing to make, or while the stats are still loading, it ends the plain way. Both answers mark the tour seen. The offer's icon is the task's own (`AppTourHandoff.icon`).
- The tour blocks taps on the bar and the page while it plays; the card's buttons and "Lewati" are the only ways through and out.
- **First-task guidance** (a booking needs a bike, so the order is bike → booking): the Create Booking bike picker shows "Tambah Motor" when the member has no bike, which opens Add Bike and reopens the picker once a bike is saved; Home shows `FirstBikeCard` ("Tambah motor pertama Anda") while `stats.qty <= 0`. Both are driven by data, not by a remembered flag, so they vanish by themselves once a bike exists (Add Bike invalidates `DataKind.stats`). The "first booking" card (`FirstBookingSlot`, "Buat booking pertama Anda", shown while the member has a bike and is still pending) is the exception: it is **not** data-driven, because bookings are only fetched by date range (`SERVICEBOOKINGHISTORYBYMEMBER`), so the app cannot tell "never booked" cheaply. Instead the phone remembers (`FirstBookingGuide`, SharedPreferences lists `first_booking_pending` / `first_booking_settled`, per member id): Home noting a member with 0 bikes marks them pending, a `DataKind.bookings` signal (only Create Booking sends it) settles them for good. A member the app never saw with 0 bikes, i.e. every existing member, never gets it; a member who booked before the card existed, deleted every bike and added one again would be nudged once more. Opt-in like the tour: `HomePage(prefs:)` null leaves the card out (`AppRouter` passes `sl<SharedPreferences>()`). A tap runs `startGuidedBooking`, so its confirmation points to the Booking tab too.
- **Seeing it all on an account that has bikes (debug only):** `--dart-define=SIMULATE_NEW_MEMBER=true` (`AppConstants.simulateNewMember`; VS Code launch entry "fix_up_moto (new member)"). `SimulatedNewMember.start` (called in `initDependencies`) answers null in a release build whatever is defined, like `applyPreviewPlatform`; otherwise it clears `app_tour_seen` and the two `FirstBookingGuide` lists at every launch and hands `HomeBloc` an object that takes the bikes the account had when the launch first saw it off `stats.qty` (a bike added afterwards counts, so bike → booking offer → booking card all run). Only the count changes, so the Profile tab's bike count shows it too; the bike list, the bike picker and every request are real.
- **The other half, a member who has bikes but has not booked (debug only):** `--dart-define=SIMULATE_FIRST_BOOKING=true` (`AppConstants.simulateFirstBooking`; VS Code launch entry "fix_up_moto (first booking)"). `SimulatedFirstBooking.start` (also called in `initDependencies`) answers null in a release build whatever is defined. It changes **no stats**: the bikes stay real. What it changes is the phone's memory: `HomeBloc` awaits `SimulatedFirstBooking.prepare(stats)` before it emits a member's stats, and the first time a launch sees that member `prepare` wipes both `FirstBookingGuide` lists and notes them pending, so Home shows "Buat booking pertama Anda" (the card needs a bike, which they have) and its tap runs the guided booking to the "Lihat" pointer. A booking settles them as usual and the card goes; a later reload does not note them again (once per member per launch), and `HomeResetRequested` (sign-out) allows it once more. `start` also clears `app_tour_seen` at every launch (like the new-member one), and because that member is pending the tour plays (a member with a bike who is pending is new to it), ending in "Buat booking sekarang" → the same guided booking. The new-member launch's tour ends in "Tambah motor sekarang" → Add Bike → "Buat Booking" → "Lihat". `test/core/debug/simulated_launches_tour_test.dart` runs each launch end to end (real `HomeBloc` + simulation + `AppTourHost`) for an account that really has bikes. The two launch entries can be told apart by what they change, count (new member) vs memory (first booking); they are not meant to be combined.
- **Add Bike field guide** (`lib/core/tour/field_guide.dart`, `field_guide_seen.dart`; wired in `BikeForm` and `AddBikePage`): a second, page-level coach-mark walk, this time over the form of Add Bike: its six **text fields** (Merek & Model, Warna, Tahun, Plat Nomor, No Chasis, No Mesin) and then the **Foto** box (7 steps; the photo is not a text field, but it has no label or hint to explain it, and the user asked for it after the first build stopped at six), one card each saying what to type or do, where it is on the STNK, and a "Wajib diisi" / "Opsional" tag (only Merek & Model and Plat Nomor are required, and a test checks the tags against the real validators). It reuses the app tour's look and package (`buildFieldGuide`, `FieldGuideCard`).
  - **Opt-in by constructor, so Edit Bike and old tests are untouched:** `AddBikePage(guidePrefs:)` null leaves the page exactly as it was; given, it shows a "?" help button (`add-bike-guide-button`, tooltip "Panduan pengisian") that replays the guide for anyone, and `autoGuide` makes it also play by itself once. `AppRouter` passes `sl<SharedPreferences>()` and `autoGuide: bikes != null && AppTourAudience.isNew(bikes)`, i.e. only for a member with **no bike** (same "no bike = new" rule as the tour; unknown never counts), whichever way they reached the page.
  - **Seen** is `FieldGuideSeen` (`field_guide_seen_add_bike` in SharedPreferences, per phone, id `FieldGuideId.addBike`), marked when the guide *ends* (Selesai or Lewati), not when it opens, so leaving the page halfway shows it again. The automatic start waits `BikeForm.guideDelay` (800 ms) for the page's slide-in and skips if something is on top.
  - **Layout, learned the hard way:** the form is longer than a phone, and the package measures a field where it is *now*, so `BikeForm` awaits `Scrollable.ensureVisible` in `buildFieldGuide`'s `reveal` (alignment 0.2) before each step, and adds blank scroll room (`_guideRoom`, 0.8 × screen height) under the photo *while the guide plays* so the last fields can scroll up too. That is what lets every card sit **below** its field: a card above a field ran off the top of a short screen. A test checks field and card stay on screen and the card never covers the field at 412x915, 360x640 and 800x600. Taps on the lit field do nothing (`enableTargetTab: false`). The step animations are 400/250 ms (the package's 600 ms each way ignores taps for ~1.8 s per step). In widget tests use fixed-step pumps (`settleGuide` in `add_bike_page_test.dart`), not `pumpAndSettle`, which stops at the first frame-less gap in the overlay's chain.
  - **Two details found by running it on the emulator:** while the guide plays the app bar's "?" steps aside (`BikeForm.guideActive`, a `ValueNotifier` the page owns; `Visibility(maintainSize: true)` so the title keeps its place), because the guide's "Lewati" sits in the same top-right corner and landed on top of it; and when the guide ends the form scrolls back to its top (`_scroll`), since it otherwise stays wherever the last field was.
  - **Shared machinery (`FieldGuidePlayer`, `field_guide_player.dart`):** a page owns one in its `State` and gives it its steps, its `onRoomChanged` (the page draws the blank scroll room), its `ScrollController` and a `ValueNotifier` for "guide is playing"; it then calls `autoPlayOnce()` (initState), `play()` (help button) and `dispose()`. It holds everything that is not looks: the 800 ms wait, skipping if something is on top, waiting for a raised keyboard, asking for scroll room and a frame before showing, scrolling each step to alignment 0.2 (a step outside the scroll view, like a fixed bar, just returns), marking seen at the end, going back to the top, and removing the overlay on dispose. `FieldGuideHelpButton` is the "?" (hides while the guide plays, keeps its place). `FieldGuideStep` has an optional `required` (null = no tag), `warning` (a caution box under the message) and `cardAbove` (for something fixed at the bottom of the screen). Add Bike and Create Booking both use all of it; ids are in `FieldGuideId`.
  - **Create Booking guide** (`CreateBookingPage(guidePrefs:, autoGuide:)`, 6 steps): Bengkel (says the workshop nearest the member is chosen automatically, the first one if location is off, check it or change it; worded as what the page does, not as done, because on a cold start the row can still read "Memuat bengkel..." when the guide opens), Motor, Tanggal (the date strip), Jam (the three chips), Catatan, Konfirmasi (the sticky summary bar, card **above** it). Tags: Motor, Tanggal and Jam "Wajib diisi" (what `_submit` insists on; the date holds the earliest day already), Catatan "Opsional", Bengkel and Konfirmasi none. **The Motor step carries a warning box under its explanation**: "Jangan lupa, Anda harus mengisi data motor terlebih dahulu sebelum bisa membuat booking." (the user asked for it; kept short because the card with it ran off a 360x640 screen when it also had a second sentence). `AppRouter` passes `autoGuide: _memberBookingPending()`, so it plays by itself, once, only for a member whose first booking is still to make, whichever way they got there; everyone else has the "?" button. Both debug launches clear its seen flag (`FieldGuideId.createBooking`).
  - **Debug:** `SimulatedNewMember.start` also clears the field guide's seen flag, so the `fix_up_moto (new member)` launch plays tour → Add Bike → the guide at every launch. The first-booking launch has real bikes, so the guide does not play by itself there; the help button still works.
- **Bike → booking chain:** the two guided doors into Add Bike (Home's `FirstBikeCard`, the tour's hand-off via `AppTourHandoff.extra`) open it with `extra: FirstTaskStep.addBike` (`lib/core/router/first_task_step.dart`); `AppRouter` turns that into `AddBikePage(offerBooking: true)`. Then the one confirmation reads "Motor tersimpan. Buat booking sekarang?" with "Buat Booking", which runs `startGuidedBooking` (`features/bookings/presentation/guided_booking.dart`: opens Create Booking straight away as `FirstTaskStep.createBooking`; there is **no workshop step in front of it**, see below). That form's confirmation reads "Booking berhasil! Lihat di tab Booking." with "Lihat" → `go(RouteNames.bookings)`. Both are `persist: false` snack bars (a snack bar with an action otherwise stays until dismissed) and every other way into either page, My Bikes' FAB or the Bookings tab or Create Booking's own "Tambah Motor", is unchanged. The pointer is tied to the guided start, not to "first booking" (unknowable).
- **The workshop is chosen on Create Booking, not before it** (changed 2026-11-24 at the user's request, after the field guide made the page self-explanatory). `startGuidedBooking`, the Bookings tab's button (`BookingsPage._openCreateBooking`) and a service's "Book Again" all push straight to the form, so the old `Pilih Bengkel` step in front of it is gone. `CreateBookingPage` provides a lazy `WorkshopsBloc`; if `SelectedWorkshopCubit` is empty when the page opens, `_findDefaultWorkshop` asks for the list and selects the **nearest active workshop** to the member, or the **first active one** whenever the position is unknown (the list shows inactive workshops but will not let you pick them), then shows it in the workshop row, which still opens the list to change it. A choice already there (from Home, or earlier) is kept and costs no request, and a pick the member makes while the list loads is never overridden. While it loads the row says "Memuat bengkel..."; if the list fails or has no open workshop the row reads "Pilih bengkel favorit kamu" and works the usual way. Konfirmasi stays off until a workshop is there (`_SummaryBar.hasWorkshop`), and `_submit` no longer force-unwraps the workshop (a service's "Book Again" used to reach it with none). **Nearest, and what is live today:** `nearestWorkshop` (`features/workshops/domain/nearest_workshop.dart`, with haversine `distanceKm` and `GeoPoint` in `core/helpers/geo.dart`) skips inactive workshops and ones without real coordinates (0,0, out of range, NaN) and keeps list order on a tie. The position comes from `LocationService.currentPosition()` (`core/services/location_service.dart`), whose contract is: never throws, answers null when location is off / refused / too slow, gives up after a few seconds, asks for permission at most once per run, and never stores, logs or sends the position (a page may hold it while it is open) (`GeoPoint` prints nothing about itself). The page adds its own **30 s** limit on that wait, a safety net only (the service limits the fix itself to **8 s**, 10 s with its grace; the rest of the wait is the member reading the system prompt, which cannot be hurried. It was 4 s until 2026-11-25: too short a limit silently defaults to the first workshop, while waiting costs little because the row stays tappable). **It is live:** `GeolocatorLocationService` (`core/services/geolocator_location_service.dart`, registered in `injection_container.dart`) sits on the `geolocator` package (^14.1.2) through a small `LocationGateway` so its rules can be tested without a phone: location off for the phone answers null and asks nothing; already allowed carries on; not allowed yet shows the system prompt **once per app run**; "never" is never asked; the phone's remembered position is used only if under 15 minutes old, else a fresh **low-accuracy** fix. Android declares only `ACCESS_COARSE_LOCATION` (not fine, on purpose) and iOS `NSLocationWhenInUseUsageDescription` (Bahasa). While a position is being looked up the guide holds back: `FieldGuidePlayer.autoPlayOnce(ready:)` re-asks every 300 ms and also waits for the app to be in the foreground (a system permission prompt pauses it), for up to `waitAtMost` = **35 s of foreground time** (longer than the page's 30 s limit, so it never starts in the middle of the lookup, and time behind a prompt does not use it up). If location is off or refused the default is list order, so a wrong-branch booking is possible if the member does not look; the guide's Bengkel step says the nearest is chosen automatically (first one if location is off) and to check it. Not yet seen on a real Android phone or an iPhone. Also unseen: from the plugin's code, a phone whose location settings do not suit a low-power request may get a second Google dialog ("turn on location accuracy").
  - **The workshop list is sorted nearest first** (`WorkshopListPage`, added 2026-11-25; opened from Home's workshop row and Create Booking's). `sortByDistance` (`nearest_workshop.dart`): open ones nearest first, then open ones that cannot be placed, then **closed ones at the bottom** (same order among themselves); ties keep the server's order, so the top card is always `nearestWorkshop`, Create Booking's default. Each card shows the straight-line distance ("± 2,4 km", "< 0,1 km" under 100 m; nothing when either end is unknown), approximate because the position is coarse. The spinner stays until **both** the list and the position have answered, so a card never moves under a finger (an empty list does not wait: there is nothing to order). A line under the spinner (`_LoadingView`) says which wait it is, and the two must not be mixed up: "Memuat..." while the list itself is coming from the server, even though the position is being looked up alongside; "Mencari bengkel terdekat dari lokasi Anda..." **only** once the list has arrived and the position is all that is left; the same 30 s safety limit as Create Booking applies. Pull-to-refresh and Retry ask the position again (never a second prompt). With no position the list is in the server's order, as before, with a line above it, **"Lokasi Anda gagal ditemukan"** (only once the lookup is over; it covers off, refused and too slow alike, and goes when a pull-to-refresh finds the position). The wording is deliberate: it is the member's position that failed, and "lokasi terdekat" would read as if no branch were near. So the location prompt can now appear from Home too, and the iOS prompt text no longer says it is only for booking. Tests that pump the page must register a `LocationService` in `sl`. **Seen on the emulator (2026-11-25):** from Home (with the prompt) and from Create Booking, all 7 live branches were in the right order and the top card matched the booking default; with location off, server order and no distance. The shown distances were 0.4 to 1.6 km longer than the mock position's; one point **1.54 km** from the mock explains all seven to 0.02 km, so the maths is right and the app was handed a shifted position, most likely Android blurring approximate location. So on a coarse permission the km (and the order, or the booking default, between two branches at nearly equal distance) can be wrong by about that much; asking for precise location would be the way to change it, and has not been decided.
  - **`[location]` console lines** (kept on purpose; debug and profile builds, never release): the service prints which step it reached and, on a failure, only the error's type, **never a position**. Keep it that way. They explain a default that was not the nearest, and the times between "taking a new fix" and "position found" are how to measure a real phone before changing the 8 s.
  - **Testing it on the Android emulator** (learned 2026-11-24/25; `scripts/fake_location.ps1` does the mocking for you, and without it the emulator gives no coarse fix, so every lookup ends in a TimeoutException and the list stays in server order): mock **both** the `network` and `gps` test providers (`adb shell cmd location providers add-test-provider ...`; it needs the shell's `mock_location` app-op set to allow), and keep re-sending the position, since a mock provider only emits when told (with `network` alone the fresh fix timed out). The plugin asks Google Play services, whose **remembered position is separate from what `dumpsys location` shows**: after moving the mock, the app still used the previous spot (under 15 minutes old) and picked that area's branch. Switching location off and on (`settings put secure location_mode 0`, then `3`) cleared it and forces the **fresh fix**. `uiautomator dump` only reads the top window, so check "no guide behind the system prompt" with a screenshot. After "Don't allow", run `pm clear-permission-flags ... user-set user-fixed` to be a first-time member again. A second visit to Create Booking never looks the position up (the chosen workshop lasts the whole run), so the service's once-per-run rule can only be checked by calling it directly (Dart VM `evaluate` under `flutter run`).
  - **Seen live on the emulator (2026-11-25):** the prompt with no guide behind it 12 s in; Allow near Darmo picked DARMO; Don't allow gave KUTISARI (first active), and neither a second visit nor a second direct call to the service prompted again; location off gave KUTISARI with no prompt; a forced fresh fix picked BS. RIYADI (Malang) and GEDANGAN; with 8 s, a fix delayed 5 s still picked DARMO and no fix at all gave up at 8.0 s (with 4 s the same 5 s delay lost it to KUTISARI). The delays were simulated, so this says nothing about how fast a **real** phone gets a fix.

### Networking

`DioClient` (`lib/core/network/dio_client.dart`) is a singleton wrapping Dio with:
1. `AuthInterceptor` — injects `Authorization: Bearer <token>` header from `FlutterSecureStorage`.
2. `LoggingInterceptor` — logs requests/responses.

Data sources receive `sl<DioClient>().dio` directly.

### Code Generation

Models under `data/models/` use `@JsonSerializable` and may use `@freezed`. Generated files end in `.g.dart`. After modifying these classes, run `build_runner` to regenerate.

### Error Hierarchy

`Failure` subtypes (all in `lib/core/error/failures.dart`):
- `ServerFailure` (non-2xx, optional `statusCode`)
- `NetworkFailure` (no connectivity)
- `AuthFailure` (401 / expired token)
- `CacheFailure` (local storage errors)
- `ValidationFailure` (form/business rule errors, carries `fieldErrors` map)
- `PermissionFailure` (403)
- `NotFoundFailure` (404)

### Testing

Tests live under `test/features/<feature>/`. Use `mocktail` for mocks and `bloc_test` (`blocTest`, `whenListen`) for BLoC unit tests. No code generation is needed for mocks.
