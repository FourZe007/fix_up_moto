import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';

/// Shows the signed-in member and the sign-out action.
///
/// **Reads from [AuthBloc], not from the network.** The member record returned
/// by login is already cached and already in memory, so fetching it again would
/// be redundant — and until `/apiSAMP/BrowseMember` is a verified endpoint, that
/// fetch simply hung for the full 30-second Dio timeout every time the tab was
/// opened. `ProfileBloc` stays registered in the DI container for when the
/// profile endpoints are confirmed.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          // The router's guard makes this tab unreachable while signed out, so
          // anything other than AuthAuthenticated is defensive only — most
          // likely the brief moment during sign-out before the redirect lands.
          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          return _ProfileBody(user: state.user);
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    // Resolve the bloc BEFORE opening the dialog. Reaching for it afterwards
    // would mean touching a BuildContext across the dialog's dismissal.
    final authBloc = context.read<AuthBloc>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);

              // No navigation here on purpose. AuthBloc emits
              // AuthUnauthenticated, GoRouterRefreshStream notifies the router,
              // and the redirect guard sends the user to /login.
              authBloc.add(const AuthLogoutRequested());
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserEntity user;

  const _ProfileBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 32),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(user.name, style: theme.textTheme.headlineSmall),

              // The backend's own wording about the membership — the same field
              // that explains a refused sign-in.
              Text(user.status, style: theme.textTheme.bodyMedium),

              // Both absent from the SAMP member record today, so only shown
              // once an endpoint actually provides them.
              if (user.phone != null)
                Text(user.phone!, style: theme.textTheme.bodyMedium),
              if (user.email != null)
                Text(user.email!, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),

        // Not wired yet: listing units needs BrowseTrans confirmed, and adding
        // one needs InsertUnit. ProfileBloc never loaded this list either —
        // ProfileLoaded.motorcycles always defaulted to an empty list.
        ListTile(
          title: Text('My Motorcycles', style: theme.textTheme.titleMedium),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(RouteNames.addMotorcycle),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No motorcycles added yet'),
        ),
      ],
    );
  }
}
