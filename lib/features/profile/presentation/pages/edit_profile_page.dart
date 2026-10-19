import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/phone_number.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_state.dart';

/// Edits the signed-in member's name, phone number and email.
///
/// Reached via `context.push(RouteNames.editProfile)` — a top-level route, so
/// it provides its own blocs rather than assuming an ancestor does: a
/// [HomeBloc] to read the member's current details (the same dashboard stats
/// record the Profile page shows) and a [ProfileBloc] to save them.
///
/// The login ID is tied to the member's ID, so it is shown but locked. A
/// phone-registered account signs in with its phone: name and email are
/// editable. A Google account signs in with its email: name and phone are
/// editable. The repository enforces the same rule — see
/// [ProfileRepository.updateProfile].
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Both colours come from the active Theme rather than AppColors constants,
    // so this bar follows light/dark automatically when ThemeCubit changes
    // MaterialApp's themeMode — no cubit read needed here. The title and arrow
    // are coloured explicitly because the app's AppBarTheme hard-codes a white
    // title style.
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final authState = context.read<AuthBloc>().state;
    final isGoogle =
        authState is AuthAuthenticated && authState.user.isGoogle == '1';

    return MultiBlocProvider(
      providers: [
        // Page-scoped factories, like every other page's blocs.
        BlocProvider(
          create: (_) => sl<HomeBloc>()..add(const HomeStatsRequested()),
        ),
        BlocProvider(create: (_) => sl<ProfileBloc>()),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Edit Profile',
            style: TextStyle(color: onSurface, fontSize: 20),
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          // Same colour as the page behind it, so the bar blends into the body.
          backgroundColor: theme.scaffoldBackgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(foregroundColor: onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        body: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) => switch (state) {
            HomeInitial() ||
            HomeLoading() => const Center(child: CircularProgressIndicator()),
            HomeError(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  Text(message),
                  ElevatedButton(
                    onPressed: () => context.read<HomeBloc>().add(
                      const HomeStatsRequested(),
                    ),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
            HomeLoaded(:final stats) => _EditProfileForm(
              stats: stats,
              isGoogle: isGoogle,
            ),
          },
        ),
      ),
    );
  }
}

/// The backend sends `-` (or nothing) for a field the member never filled in.
String _valueOrEmpty(String value) {
  final trimmed = value.trim();
  return trimmed == '-' ? '' : trimmed;
}

class _EditProfileForm extends StatefulWidget {
  final DashboardStatsEntity stats;
  final bool isGoogle;

  const _EditProfileForm({required this.stats, required this.isGoogle});

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.stats.memberName,
  );
  late final _phoneController = TextEditingController(
    text: _phoneFrom(widget.stats.phoneNo),
  );
  late final _emailController = TextEditingController(
    text: _valueOrEmpty(widget.stats.emailAddress),
  );

  /// The backend sends the phone without its leading zero; the member types
  /// (and reads) it with one. A Google account that has not saved a phone yet
  /// has its email in this slot, which is not a phone to show.
  static String _phoneFrom(String phoneNo) {
    final value = _valueOrEmpty(phoneNo);
    if (value.isEmpty || PhoneNumber.looksLikeEmail(value)) return '';
    return '0$value';
  }

  // Local, Bahasa-language checks — the shared `Validators` messages are
  // English and reused by Login/Register, whose wording this page shouldn't
  // change (same reasoning as AddBikePage).
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nama wajib diisi';
    return null;
  }

  /// Optional, but still checked when something is typed.
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    // Separators are fine to type; the data layer strips them.
    final digitsOnly = value.replaceAll(RegExp(r'[\s\-()]+'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(digitsOnly)) {
      return 'Masukkan nomor telepon yang valid';
    }
    return null;
  }

  /// Optional, but still checked when something is typed.
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(
      r'^[\w._%+\-]+@[\w.\-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(value.trim())) {
      return 'Masukkan email yang valid';
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ProfileBloc>().add(
        ProfileUpdateRequested(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileActionSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));

          // The member's details just changed, and Home, Membership and
          // Profile are alive in the tab stack — tell them to reload. Read
          // before the pop, while this context is active.
          context.read<DataRefreshCubit>().invalidate(DataKind.stats);
          context.pop();
        } else if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is ProfileLoading;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  AuthTextField(
                    controller: _nameController,
                    label: 'Nama Lengkap',
                    prefixIcon: Icons.person_outlined,
                    validator: _validateName,
                  ),
                  // The login ID is locked: the phone for a phone-registered
                  // account, the email for a Google one. The other of the two
                  // is the editable contact field.
                  AuthTextField(
                    controller: _phoneController,
                    label: widget.isGoogle
                        ? 'Nomor Telepon (opsional)'
                        : 'Nomor Telepon',
                    hint: '081234567890',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    enabled: widget.isGoogle,
                    validator: widget.isGoogle ? _validatePhone : null,
                  ),
                  AuthTextField(
                    controller: _emailController,
                    label: widget.isGoogle ? 'Email' : 'Email (opsional)',
                    hint: 'anda@contoh.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    enabled: !widget.isGoogle,
                    validator: widget.isGoogle ? null : _validateEmail,
                  ),
                  Text(
                    widget.isGoogle
                        ? 'Email adalah ID akun Google Anda dan tidak dapat '
                              'diubah.'
                        : 'Nomor telepon adalah ID akun Anda dan tidak dapat '
                              'diubah.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
