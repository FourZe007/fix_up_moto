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
- **Only new members get it unasked:** with `MainShell.tourBikeCount` given (`AppRouter` reads it from `HomeBloc`; null until the stats load), the host waits for the count and plays only for `AppTourAudience.isNew` (0 bikes). A member with a bike is marked seen without being shown it, so deleting their last bike later cannot bring it back. Unknown never means new. Profile's "Panduan Aplikasi" row still plays it for anyone.
- **It waits before starting:** the host needs the shell to be the screen on top, the app resumed and the bar laid out for 3 checks 500 ms apart. The push-notification explainer is a dialog on the same root navigator, and the tour is a root `OverlayEntry`, which sits above any route pushed after it and would hide that dialog. Do not shorten this wait without moving the explainer.
- **The last step can hand the member on:** `AppTourHost.handoff` (passed down as `MainShell.tourHandoff`, set in `AppRouter` from `HomeBloc`'s bike count via `AppTourHandoff.forBikeCount`) is asked each time the tour starts. For a member with 0 bikes the last card swaps "Selesai" for "Tambah motor sekarang" / "Nanti saja"; accepting closes the tour (via `controller.skip()`, so at once) and the host pushes `RouteNames.addBike`. With a bike, or while the stats are still loading, it ends the plain way. Both answers mark the tour seen.
- The tour blocks taps on the bar and the page while it plays; the card's buttons and "Lewati" are the only ways through and out.
- **First-task guidance** (a booking needs a bike, so the order is bike → booking): the Create Booking bike picker shows "Tambah Motor" when the member has no bike, which opens Add Bike and reopens the picker once a bike is saved; Home shows `FirstBikeCard` ("Tambah motor pertama Anda") while `stats.qty <= 0`. Both are driven by data, not by a remembered flag, so they vanish by themselves once a bike exists (Add Bike invalidates `DataKind.stats`). The "first booking" card (`FirstBookingSlot`, "Buat booking pertama Anda", shown while the member has a bike and is still pending) is the exception: it is **not** data-driven, because bookings are only fetched by date range (`SERVICEBOOKINGHISTORYBYMEMBER`), so the app cannot tell "never booked" cheaply. Instead the phone remembers (`FirstBookingGuide`, SharedPreferences lists `first_booking_pending` / `first_booking_settled`, per member id): Home noting a member with 0 bikes marks them pending, a `DataKind.bookings` signal (only Create Booking sends it) settles them for good. A member the app never saw with 0 bikes, i.e. every existing member, never gets it; a member who booked before the card existed, deleted every bike and added one again would be nudged once more. Opt-in like the tour: `HomePage(prefs:)` null leaves the card out (`AppRouter` passes `sl<SharedPreferences>()`). A tap runs `startGuidedBooking`, so its confirmation points to the Booking tab too.
- **Seeing it all on an account that has bikes (debug only):** `--dart-define=SIMULATE_NEW_MEMBER=true` (`AppConstants.simulateNewMember`; VS Code launch entry "fix_up_moto (new member)"). `SimulatedNewMember.start` (called in `initDependencies`) answers null in a release build whatever is defined, like `applyPreviewPlatform`; otherwise it clears `app_tour_seen` and the two `FirstBookingGuide` lists at every launch and hands `HomeBloc` an object that takes the bikes the account had when the launch first saw it off `stats.qty` (a bike added afterwards counts, so bike → booking offer → booking card all run). Only the count changes, so the Profile tab's bike count shows it too; the bike list, the bike picker and every request are real.
- **Bike → booking chain:** the two guided doors into Add Bike (Home's `FirstBikeCard`, the tour's hand-off via `AppTourHandoff.extra`) open it with `extra: FirstTaskStep.addBike` (`lib/core/router/first_task_step.dart`); `AppRouter` turns that into `AddBikePage(offerBooking: true)`. Then the one confirmation reads "Motor tersimpan. Buat booking sekarang?" with "Buat Booking", which runs `startGuidedBooking` (`features/bookings/presentation/guided_booking.dart`: workshop list if none is chosen, then Create Booking opened as `FirstTaskStep.createBooking`). That form's confirmation reads "Booking berhasil! Lihat di tab Booking." with "Lihat" → `go(RouteNames.bookings)`. Both are `persist: false` snack bars (a snack bar with an action otherwise stays until dismissed) and every other way into either page, My Bikes' FAB or the Bookings tab or Create Booking's own "Tambah Motor", is unchanged. The pointer is tied to the guided start, not to "first booking" (unknowable); `BookingsPage._openCreateBooking` keeps its own copy of the workshop gate on purpose, so the released screen was not touched.

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
