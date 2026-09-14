import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fix_up_moto/core/constants/google_auth_constants.dart';

import 'package:fix_up_moto/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fix_up_moto/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_google_identity_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/get_remembered_google_phone_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/login_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/logout_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/register_usecase.dart';
import 'package:fix_up_moto/features/auth/domain/usecases/submit_google_account_usecase.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/bookings/data/datasources/bookings_remote_data_source.dart';
import 'package:fix_up_moto/features/bookings/data/repositories/bookings_repository_impl.dart';
import 'package:fix_up_moto/features/bookings/domain/repositories/bookings_repository.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/cancel_booking_usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/create_booking_usecase.dart';
import 'package:fix_up_moto/features/bookings/domain/usecases/get_bookings_usecase.dart';
import 'package:fix_up_moto/features/bookings/presentation/bloc/bookings_bloc.dart';
import 'package:fix_up_moto/features/feeds/data/datasources/feeds_remote_data_source.dart';
import 'package:fix_up_moto/features/feeds/data/repositories/feeds_repository_impl.dart';
import 'package:fix_up_moto/features/feeds/domain/repositories/feeds_repository.dart';
import 'package:fix_up_moto/features/feeds/domain/usecases/get_feeds_usecase.dart';
import 'package:fix_up_moto/features/feeds/presentation/bloc/feeds_bloc.dart';
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
import 'package:fix_up_moto/features/promos/data/datasources/promos_remote_data_source.dart';
import 'package:fix_up_moto/features/promos/data/repositories/promos_repository_impl.dart';
import 'package:fix_up_moto/features/promos/domain/repositories/promos_repository.dart';
import 'package:fix_up_moto/features/promos/domain/usecases/get_promo_images_usecase.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_bloc.dart';
import 'package:fix_up_moto/features/workshops/data/datasources/workshops_remote_data_source.dart';
import 'package:fix_up_moto/features/workshops/data/repositories/workshops_repository_impl.dart';
import 'package:fix_up_moto/features/workshops/domain/repositories/workshops_repository.dart';
import 'package:fix_up_moto/features/workshops/domain/usecases/get_workshops_usecase.dart';
import 'package:fix_up_moto/features/workshops/presentation/bloc/workshops_bloc.dart';
import 'package:fix_up_moto/features/services/data/datasources/services_remote_data_source.dart';
import 'package:fix_up_moto/features/services/data/repositories/services_repository_impl.dart';
import 'package:fix_up_moto/features/services/domain/repositories/services_repository.dart';
import 'package:fix_up_moto/features/services/domain/usecases/get_service_detail_usecase.dart';
import 'package:fix_up_moto/features/services/domain/usecases/get_services_usecase.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/network/dio_client.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fix_up_moto/firebase_options.dart';

/// Global service locator instance.
/// Access dependencies anywhere with: `sl<SomeType>()`
final sl = GetIt.instance;

/// Registers all application dependencies with GetIt.
///
/// Called once from [main()] before [runApp()].
/// Registration order matters — dependencies must be registered before the
/// classes that consume them.
Future<void> initDependencies() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Guard against stale or corrupt keychain state that causes EXC_BAD_ACCESS
  // on ARM64e devices (iPhone 15 / A16) after extended idle periods. A failed
  // read means the keychain entry is invalid; wipe all stored items so the app
  // starts clean rather than crashing in a DartWorker thread.
  try {
    await const FlutterSecureStorage().read(key: ApiConstants.cachedUserKey);
  } catch (_) {
    await const FlutterSecureStorage().deleteAll();
  }

  // ── External / Third-party ───────────────────────────────────────────────

  // google_sign_in 7.x requires initialize() to be awaited exactly once before
  // any other call on the singleton — so this runs unconditionally. Skipping it
  // when the Dart constant was empty is what produced "not configured for this
  // build" even on a correctly set up project.
  //
  // serverClientId is passed as NULL rather than '' when unset: null lets the
  // Android plugin fall back to the `default_web_client_id` string resource
  // that the google-services plugin generates from google-services.json, while
  // an empty string is treated as a real value and fails that lookup.
  //
  // Wrapped so a Google misconfiguration cannot take ordinary phone login down
  // with it; the Google button reports the problem when it is actually pressed.
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: GoogleAuthConstants.serverClientId.isEmpty
          ? null
          : GoogleAuthConstants.serverClientId,
    );
  } catch (_) {
    // Deliberately swallowed — see above.
  }

  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => DioClient());

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
  sl.registerLazySingleton(() => GetGoogleIdentityUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(
    () => GetRememberedGooglePhoneUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton(
    () => SubmitGoogleAccountUseCase(sl<AuthRepository>()),
  );

  // AuthBloc is the ONE exception to the factory rule below, because it is
  // app-scoped rather than page-scoped: it is created once at the root in
  // App.build and lives for the whole run, so the state-bleeding hazard that
  // makes page BLoCs factories cannot arise. A single shared instance is also
  // what lets AppRouter observe it via `refreshListenable`.
  //
  // Pair this with `BlocProvider.value` in app.dart — `create:` would close the
  // singleton on dispose and leave sl<AuthBloc>() handing out a closed bloc.
  sl.registerLazySingleton(
    () => AuthBloc(
      loginUseCase: sl(),
      registerUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      getGoogleIdentityUseCase: sl(),
      submitGoogleAccountUseCase: sl(),
      getRememberedGooglePhoneUseCase: sl(),
    ),
  );

  // ── Home Feature ─────────────────────────────────────────────────────────

  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      authRepository: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => GetDashboardStatsUseCase(sl<HomeRepository>()),
  );
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

  // ── Feeds Feature ─────────────────────────────────────────────────────────

  sl.registerLazySingleton<FeedsRemoteDataSource>(
    () => FeedsRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<FeedsRepository>(
    () => FeedsRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetFeedsUseCase(sl<FeedsRepository>()));
  sl.registerFactory(() => FeedsBloc(getFeeds: sl()));

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
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl<ProfileRepository>()));
  sl.registerFactory(() => ProfileBloc(getProfile: sl(), updateProfile: sl()));

  // ── Workshops Feature ─────────────────────────────────────────────────────

  sl.registerLazySingleton<WorkshopsRemoteDataSource>(
    () => WorkshopsRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<WorkshopsRepository>(
    () => WorkshopsRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetWorkshopsUseCase(sl<WorkshopsRepository>()));
  sl.registerFactory(() => WorkshopsBloc(getWorkshops: sl()));

  // ── Promos Feature ────────────────────────────────────────────────────────

  sl.registerLazySingleton<PromosRemoteDataSource>(
    () => PromosRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<PromosRepository>(
    () => PromosRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetPromoImagesUseCase(sl<PromosRepository>()));
  sl.registerFactory(() => PromosBloc(getPromoImages: sl()));
}
