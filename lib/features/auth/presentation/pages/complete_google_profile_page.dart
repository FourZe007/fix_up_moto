import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/helpers/validators.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';

/// Collects the last details needed to turn a Google account into a real
/// session: a name (prefilled from Google, editable) and a phone number
/// (required — the backend has no field for a Google identity, only a phone).
///
/// Email is shown but locked: Google already verified it, so it isn't
/// collected as free text the way the phone number is.
///
/// Reached only via [AuthGoogleIdentityRequested] succeeding — there is no
/// direct route to push this page from, and no backend session exists yet
/// while it is on screen, which is why [AppRouter] treats it as an auth route
/// rather than gating it behind [AuthAuthenticated].
class CompleteGoogleProfilePage extends StatefulWidget {
  final GoogleAccountIdentity identity;

  const CompleteGoogleProfilePage({super.key, required this.identity});

  @override
  State<CompleteGoogleProfilePage> createState() =>
      _CompleteGoogleProfilePageState();
}

class _CompleteGoogleProfilePageState
    extends State<CompleteGoogleProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    // Blank when Google gave no display name, per the widget's own contract —
    // never substitute a placeholder the user would have to notice and clear.
    text: widget.identity.displayName ?? '',
  );
  late final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSubmitPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthGoogleAccountSubmitted(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: widget.identity.email,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          // Navigation on success is handled by AppRouter's redirect, the same
          // as every other auth-completing event — nothing to do here.
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Just a few more details',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We need your phone number to finish setting up your account.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 40),

                    AuthTextField(
                      controller: _nameController,
                      label: 'Name',
                      prefixIcon: Icons.person_outlined,
                      validator: Validators.required('Name'),
                    ),
                    const SizedBox(height: 16),

                    AuthTextField(
                      controller: _phoneController,
                      label: 'Phone number',
                      hint: '081234567890',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: 16),

                    // Read-only: Google already verified this address, so it
                    // is shown for confirmation only, never re-typed.
                    AuthTextField(
                      controller: TextEditingController(
                        text: widget.identity.email,
                      ),
                      label: 'Email',
                      prefixIcon: Icons.email_outlined,
                      enabled: false,
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: isLoading ? null : _onSubmitPressed,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Finish setting up'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
