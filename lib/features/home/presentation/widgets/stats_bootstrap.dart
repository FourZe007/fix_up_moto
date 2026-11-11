import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/refresh/refresh_on.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';

/// The one place that decides when the member's stats are loaded, reloaded and
/// cleared. Put it in `MaterialApp.router`'s `builder`, below the app's
/// [AuthBloc], [HomeBloc] and [DataRefreshCubit] providers.
///
/// - **Sign-in** → loads the stats once. Pages do not fetch on mount; they read
///   what [HomeBloc] holds.
/// - **`DataRefreshCubit.invalidate(DataKind.stats)`** → reloads once. This is
///   the only listener, so one change is one request, not one per page.
/// - **Sign-out** → clears the stats, so one member's data never shows for the
///   next.
///
/// It draws nothing of its own: it returns [child] untouched.
class StatsBootstrap extends StatefulWidget {
  final Widget child;

  const StatsBootstrap({super.key, required this.child});

  @override
  State<StatsBootstrap> createState() => _StatsBootstrapState();
}

class _StatsBootstrapState extends State<StatsBootstrap> {
  @override
  void initState() {
    super.initState();
    // BlocListener only reports changes, so a session that is already live when
    // this mounts (a hot restart) is picked up here. Only when nothing has been
    // asked for yet, so it never doubles a request the listener already made.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final home = context.read<HomeBloc>();
      if (context.read<AuthBloc>().state is AuthAuthenticated &&
          home.state is HomeInitial) {
        home.add(const HomeStatsRequested());
      }
    });
  }

  void _onAuthChanged(BuildContext context, AuthState state) {
    final home = context.read<HomeBloc>();
    if (state is AuthAuthenticated) {
      home.add(const HomeStatsRequested());
    } else if (state is AuthUnauthenticated) {
      home.add(const HomeResetRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _onAuthChanged,
      child: RefreshOn(
        kind: DataKind.stats,
        onRefresh: (context) {
          // Nobody to load for once signed out (the member is on the login
          // form); the next sign-in loads from scratch.
          if (context.read<AuthBloc>().state is! AuthAuthenticated) return;
          context.read<HomeBloc>().add(const HomeStatsRequested());
        },
        child: widget.child,
      ),
    );
  }
}
