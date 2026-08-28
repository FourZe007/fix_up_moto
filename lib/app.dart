import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/app_router.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';

/// Root widget of the application.
///
/// Responsibilities:
/// - Provides **global** BLoCs that must outlive individual routes (e.g. [AuthBloc])
/// - Configures [MaterialApp.router] with theme + GoRouter
///
/// Feature-scoped BLoCs (home, services, bookings, profile) are provided at
/// the page level — NOT here — so they are disposed when the page is popped.
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
        // Register additional app-wide BLoCs here as the app grows.
        // Example: BlocProvider<ThemeBloc>(create: (_) => sl<ThemeBloc>()),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,

        // Light and dark themes defined centrally in core/theme/
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,

        // Follows the device's system theme setting automatically.
        // Users can override this later with a ThemeBloc if needed.
        themeMode: ThemeMode.system,

        // GoRouter instance declared in AppRouter handles all navigation,
        // including the auth redirect guard and ShellRoute tab structure.
        routerConfig: AppRouter.router,

        // Remove the debug banner in all builds — cleaner screenshots/demos.
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
