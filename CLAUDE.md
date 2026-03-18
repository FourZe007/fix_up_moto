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

**Critical rule:** BLoCs are registered as **`registerFactory`** (new instance per `BlocProvider`), not singletons. Data sources, repositories, and use cases are `registerLazySingleton`.

### Navigation

`lib/core/router/app_router.dart` — GoRouter with:
- **Auth guard**: `redirect` callback checks `AuthBloc` state before every navigation. Unauthenticated users go to `/login`; authenticated users are bounced away from auth routes.
- **ShellRoute** wraps the four main tabs (`/`, `/services`, `/bookings`, `/profile`) in `MainShell`, keeping the bottom nav bar persistent.
- Nested routes (e.g. `/services/detail/:id`, `/bookings/create`) are children of their parent tab route.

Route name constants are in `lib/core/router/route_names.dart`.

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
