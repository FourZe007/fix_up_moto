import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import 'package:fix_up_moto/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fix_up_moto/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/login_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/register_usecase.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/bookings/data/datasources/bookings_remote_data_source.dart';
import 'package:fix_up_moto/features/bookings/data/repositories/bookings_repository_impl.dart';
import 'package:fix_up_moto/features/bookings/domain/repositories/bookings_repository.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/cancel_booking_usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/create_booking_usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/get_bookings_usecase.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/home/data/datasources/home_remote_data_source.dart';
import 'package:fix_up_moto/features/home/data/repositories/home_repository_impl.dart';
import 'package:fix_up_moto/features/home/domain/repositories/home_repository.dart';
import 'package:fix_up_moto/features/home/domain/usecases/get_dashboard_stats_usecase.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:fix_up_moto/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/profile_repository.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/services/data/datasources/services_remote_data_source.dart';
import 'package:fix_up_moto/features/services/data/repositories/services_repository_impl.dart';
import 'package:fix_up_moto/features/services/domain/repositories/services_repository.dart';
import 'package:fix_up_moto/features/services/domain/usecases/get_service_detail_usecase.dart';
import 'package:fix_up_moto/features/services/domain/usecases/get_services_usecase.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/core/network/dio_client.dart';
import 'package:fix_up_moto/core/network/interceptors/auth_interceptor.dart';
import 'package:fix_up_moto/core/network/network_info.dart';

/// Global service locator instance.
/// Access dependencies anywhere with: `sl<SomeType>()`
final sl = GetIt.instance;

/// Registers all application dependencies with GetIt.
///
/// Called once from [main()] before [runApp()].
/// Registration order matters — dependencies must be registered before the
/// classes that consume them.
Future<void> initDependencies() async {
  // Guard against stale or corrupt keychain state that causes EXC_BAD_ACCESS
  // on ARM64e devices (iPhone 15 / A16) after extended idle periods. A failed
  // read means the keychain entry is invalid; wipe all stored items so the app
  // starts clean rather than crashing in a DartWorker thread.
  try {
    await const FlutterSecureStorage().read(key: 'auth_token');
  } catch (_) {
    await const FlutterSecureStorage().deleteAll();
  }

  // ── External / Third-party ───────────────────────────────────────────────

  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => AuthInterceptor(sl<FlutterSecureStorage>()));
  sl.registerLazySingleton(
    () => DioClient(authInterceptor: sl<AuthInterceptor>()),
  );

  // ── Core ─────────────────────────────────────────────────────────────────

  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  // ── Auth Feature ─────────────────────────────────────────────────────────

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => RegisterUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => LogoutUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl<AuthRepository>()));

  // Factory: BLoC must NOT be a singleton — each BlocProvider creates a fresh
  // instance so state doesn't bleed between screen navigations.
  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl(),
      registerUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
    ),
  );

  // ── Home Feature ─────────────────────────────────────────────────────────

  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetDashboardStatsUseCase(sl<HomeRepository>()));
  sl.registerFactory(() => HomeBloc(getDashboardStats: sl()));

  // ── Services Feature ──────────────────────────────────────────────────────

  sl.registerLazySingleton<ServicesRemoteDataSource>(
    () => ServicesRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<ServicesRepository>(
    () => ServicesRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetServicesUseCase(sl<ServicesRepository>()));
  sl.registerLazySingleton(
    () => GetServiceDetailUseCase(sl<ServicesRepository>()),
  );
  sl.registerFactory(
    () => ServicesBloc(getServices: sl(), getServiceDetail: sl()),
  );

  // ── Bookings Feature ──────────────────────────────────────────────────────

  sl.registerLazySingleton<BookingsRemoteDataSource>(
    () => BookingsRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<BookingsRepository>(
    () => BookingsRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetBookingsUseCase(sl<BookingsRepository>()));
  sl.registerLazySingleton(
    () => CreateBookingUseCase(sl<BookingsRepository>()),
  );
  sl.registerLazySingleton(
    () => CancelBookingUseCase(sl<BookingsRepository>()),
  );
  sl.registerFactory(
    () => BookingsBloc(
      getBookings: sl(),
      createBooking: sl(),
      cancelBooking: sl(),
    ),
  );

  // ── Profile Feature ───────────────────────────────────────────────────────

  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetProfileUseCase(sl<ProfileRepository>()));
  sl.registerLazySingleton(
    () => UpdateProfileUseCase(sl<ProfileRepository>()),
  );
  sl.registerFactory(
    () => ProfileBloc(getProfile: sl(), updateProfile: sl()),
  );
}
