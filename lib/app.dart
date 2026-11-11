import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/push/push_bootstrap.dart';
import 'package:fix_up_moto/core/push/push_notification_service.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/router/app_router.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/theme/preview_platform.dart';
import 'package:fix_up_moto/core/theme/theme_cubit.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_monitor.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/stats_bootstrap.dart';
import 'package:fix_up_moto/features/notification/presentation/cubit/notification_count_cubit.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';

/// Root widget of the application.
///
/// Responsibilities:
/// - Provides **global** BLoCs that must outlive individual routes (e.g.
///   [AuthBloc], and [HomeBloc], the member's stats record that Home, Profile,
///   MyPoint and Edit Profile all read)
/// - Configures [MaterialApp.router] with theme + GoRouter
///
/// Page-scoped BLoCs (services, bookings, profile) are provided at the page
/// level — NOT here — so they are disposed when the page is popped.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // AuthBloc is a lazy singleton, so this is the same instance AppRouter
        // observes through its refreshListenable.
        //
        // `.value` rather than `create:` on purpose: `create:` transfers
        // ownership, and BlocProvider would close the bloc when App is
        // disposed — leaving sl<AuthBloc>() handing out a closed bloc for the
        // rest of the process. `.value` shares without owning.
        //
        // ..add fires the session check immediately; the router shows the
        // splash route until it resolves.
        BlocProvider<AuthBloc>.value(
          value: sl<AuthBloc>()..add(const AuthCheckStatusRequested()),
        ),
        // Same reasoning as AuthBloc above: app-scoped, and .value so this
        // widget doesn't own (and therefore doesn't close) the singleton.
        // Needed here rather than at Home/Bookings page level since Home's
        // workshop picker and Create Booking's picker must see the same pick.
        BlocProvider<SelectedWorkshopCubit>.value(
          value: sl<SelectedWorkshopCubit>(),
        ),
        // App-scoped and `.value` for the same reason as the two above;
        // MaterialApp below rebuilds from it when the member changes theme.
        BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
        // Lets an action on one screen tell a kept-alive tab to reload.
        BlocProvider<DataRefreshCubit>.value(value: sl<DataRefreshCubit>()),
        // The member's stats record (name, phone, email, points, history),
        // loaded once and read by Home, Profile, MyPoint and Edit Profile.
        // StatsBootstrap below loads it at sign-in and clears it at sign-out.
        // App-scoped and `.value` for the same reason as AuthBloc above.
        BlocProvider<HomeBloc>.value(value: sl<HomeBloc>()),
        // The unread-notification count shown by Home's bell and Profile's
        // row. App-scoped and `.value` for the same reason as the above.
        BlocProvider<NotificationCountCubit>.value(
          value: sl<NotificationCountCubit>(),
        ),
        // Register additional app-wide BLoCs here as the app grows.
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp.router(
          title: AppConstants.appName,

          // Light and dark themes defined centrally in core/theme/
          // Unchanged unless --dart-define=PREVIEW_PLATFORM=ios is given (and
          // never in a release build): see applyPreviewPlatform.
          theme: applyPreviewPlatform(AppTheme.light),
          darkTheme: applyPreviewPlatform(AppTheme.dark),

          // Light only while AppConstants.themeSwitchEnabled is off: the saved
          // choice (and the phone's own dark setting) is ignored until the
          // feature is turned back on.
          themeMode: AppTheme.resolveMode(themeMode),

          // GoRouter instance declared in AppRouter handles all navigation,
          // including the auth redirect guard and tab structure.
          routerConfig: AppRouter.router,

          // Push notifications: switches them on at sign-in and off at
          // sign-out, shows a banner for a push that arrives while the app
          // is open, and opens Kotak Masuk when one is tapped. Also keeps the
          // member told about new inbox messages (points, booking confirmed).
          // Below the AuthBloc provider above, and draws nothing of its own.
          builder: (context, child) => StatsBootstrap(
            // Loads, reloads and clears the member's stats (see StatsBootstrap).
            child: PushBootstrap(
              router: AppRouter.router,
              service: sl<PushNotificationService>(),
              inbox: sl<InboxMonitor>(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),

          // Remove the debug banner in all builds — cleaner screenshots/demos.
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
