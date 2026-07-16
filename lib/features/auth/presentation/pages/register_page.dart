import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:fix_up_moto/core/helpers/validators.dart';

/// Registration screen — creates a new user account.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthRegisterRequested(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Back arrow returns to login page
      appBar: AppBar(title: const Text('Create Account'), elevation: 0),
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
          // AuthAuthenticated is handled by AppRouter redirect
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Join Fix Up Moto',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create an account to book your service',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  // ── Name ──────────────────────────────────────────────
                  AuthTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    prefixIcon: Icons.person_outlined,
                    validator: Validators.required('Full name'),
                  ),
                  const SizedBox(height: 16),

                  // ── Email ─────────────────────────────────────────────
                  AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'you@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),

                  // ── Password ──────────────────────────────────────────
                  AuthTextField(
                    controller: _passwordController,
                    label: 'Password',
                    prefixIcon: Icons.lock_outlined,
                    obscureText: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),

                  // ── Confirm password ──────────────────────────────────
                  AuthTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    prefixIcon: Icons.lock_outlined,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    // Validator is built dynamically to compare against current password
                    validator: Validators.confirmPassword(
                      _passwordController.text,
                    ),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: isLoading ? null : _onRegisterPressed,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
