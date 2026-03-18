import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/route_names.dart';
import 'package:fix_up_moto/presentation/blocs/profile_bloc.dart';
import 'package:fix_up_moto/presentation/blocs/profile_event.dart';
import 'package:fix_up_moto/presentation/blocs/profile_state.dart';

/// Shows the authenticated user's profile info and their registered motorcycles.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileBloc>()..add(const ProfileLoadRequested()),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Logout button in the app bar
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            ProfileInitial() || ProfileLoading() =>
              const Center(child: CircularProgressIndicator()),
            ProfileError(:final message) => Center(child: Text(message)),
            ProfileActionSuccess() =>
              const Center(child: CircularProgressIndicator()),
            ProfileLoaded(:final user, :final motorcycles) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Avatar + name header
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
                        Text(user.name,
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(user.email,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),

                  // Motorcycles section
                  ListTile(
                    title: Text('My Motorcycles',
                        style: Theme.of(context).textTheme.titleMedium),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => context.push(RouteNames.addMotorcycle),
                    ),
                  ),
                  if (motorcycles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No motorcycles added yet'),
                    )
                  else
                    ...motorcycles.map(
                      (moto) => ListTile(
                        leading: const Icon(Icons.two_wheeler),
                        title: Text('${moto.brand} ${moto.model}'),
                        subtitle: Text('${moto.year} · ${moto.plateNumber}'),
                      ),
                    ),
                ],
              ),
          };
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Dispatch to the global AuthBloc (provided at App root)
              // We use context.read which walks up the widget tree
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
